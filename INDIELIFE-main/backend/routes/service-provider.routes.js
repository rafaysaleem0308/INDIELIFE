const express = require("express");
const router = express.Router();
const ServiceProvider = require("../models/service-provider.model");
const User = require("../models/user.model");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const RefreshToken = require("../models/refresh-token.model");
const { verifyToken } = require("../middleware/auth");
const { authLimiter } = require("../middleware/rateLimit");
const {
  generateRefreshToken,
  generateAccessToken,
  buildSpPayload,
  buildSpResponse,
  REFRESH_TOKEN_EXPIRY_DAYS,
} = require("./auth.routes");

// ─── VALIDATION & SANITIZATION ────────────────────────────────────────────
const {
  validateEmail,
  validatePassword,
  validatePhone,
  sanitizeString,
} = require("../utils/validators");

const multer = require("multer");
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, "uploads/");
  },
  filename: function (req, file, cb) {
    cb(
      null,
      "profile-sp-" + Date.now() + "-" + file.originalname.replace(/\s+/g, "-"),
    );
  },
});
const upload = multer({ storage: storage });

// Store OTP verification status temporarily

// POST /signup/service-provider
router.post("/", async (req, res) => {
  try {
    const {
      email,
      phone,
      password,
      firstName,
      lastName,
      city,
      address,
      districtName,
      districtNazim,
      spSubRole,
      lat,
      lng,
    } = req.body;

    // ─── VALIDATION ────────────────────────────────────────────────────────
    if (!email || !phone || !password || !firstName || !lastName) {
      return res.status(400).json({
        success: false,
        message: "All required fields must be provided",
      });
    }

    // Validate email format
    if (!validateEmail(email)) {
      return res.status(400).json({
        success: false,
        message: "Email format is invalid",
      });
    }

    // Validate phone format
    if (!validatePhone(phone)) {
      return res.status(400).json({
        success: false,
        message: "Phone number format is invalid (must be Pakistani format)",
      });
    }

    // Validate password strength (Backend enforcement)
    if (!validatePassword(password)) {
      return res.status(400).json({
        success: false,
        message:
          "Password must be at least 8 characters with uppercase, lowercase, digit, and special character",
      });
    }

    // Validate name lengths
    if (firstName.length < 2 || firstName.length > 50) {
      return res.status(400).json({
        success: false,
        message: "First name must be 2-50 characters",
      });
    }

    if (lastName.length < 2 || lastName.length > 50) {
      return res.status(400).json({
        success: false,
        message: "Last name must be 2-50 characters",
      });
    }

    if (!districtName) {
      return res.status(400).json({
        success: false,
        error: "District Name is required",
      });
    }

    if (!districtNazim) {
      return res.status(400).json({
        success: false,
        error: "District Nazim Name is required",
      });
    }

    // ─── SANITIZATION ──────────────────────────────────────────────────────
    const sanitizedData = {
      ...req.body,
      email: email.toLowerCase().trim(),
      phone: phone.trim(),
      firstName: sanitizeString(firstName),
      lastName: sanitizeString(lastName),
      bio: req.body.bio ? sanitizeString(req.body.bio) : "",
      address: req.body.address ? sanitizeString(req.body.address) : "",
      city: req.body.city ? sanitizeString(req.body.city) : "",
    };

    // Check for existing email in both collections
    const existingSPEmail = await ServiceProvider.findOne({
      email: sanitizedData.email,
    });
    const existingUserEmail = await User.findOne({
      email: sanitizedData.email,
    });

    if (existingSPEmail || existingUserEmail) {
      return res.status(400).json({
        success: false,
        error: "Account already exists with this email",
      });
    }

    // Check for existing phone in both collections
    const existingSPPhone = await ServiceProvider.findOne({
      phone: sanitizedData.phone,
    });
    const existingUserPhone = await User.findOne({
      phone: sanitizedData.phone,
    });

    if (existingSPPhone || existingUserPhone) {
      return res.status(400).json({
        success: false,
        error: "Account already exists with this phone number",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    // Create ServiceProvider record directly (no User record for service providers)
    const sp = new ServiceProvider({
      firstName: sanitizedData.firstName,
      lastName: sanitizedData.lastName,
      email: sanitizedData.email,
      password: hashedPassword,
      phone: sanitizedData.phone,
      city: sanitizedData.city,
      address: sanitizedData.address,
      districtName: sanitizedData.districtName,
      districtNazim: sanitizedData.districtNazim,
      spSubRole: spSubRole,
      serviceName: `${sanitizedData.firstName} ${sanitizedData.lastName}`,
      description: "",
      profileImage: null,
      ismnAddress: "",
      isVerified: false,
      isActive: true,
      totalOrders: 0,
      totalEarnings: 0,
      rating: 0,
      reviewsCount: 0,
      isAvailable: true,
      openingHours: {
        from: "09:00",
        to: "22:00",
      },
    });

    if (lat && lng) {
      sp.location = {
        type: "Point",
        coordinates: [parseFloat(lng), parseFloat(lat)],
      };
    }

    await sp.save();

    // Return approval request response - NO TOKENS yet
    res.status(201).json({
      success: true,
      message:
        "Approval request submitted. Please wait for admin verification.",
      spId: sp._id,
      status: "pending",
      requestedAt: sp.createdAt,
    });
  } catch (err) {
    console.error("Service Provider signup error:", err);
    // Don't expose internal error details - return user-friendly message
    const errorMsg = err.message || "An error occurred during signup";
    let statusCode = 500;
    let userMessage = "An error occurred during signup. Please try again.";

    if (errorMsg.includes("duplicate key")) {
      userMessage = "This email or phone number is already registered";
      statusCode = 400;
    } else if (errorMsg.includes("validation failed")) {
      userMessage = "Invalid data provided. Please check all fields";
      statusCode = 400;
    }

    res.status(statusCode).json({
      success: false,
      error: userMessage,
    });
  }
});

// LOGIN SERVICE PROVIDER
router.post("/login", authLimiter, async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Email and password are required",
      });
    }

    // Validate email format
    if (!validateEmail(email)) {
      return res.status(400).json({
        success: false,
        message: "Invalid email format",
      });
    }

    // Basic password validation
    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 6 characters",
      });
    }

    // Find service provider directly in ServiceProvider collection
    const normalizedEmail = email.toLowerCase().trim();
    const serviceProvider = await ServiceProvider.findOne({
      email: normalizedEmail,
    });

    if (!serviceProvider) {
      return res.status(400).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    const isPasswordValid = await bcrypt.compare(
      password,
      serviceProvider.password,
    );

    if (!isPasswordValid) {
      return res.status(400).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    // Check if provider is approved
    if (serviceProvider.status !== "approved") {
      if (serviceProvider.status === "pending") {
        return res.status(403).json({
          success: false,
          message:
            "Your account is pending approval. Please wait for admin verification.",
          status: "pending",
        });
      } else if (serviceProvider.status === "rejected") {
        return res.status(403).json({
          success: false,
          message: "Your account has been rejected. Please contact support.",
          status: "rejected",
        });
      } else if (serviceProvider.status === "suspended") {
        return res.status(403).json({
          success: false,
          message: "Your account has been suspended. Please contact support.",
          status: "suspended",
        });
      }
    }

    const accessToken = generateAccessToken(buildSpPayload(serviceProvider));
    const refreshToken = generateRefreshToken();

    await RefreshToken.create({
      token: refreshToken,
      userId: serviceProvider._id.toString(),
      role: "service_provider",
      userModel: "ServiceProvider",
      deviceInfo: req.headers["user-agent"] || "unknown",
      expiresAt: new Date(
        Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000,
      ),
    });

    res.status(200).json({
      success: true,
      message: "Service Provider login successful",
      token: accessToken,
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: buildSpResponse(serviceProvider),
    });
  } catch (err) {
    console.error("Service Provider login error:", err);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: err.message,
    });
  }
});

// GET CURRENT SERVICE PROVIDER
router.get("/me", verifyToken, async (req, res) => {
  try {
    // Find service provider
    const sp = await ServiceProvider.findById(req.user.spId || req.user.userId);

    if (!sp)
      return res
        .status(404)
        .json({ success: false, message: "Provider not found" });

    res.status(200).json({
      success: true,
      user: {
        id: sp._id,
        userId: sp._id,
        firstName: sp.firstName,
        lastName: sp.lastName,
        email: sp.email,
        role: "service_provider",
        spSubRole: sp.spSubRole,
        phone: sp.phone,
        city: sp.city,
        address: sp.address,
        // Add missing fields to match PUT response
        username: `${sp.firstName} ${sp.lastName}`,
        districtName: sp.districtName,
        districtNazim: sp.districtNazim,
        profileImage: sp.profileImage,
        bio: sp.bio,
        experienceYears: sp.experienceYears,
      },
    });
  } catch (err) {
    console.error("SP /me error:", err);
    res.status(401).json({ success: false, message: "Invalid token" });
  }
});

// GET service provider by user ID
router.get("/by-user/:userId", async (req, res) => {
  try {
    const { userId } = req.params;

    const serviceProvider = await ServiceProvider.findOne({ userId: userId });

    if (!serviceProvider) {
      return res.status(404).json({
        success: false,
        message: "Service provider not found",
      });
    }

    res.status(200).json({
      success: true,
      serviceProvider: serviceProvider,
    });
  } catch (err) {
    console.error("Get service provider error:", err);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: err.message,
    });
  }
});

// ================================
// GET /signup/service-provider/profile/:spId - Get Public Profile
// ================================
router.get("/profile/:spId", async (req, res) => {
  try {
    const { spId } = req.params;
    const sp = await ServiceProvider.findById(spId).select("-password");

    if (!sp) {
      return res
        .status(404)
        .json({ success: false, message: "Provider not found" });
    }

    res.status(200).json({ success: true, serviceProvider: sp });
  } catch (err) {
    res
      .status(500)
      .json({ success: false, message: "Server error", error: err.message });
  }
});

// ================================
// PUT /signup/service-provider/profile/:spId - Update Profile
// ================================
router.put("/profile/:spId", verifyToken, async (req, res) => {
  try {
    const { spId } = req.params;
    let updateData = req.body;

    // ─── VALIDATION & SANITIZATION ────────────────────────────────────────
    // Validate and sanitize firstName
    if (updateData.firstName) {
      if (updateData.firstName.length < 2 || updateData.firstName.length > 50) {
        return res.status(400).json({
          success: false,
          message: "First name must be 2-50 characters",
        });
      }
      updateData.firstName = sanitizeString(updateData.firstName);
    }

    // Validate and sanitize lastName
    if (updateData.lastName) {
      if (updateData.lastName.length < 2 || updateData.lastName.length > 50) {
        return res.status(400).json({
          success: false,
          message: "Last name must be 2-50 characters",
        });
      }
      updateData.lastName = sanitizeString(updateData.lastName);
    }

    // Validate and sanitize bio
    if (updateData.bio) {
      updateData.bio = sanitizeString(updateData.bio);
    }

    // Validate and sanitize address
    if (updateData.address) {
      updateData.address = sanitizeString(updateData.address);
    }

    // Validate and sanitize city
    if (updateData.city) {
      updateData.city = sanitizeString(updateData.city);
    }

    // Validate and sanitize districtName
    if (updateData.districtName) {
      updateData.districtName = sanitizeString(updateData.districtName);
    }

    // Validate and sanitize districtNazim
    if (updateData.districtNazim) {
      updateData.districtNazim = sanitizeString(updateData.districtNazim);
    }

    // Handle username update (split into firstName/lastName)
    if (updateData.username) {
      const parts = sanitizeString(updateData.username).trim().split(" ");
      if (parts.length > 0) updateData.firstName = parts[0];
      if (parts.length > 1) updateData.lastName = parts.slice(1).join(" ");
      delete updateData.username;
    }

    if (updateData.lat && updateData.lng) {
      updateData.location = {
        type: "Point",
        coordinates: [parseFloat(updateData.lng), parseFloat(updateData.lat)],
      };
      delete updateData.lat;
      delete updateData.lng;
    }

    // Prevent password and email update via this route
    delete updateData.password;
    delete updateData.email; // Prevent email change for now

    const sp = await ServiceProvider.findByIdAndUpdate(
      spId,
      { $set: updateData },
      { new: true, runValidators: true },
    ).select("-password");

    if (!sp) {
      return res
        .status(404)
        .json({ success: false, message: "Provider not found" });
    }

    res.status(200).json({
      success: true,
      message: "Profile updated successfully",
      serviceProvider: sp,
      user: {
        // Return mapped user object for frontend session
        id: sp._id,
        userId: sp._id,
        spId: sp._id,
        firstName: sp.firstName,
        lastName: sp.lastName,
        username: `${sp.firstName} ${sp.lastName}`, // Add username field
        email: sp.email,
        role: "service_provider",
        spSubRole: sp.spSubRole,
        phone: sp.phone,
        city: sp.city,
        address: sp.address,
        districtName: sp.districtName,
        districtNazim: sp.districtNazim,
        profileImage: sp.profileImage, // Important
        bio: sp.bio,
        experienceYears: sp.experienceYears,
        skills: sp.skills,
        servicesOffered: sp.servicesOffered,
        serviceName: sp.serviceName,
      },
    });
  } catch (err) {
    res
      .status(500)
      .json({ success: false, message: "Server error", error: err.message });
  }
});

// ================================
// POST /signup/service-provider/profile/:spId/image - Update Profile Image
// ================================
router.post(
  "/profile/:spId/image",
  verifyToken,
  upload.single("profileImage"),
  async (req, res) => {
    try {
      const { spId } = req.params;
      if (!req.file) {
        return res
          .status(400)
          .json({ success: false, message: "No image file provided" });
      }

      const imageUrl = "/uploads/" + req.file.filename;

      const sp = await ServiceProvider.findByIdAndUpdate(
        spId,
        { profileImage: imageUrl },
        { new: true },
      ).select("-password");

      if (!sp) {
        return res
          .status(404)
          .json({ success: false, message: "Provider not found" });
      }

      res.status(200).json({
        success: true,
        message: "Profile picture updated successfully",
        serviceProvider: sp,
        imageUrl,
        user: {
          id: sp._id,
          userId: sp._id,
          spId: sp._id,
          firstName: sp.firstName,
          lastName: sp.lastName,
          username: `${sp.firstName} ${sp.lastName}`,
          email: sp.email,
          role: "service_provider",
          spSubRole: sp.spSubRole,
          phone: sp.phone,
          city: sp.city,
          address: sp.address,
          profileImage: imageUrl,
        },
      });
    } catch (err) {
      res
        .status(500)
        .json({ success: false, message: "Server error", error: err.message });
    }
  },
);

// ================================
// PATCH /signup/service-provider/availability - Toggle Status
// ================================
router.patch("/availability", verifyToken, async (req, res) => {
  try {
    const spId = req.user.spId || req.user.userId;
    const { isAvailable } = req.body;

    const sp = await ServiceProvider.findByIdAndUpdate(
      spId,
      { isAvailable },
      { new: true },
    );

    if (!sp)
      return res
        .status(404)
        .json({ success: false, message: "Provider not found" });

    res.status(200).json({ success: true, isAvailable: sp.isAvailable });
  } catch (err) {
    res.status(500).json({ success: false, message: "Server error" });
  }
});

// ================================
// GET /check-approval/:spId - Check Service Provider Approval Status
// ================================
router.get("/check-approval/:spId", async (req, res) => {
  try {
    const { spId } = req.params;

    const sp =
      await ServiceProvider.findById(spId).select("status email phone");

    if (!sp) {
      return res.status(404).json({
        success: false,
        message: "Service provider not found",
      });
    }

    res.status(200).json({
      success: true,
      status: sp.status,
      spId: sp._id,
      email: sp.email,
      isApproved: sp.status === "approved",
      isPending: sp.status === "pending",
      isRejected: sp.status === "rejected",
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: "Server error",
      error: err.message,
    });
  }
});

module.exports = router;
