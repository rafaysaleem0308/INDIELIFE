const express = require("express");
const router = express.Router();
const User = require("../models/user.model");
const ServiceProvider = require("../models/service-provider.model");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const RefreshToken = require("../models/refresh-token.model");
const { verifyToken, JWT_SECRET } = require("../middleware/auth");
const { authLimiter } = require("../middleware/rateLimit");
const {
  generateRefreshToken,
  generateAccessToken,
  buildUserPayload,
  buildUserResponse,
  REFRESH_TOKEN_EXPIRY_DAYS,
} = require("./auth.routes");

// ─── VALIDATION & SANITIZATION ────────────────────────────────────────────
const {
  validateEmail,
  validatePassword,
  validatePhone,
  sanitizeString,
  sanitizeHtmlContent,
} = require("../utils/validators");
const { createUpload, getUploadedFileUrl } = require("../utils/upload");

const upload = createUpload("Indielife/users", "profile-user");

// POST /signup/user
router.post("/", async (req, res) => {
  try {
    const { email, phone, password, role, firstName, lastName } = req.body;

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

    // ─── SANITIZATION ──────────────────────────────────────────────────────
    const sanitizedData = {
      ...req.body,
      email: email.toLowerCase().trim(),
      phone: phone.trim(),
      firstName: sanitizeString(firstName),
      lastName: sanitizeString(lastName),
      bio: req.body.bio ? sanitizeHtmlContent(req.body.bio) : "",
      address: req.body.address ? sanitizeString(req.body.address) : "",
      city: req.body.city ? sanitizeString(req.body.city) : "",
    };

    const existingUserEmail = await User.findOne({
      email: sanitizedData.email,
    });
    if (existingUserEmail)
      return res.status(400).json({
        success: false,
        error: "Account already exists with this email",
      });

    const existingSPEmail = await ServiceProvider.findOne({
      email: sanitizedData.email,
    });
    if (existingSPEmail)
      return res.status(400).json({
        success: false,
        error: "Account already exists with this email",
      });

    const existingUserPhone = await User.findOne({
      phone: sanitizedData.phone,
    });
    if (existingUserPhone)
      return res.status(400).json({
        success: false,
        error: "Account already exists with this phone number",
      });

    const existingSPPhone = await ServiceProvider.findOne({
      phone: sanitizedData.phone,
    });
    if (existingSPPhone)
      return res.status(400).json({
        success: false,
        error: "Account already exists with this phone number",
      });

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = new User({
      ...sanitizedData,
      password: hashedPassword,
      // Generate username from first and last name if not provided
      username:
        sanitizedData.username ||
        `${sanitizedData.firstName} ${sanitizedData.lastName}`,
    });

    await user.save();

    const accessToken = generateAccessToken(buildUserPayload(user));
    const refreshToken = generateRefreshToken();

    // Store refresh token in database
    await RefreshToken.create({
      token: refreshToken,
      userId: user._id.toString(),
      role: "user",
      userModel: "User",
      expiresAt: new Date(
        Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000,
      ),
    });

    res.status(201).json({
      success: true,
      message: "User registered successfully",
      token: accessToken,
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: buildUserResponse(user),
    });
  } catch (err) {
    console.error("Signup error:", err);
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

// LOGIN USER
router.post("/login", authLimiter, async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res
        .status(400)
        .json({ success: false, message: "Email and password are required" });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const user = await User.findOne({ email: normalizedEmail });
    if (!user) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid email or password" });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid email or password" });
    }

    // Account Status Check (Fix for AUTHENTICATION_EXCEPTIONS_REPORT.md)
    if (user.accountStatus !== "active") {
      if (user.accountStatus === "suspended") {
        return res.status(403).json({
          success: false,
          message: "Your account is suspended. Please contact support.",
          status: "suspended",
        });
      } else if (user.accountStatus === "deactivated") {
        return res.status(403).json({
          success: false,
          message: "Your account has been deactivated.",
          status: "deactivated",
        });
      }
    }

    const accessToken = generateAccessToken(buildUserPayload(user));
    const refreshToken = generateRefreshToken();

    // Store refresh token in database
    await RefreshToken.create({
      token: refreshToken,
      userId: user._id.toString(),
      role: "user",
      userModel: "User",
      deviceInfo: req.headers["user-agent"] || "unknown",
      expiresAt: new Date(
        Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000,
      ),
    });

    res.status(200).json({
      success: true,
      message: "Login successful",
      token: accessToken,
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: buildUserResponse(user),
    });
  } catch (err) {
    console.error("Login error:", err.message);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

// GET USER PROFILE BY ID
router.get("/profile/:userId", async (req, res) => {
  try {
    const { userId } = req.params;

    const user = await User.findById(userId).select("-password"); // Exclude password
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.status(200).json({
      success: true,
      user: {
        id: user._id,
        userId: user._id,
        username: user.username,
        email: user.email,
        role: "user",
        firstName: user.firstName,
        lastName: user.lastName,
        phone: user.phone,
        city: user.city,
        address: user.address,
        profileImage: user.profileImage,
        points: user.points,
        activeOrders: user.activeOrders,
        familyName: user.familyName,
        familyPhone: user.familyPhone,
        roommateName: user.roommateName,
        roommatePhone: user.roommatePhone,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: "Server error",
      error: err.message,
    });
  }
});

// UPDATE USER PROFILE
router.put("/profile/:userId", verifyToken, async (req, res) => {
  try {
    const { userId } = req.params;
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

    // Validate phone format if provided
    if (updateData.phone) {
      if (!validatePhone(updateData.phone)) {
        return res.status(400).json({
          success: false,
          message: "Phone number format is invalid (must be Pakistani format)",
        });
      }
    }

    // Validate and sanitize address
    if (updateData.address) {
      updateData.address = sanitizeString(updateData.address);
    }

    // Validate and sanitize city
    if (updateData.city) {
      updateData.city = sanitizeString(updateData.city);
    }

    // Sanitize optional fields
    if (updateData.bio) {
      updateData.bio = sanitizeHtmlContent(updateData.bio);
    }

    if (updateData.familyName) {
      updateData.familyName = sanitizeString(updateData.familyName);
    }

    if (updateData.roommateName) {
      updateData.roommateName = sanitizeString(updateData.roommateName);
    }

    // Remove password from update data if present
    delete updateData.password;
    delete updateData.email; // Prevent email change via this route

    const user = await User.findByIdAndUpdate(
      userId,
      { $set: updateData },
      { new: true, runValidators: true },
    ).select("-password");

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.status(200).json({
      success: true,
      message: "Profile updated successfully",
      user: {
        id: user._id,
        userId: user._id,
        username: user.username,
        email: user.email,
        role: "user",
        firstName: user.firstName,
        lastName: user.lastName,
        phone: user.phone,
        city: user.city,
        address: user.address,
        profileImage: user.profileImage,
        points: user.points,
        activeOrders: user.activeOrders,
        familyName: user.familyName,
        familyPhone: user.familyPhone,
        roommateName: user.roommateName,
        roommatePhone: user.roommatePhone,
      },
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: "Server error",
      error: err.message,
    });
  }
});

// UPDATE USER PROFILE IMAGE
router.post(
  "/profile/:userId/image",
  verifyToken,
  upload.single("profileImage"),
  async (req, res) => {
    try {
      const { userId } = req.params;
      if (!req.file) {
        return res
          .status(400)
          .json({ success: false, message: "No image file provided" });
      }

      const imageUrl = getUploadedFileUrl(req.file);

      const user = await User.findByIdAndUpdate(
        userId,
        { profileImage: imageUrl },
        { new: true },
      ).select("-password");

      if (!user) {
        return res
          .status(404)
          .json({ success: false, message: "User not found" });
      }

      res.status(200).json({
        success: true,
        message: "Profile picture updated successfully",
        user,
        imageUrl,
      });
    } catch (err) {
      res
        .status(500)
        .json({ success: false, message: "Server error", error: err.message });
    }
  },
);

// GET USER BY TOKEN (for current user)
router.get("/me", verifyToken, async (req, res) => {
  try {
    const user = await User.findById(req.user.userId).select("-password");
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.status(200).json({
      success: true,
      user: {
        id: user._id,
        userId: user._id,
        username: user.username,
        email: user.email,
        role: "user",
        firstName: user.firstName,
        lastName: user.lastName,
        phone: user.phone,
        city: user.city,
        address: user.address,
        profileImage: user.profileImage,
        points: user.points,
        activeOrders: user.activeOrders,
        familyName: user.familyName,
        familyPhone: user.familyPhone,
        roommateName: user.roommateName,
        roommatePhone: user.roommatePhone,
      },
    });
  } catch (err) {
    if (err.name === "JsonWebTokenError") {
      return res.status(401).json({
        success: false,
        message: "Invalid token",
      });
    }
    res.status(500).json({
      success: false,
      message: "Server error",
      error: err.message,
    });
  }
});

// In your user routes file (users.route.js)
router.get("/find-by-email/:email", verifyToken, async (req, res) => {
  try {
    const { email } = req.params;
    const normalizedEmail = email.toLowerCase().trim();

    const user = await User.findOne({ email: normalizedEmail });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.status(200).json({
      success: true,
      user: {
        _id: user._id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        username: user.username,
        phone: user.phone,
        city: user.city,
        role: user.role,
      },
    });
  } catch (error) {
    console.error("Find user by email error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

module.exports = router;
