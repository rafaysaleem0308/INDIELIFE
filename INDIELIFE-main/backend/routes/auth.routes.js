const express = require("express");
const router = express.Router();
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const RefreshToken = require("../models/refresh-token.model");
const User = require("../models/user.model");
const ServiceProvider = require("../models/service-provider.model");
const { isProduction } = require("../utils/env");

const JWT_SECRET = process.env.JWT_SECRET || (isProduction ? undefined : "dev_jwt_secret_change_me");
if (!JWT_SECRET) {
  throw new Error("JWT_SECRET is required");
}
const ACCESS_TOKEN_EXPIRY = "1d"; // Short-lived access token
const REFRESH_TOKEN_EXPIRY_DAYS = 30; // Long-lived refresh token

/**
 * Generate a cryptographically secure refresh token
 */
function generateRefreshToken() {
  return crypto.randomBytes(64).toString("hex");
}

/**
 * Generate an access token (JWT) for a user
 */
function generateAccessToken(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: ACCESS_TOKEN_EXPIRY });
}

/**
 * Build standard user payload for JWT
 */
function buildUserPayload(user) {
  return {
    userId: user._id,
    email: user.email,
    role: user.role || "user",
    username: user.username,
    firstName: user.firstName,
    lastName: user.lastName,
  };
}

/**
 * Build standard service provider payload for JWT
 */
function buildSpPayload(sp) {
  return {
    userId: sp._id,
    spId: sp._id,
    email: sp.email,
    role: "service_provider",
    firstName: sp.firstName,
    lastName: sp.lastName,
    spSubRole: sp.spSubRole,
    districtName: sp.districtName,
    districtNazim: sp.districtNazim,
  };
}

/**
 * Build user response object (shared between login and refresh)
 */
function buildUserResponse(user) {
  return {
    id: user._id,
    userId: user._id,
    username: user.username,
    email: user.email,
    role: "user",
    city: user.city,
    phone: user.phone,
    firstName: user.firstName,
    lastName: user.lastName,
    address: user.address,
    profileImage: user.profileImage,
    points: user.points,
    activeOrders: user.activeOrders,
  };
}

/**
 * Build SP response object
 */
function buildSpResponse(sp) {
  return {
    id: sp._id,
    userId: sp._id,
    spId: sp._id,
    firstName: sp.firstName,
    lastName: sp.lastName,
    email: sp.email,
    role: "service_provider",
    spSubRole: sp.spSubRole,
    phone: sp.phone,
    city: sp.city,
    address: sp.address,
    districtName: sp.districtName,
    districtNazim: sp.districtNazim,
    profileImage: sp.profileImage,
  };
}

/**
 * Build admin response object
 */
function buildAdminResponse(admin) {
  return {
    id: admin._id,
    userId: admin._id,
    username: admin.username,
    email: admin.email,
    role: "admin",
    city: admin.city,
    phone: admin.phone,
    firstName: admin.firstName,
    lastName: admin.lastName,
    address: admin.address,
    profileImage: admin.profileImage,
  };
}

// ─── POST /auth/refresh-token ─────────────────────────────────────────────────
// Exchange a valid refresh token for a new access token
router.post("/refresh-token", async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        message: "Refresh token is required",
      });
    }

    // Find the refresh token in the database
    const storedToken = await RefreshToken.findOne({ token: refreshToken });

    if (!storedToken) {
      return res.status(401).json({
        success: false,
        message: "Invalid refresh token",
      });
    }

    // Check if the token has expired
    if (new Date() > storedToken.expiresAt) {
      await RefreshToken.deleteOne({ _id: storedToken._id });
      return res.status(401).json({
        success: false,
        message: "Refresh token expired. Please login again.",
      });
    }

    // Look up the user based on role
    let user = null;
    let accessToken = null;
    let userResponse = null;

    if (storedToken.userModel === "User") {
      user = await User.findById(storedToken.userId).select("-password");
      if (!user) {
        await RefreshToken.deleteOne({ _id: storedToken._id });
        return res.status(401).json({
          success: false,
          message: "User no longer exists",
        });
      }
      accessToken = generateAccessToken(buildUserPayload(user));
      userResponse = buildUserResponse(user);
    } else {
      user = await ServiceProvider.findById(storedToken.userId).select(
        "-password",
      );
      if (!user) {
        await RefreshToken.deleteOne({ _id: storedToken._id });
        return res.status(401).json({
          success: false,
          message: "Service provider no longer exists",
        });
      }
      accessToken = generateAccessToken(buildSpPayload(user));
      userResponse = buildSpResponse(user);
    }

    // Token rotation: generate a new refresh token and delete the old one
    const newRefreshToken = generateRefreshToken();
    await RefreshToken.deleteOne({ _id: storedToken._id });
    await RefreshToken.create({
      token: newRefreshToken,
      userId: storedToken.userId,
      role: storedToken.role,
      userModel: storedToken.userModel,
      deviceInfo: storedToken.deviceInfo,
      expiresAt: new Date(
        Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000,
      ),
    });

    return res.status(200).json({
      success: true,
      message: "Token refreshed successfully",
      accessToken,
      refreshToken: newRefreshToken,
      user: userResponse,
    });
  } catch (err) {
    console.error("Refresh token error:", err.message);
    return res.status(500).json({
      success: false,
      message: "Server error during token refresh",
    });
  }
});

// ─── POST /auth/logout ────────────────────────────────────────────────────────
// Invalidate the refresh token on server side
router.post("/logout", async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (refreshToken) {
      await RefreshToken.deleteOne({ token: refreshToken });
    }

    return res.status(200).json({
      success: true,
      message: "Logged out successfully",
    });
  } catch (err) {
    console.error("Logout error:", err.message);
    return res.status(500).json({
      success: false,
      message: "Server error during logout",
    });
  }
});

// ─── POST /auth/logout-all ────────────────────────────────────────────────────
// Invalidate ALL refresh tokens for a user (logout from all devices)
router.post("/logout-all", async (req, res) => {
  try {
    const { userId } = req.body;

    if (userId) {
      await RefreshToken.deleteMany({ userId });
    }

    return res.status(200).json({
      success: true,
      message: "Logged out from all devices",
    });
  } catch (err) {
    console.error("Logout all error:", err.message);
    return res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

module.exports = router;
module.exports.generateRefreshToken = generateRefreshToken;
module.exports.generateAccessToken = generateAccessToken;
module.exports.buildUserPayload = buildUserPayload;
module.exports.buildSpPayload = buildSpPayload;
module.exports.buildUserResponse = buildUserResponse;
module.exports.buildSpResponse = buildSpResponse;
module.exports.buildAdminResponse = buildAdminResponse;
module.exports.REFRESH_TOKEN_EXPIRY_DAYS = REFRESH_TOKEN_EXPIRY_DAYS;
