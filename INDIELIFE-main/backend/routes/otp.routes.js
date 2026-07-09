// module.exports = router;
const express = require("express");
const router = express.Router();
const nodemailer = require("nodemailer");
const bcrypt = require("bcrypt");
const User = require("../models/user.model");
const ServiceProvider = require("../models/service-provider.model");
const Otp = require("../models/otp.model");

const emailUser = process.env.EMAIL_USER;
const emailPass = process.env.EMAIL_PASS?.replace(/\s+/g, "");

// Configure nodemailer
const transporter = nodemailer.createTransport({
  service: "gmail",
  connectionTimeout: 10000,
  greetingTimeout: 10000,
  socketTimeout: 15000,
  auth: {
    user: emailUser,
    pass: emailPass,
  },
});

function sendMailWithTimeout(mailOptions, timeoutMs = 15000) {
  return Promise.race([
    transporter.sendMail(mailOptions),
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error("OTP email send timed out")), timeoutMs),
    ),
  ]);
}

// ================================
// SIGNUP OTP ROUTES
// ================================

// Send OTP for Signup
router.post("/send-otp-signup", async (req, res) => {
  try {
    const { email, role } = req.body;
    const normalizedEmail = email.toLowerCase().trim();

    console.log("Sending OTP for signup:", { email: normalizedEmail, role });

    // Check if email already exists in either collection
    const existingUser = await User.findOne({ email: normalizedEmail });
    const existingSP = await ServiceProvider.findOne({
      email: normalizedEmail,
    });

    if (existingUser || existingSP) {
      // Provide more helpful error message indicating which account type exists
      const existingAccountType = existingUser ? "User" : "Service Provider";
      return res.status(400).json({
        status: "error",
        message: "Account already exists with this email address",
        existingAccountType: existingAccountType,
        suggestion:
          existingAccountType === "User"
            ? "This email is already registered as a User account. Please use the login page or try with a different email."
            : "This email is already registered as a Service Provider account. Please use the login page or try with a different email.",
      });
    }

    // Generate 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    // Delete any existing OTP for this email
    await Otp.deleteOne({ identifier: normalizedEmail });

    // Store OTP in database with expiration (5 minutes)
    await Otp.create({
      identifier: normalizedEmail,
      otp,
      role,
      type: "signup",
      expiresAt: new Date(Date.now() + 5 * 60 * 1000), // 5 minutes from now
      verified: false,
    });

    // Send email
    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: normalizedEmail,
      subject: "Your Email Verification OTP - IndieLife",
      html: `
    <div style="font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif; background: #FF9D42; padding: 60px 20px;">
      <div style="max-width: 480px; margin: 0 auto; background: #ffffffb6; border-radius: 20px; padding: 50px 40px; box-shadow: 0 25px 50px rgba(0,0,0,0.15); position: relative; overflow: hidden;">
        
        <!-- Top Decorative Bar -->
        <div style="position: absolute; top: 0; left: 0; right: 0; height: 6px; background: #FF9D42;"></div>
        
        <!-- Header Section -->
        <div style="text-align: center; margin: 0 0 40px 0;">
          <h2 style="color: #2d3748; margin: 0 0 8px 0; font-size: 28px; font-weight: 700; letter-spacing: -0.5px;">
            Email Verification
          </h2>
          <p style="color: #718096; margin: 0; font-size: 16px; font-weight: 400;">
            Welcome to IndieLife - Complete Your ${role} Registration
          </p>
        </div>

        <!-- Main Content -->
        <div style="color: #4a5568; line-height: 1.7;">
          <p style="margin: 0 0 32px 0; font-size: 16px; text-align: center; color: #4a5568;">
            Hello there,
            <br><br>
            Thank you for choosing <strong style="color: #2d3748;">IndieLife</strong> as your ${role.toLowerCase()} platform.
            Please use the verification code below to complete your registration:
          </p>

          <!-- OTP Display -->
          <div style="text-align: center; margin: 0 0 40px 0;">
            <div style="display: inline-block; background: #FF9D42; color: white; padding: 24px 40px; font-size: 32px; font-weight: 800; border-radius: 16px; letter-spacing: 6px; box-shadow: 0 12px 30px rgba(255, 157, 66, 0.4); border: 2px solid rgba(255,255,255,0.1);">
              ${otp}
            </div>
          </div>

          <!-- Info Card -->
          <div style="background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%); padding: 28px 24px; border-radius: 14px; border: 1px solid #e2e8f0; margin: 0 0 32px 0;">
            <div style="display: flex; align-items: flex-start; margin: 0 0 16px 0;">
              <span style="font-size: 18px; margin: 2px 12px 0 0;">⏱️</span>
              <div>
                <strong style="color: #2d3748; display: block; margin: 0 0 4px 0;">Time Sensitive</strong>
                <span style="color: #4a5568; font-size: 14px;">This OTP expires in 5 minutes</span>
              </div>
            </div>

            <div style="display: flex; align-items: flex-start; margin: 0 0 16px 0;">
              <span style="font-size: 18px; margin: 2px 12px 0 0;">🔒</span>
              <div>
                <strong style="color: #2d3748; display: block; margin: 0 0 4px 0;">Keep it Secure</strong>
                <span style="color: #4a5568; font-size: 14px;">Don't share this code with anyone</span>
              </div>
            </div>

            <div style="display: flex; align-items: flex-start;">
              <span style="font-size: 18px; margin: 2px 12px 0 0;">🎯</span>
              <div>
                <strong style="color: #2d3748; display: block; margin: 0 0 4px 0;">Role</strong>
                <span style="color: #4a5568; font-size: 14px;">You're registering as: ${role}</span>
              </div>
            </div>
          </div>

          <!-- Support Section -->
          <div style="text-align: center; padding: 24px 0 0 0; border-top: 1px solid #e2e8f0;">
            <p style="margin: 0 0 16px 0; font-size: 14px; color: #718096;">
              Need assistance? Our team is here to help
            </p>
            <a href="mailto:support@indielife.com" style="display: inline-block; background: #f8fafc; color: #FF9D42; text-decoration: none; padding: 12px 24px; border-radius: 8px; font-weight: 600; font-size: 14px; border: 1px solid #e2e8f0; transition: all 0.3s ease;">
              📧 Contact Support
            </a>
          </div>
        </div>

        <!-- Footer -->
        <div style="margin: 40px 0 0 0; padding: 24px 0 0 0; border-top: 1px solid #e2e8f0;">
          <div style="text-align: center;">
            <p style="margin: 0 0 8px 0; font-size: 12px; color: #a0aec0;">
              © ${new Date().getFullYear()} IndieLife Inc. All rights reserved.
            </p>
            <p style="margin: 0; font-size: 11px; color: #cbd5e0;">
              Building extraordinary digital experiences
            </p>
          </div>
        </div>

      </div>
    </div>
  `,
    };

    await sendMailWithTimeout(mailOptions);

    console.log("OTP sent successfully to:", email);

    res.json({
      status: "success",
      message: "OTP sent successfully to your email",
    });
  } catch (error) {
    console.error("Send OTP error:", error);
    res.status(503).json({
      status: "error",
      message:
        "Failed to send OTP email. Please try again in a moment or contact support.",
    });
  }
});

// Verify OTP for Signup
router.post("/verify-otp-signup", async (req, res) => {
  try {
    const { email, otp } = req.body;
    const normalizedEmail = email.toLowerCase().trim();

    console.log("Verifying OTP:", { email: normalizedEmail, otp });

    // Find OTP record in database
    const otpData = await Otp.findOne({
      identifier: normalizedEmail,
      type: "signup",
    });

    console.log("OTP Data Found:", otpData);

    if (!otpData) {
      return res.status(400).json({
        status: "error",
        message: "OTP not found or expired. Please request a new OTP.",
      });
    }

    if (Date.now() > otpData.expiresAt.getTime()) {
      await Otp.deleteOne({ _id: otpData._id });
      return res.status(400).json({
        status: "error",
        message: "OTP has expired. Please request a new OTP.",
      });
    }

    if (otpData.otp !== otp) {
      return res.status(400).json({
        status: "error",
        message: "Invalid OTP. Please check and try again.",
      });
    }

    // OTP verified successfully - mark email as verified in database
    await Otp.updateOne({ _id: otpData._id }, { verified: true });

    console.log("OTP verified successfully for:", normalizedEmail);

    res.json({
      status: "verified",
      message:
        "Email verified successfully! You can now complete your registration.",
      role: otpData.role,
    });
  } catch (error) {
    console.error("Verify OTP error:", error);
    res.status(500).json({
      status: "error",
      message: "Failed to verify OTP",
    });
  }
});

// ================================
// FORGOT PASSWORD OTP ROUTES
// ================================

// Send OTP for Password Reset
router.post("/send-otp", async (req, res) => {
  try {
    const { email } = req.body;
    const normalizedEmail = email.toLowerCase().trim();

    console.log("Sending OTP for password reset:", { email: normalizedEmail });

    // Check if user exists in either collection
    const user = await User.findOne({ email: normalizedEmail });
    const serviceProvider = await ServiceProvider.findOne({
      email: normalizedEmail,
    });

    if (!user && !serviceProvider) {
      return res.status(404).json({
        status: "error",
        message: "No account found with this email address",
      });
    }

    // Generate 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    // Delete any existing OTP for this email
    await Otp.deleteOne({ identifier: normalizedEmail });

    // Store OTP in database with expiration (5 minutes) for password reset
    await Otp.create({
      identifier: normalizedEmail,
      otp,
      role: "password_reset",
      type: "password_reset",
      expiresAt: new Date(Date.now() + 5 * 60 * 1000), // 5 minutes from now
      verified: false,
    });

    // Send email
    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: normalizedEmail,
      subject: "Password Reset OTP - IndieLife",
      html: `
    <div style="font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif; background: #FF9D42; padding: 60px 20px;">
      <div style="max-width: 480px; margin: 0 auto; background: #ffffffb6; border-radius: 20px; padding: 50px 40px; box-shadow: 0 25px 50px rgba(0,0,0,0.15); position: relative; overflow: hidden;">
        
        <!-- Top Decorative Bar -->
        <div style="position: absolute; top: 0; left: 0; right: 0; height: 6px; background: #FF9D42;"></div>
        
        <!-- Header Section -->
        <div style="text-align: center; margin: 0 0 40px 0;">
          <h2 style="color: #2d3748; margin: 0 0 8px 0; font-size: 28px; font-weight: 700; letter-spacing: -0.5px;">
            Password Reset
          </h2>
          <p style="color: #718096; margin: 0; font-size: 16px; font-weight: 400;">
            Your IndieLife Account Security
          </p>
        </div>

        <!-- Main Content -->
        <div style="color: #4a5568; line-height: 1.7;">
          <p style="margin: 0 0 32px 0; font-size: 16px; text-align: center; color: #4a5568;">
            Hello there,
            <br><br>
            We received a request to reset your password for your 
            <strong style="color: #2d3748;">IndieLife</strong> account.
            Please use the verification code below:
          </p>

          <!-- OTP Display -->
          <div style="text-align: center; margin: 0 0 40px 0;">
            <div style="display: inline-block; background: #FF9D42; color: white; padding: 24px 40px; font-size: 32px; font-weight: 800; border-radius: 16px; letter-spacing: 6px; box-shadow: 0 12px 30px rgba(255, 157, 66, 0.4); border: 2px solid rgba(255,255,255,0.1);">
              ${otp}
            </div>
          </div>

          <!-- Info Card -->
          <div style="background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%); padding: 28px 24px; border-radius: 14px; border: 1px solid #e2e8f0; margin: 0 0 32px 0;">
            <div style="display: flex; align-items: flex-start; margin: 0 0 16px 0;">
              <span style="font-size: 18px; margin: 2px 12px 0 0;">⏱️</span>
              <div>
                <strong style="color: #2d3748; display: block; margin: 0 0 4px 0;">Time Sensitive</strong>
                <span style="color: #4a5568; font-size: 14px;">This OTP expires in 5 minutes</span>
              </div>
            </div>

            <div style="display: flex; align-items: flex-start; margin: 0 0 16px 0;">
              <span style="font-size: 18px; margin: 2px 12px 0 0;">🔒</span>
              <div>
                <strong style="color: #2d3748; display: block; margin: 0 0 4px 0;">Keep it Secure</strong>
                <span style="color: #4a5568; font-size: 14px;">Don't share this code with anyone</span>
              </div>
            </div>

            <div style="display: flex; align-items: flex-start;">
              <span style="font-size: 18px; margin: 2px 12px 0 0;">❓</span>
              <div>
                <strong style="color: #2d3748; display: block; margin: 0 0 4px 0;">Not You?</strong>
                <span style="color: #4a5568; font-size: 14px;">Ignore this email if you didn't request this</span>
              </div>
            </div>
          </div>

          <!-- Support Section -->
          <div style="text-align: center; padding: 24px 0 0 0; border-top: 1px solid #e2e8f0;">
            <p style="margin: 0 0 16px 0; font-size: 14px; color: #718096;">
              Need assistance? Our team is here to help
            </p>
            <a href="mailto:support@indielife.com" style="display: inline-block; background: #f8fafc; color: #FF9D42; text-decoration: none; padding: 12px 24px; border-radius: 8px; font-weight: 600; font-size: 14px; border: 1px solid #e2e8f0; transition: all 0.3s ease;">
              📧 Contact Support
            </a>
          </div>
        </div>

        <!-- Footer -->
        <div style="margin: 40px 0 0 0; padding: 24px 0 0 0; border-top: 1px solid #e2e8f0;">
          <div style="text-align: center;">
            <p style="margin: 0 0 8px 0; font-size: 12px; color: #a0aec0;">
              © ${new Date().getFullYear()} IndieLife Inc. All rights reserved.
            </p>
            <p style="margin: 0; font-size: 11px; color: #cbd5e0;">
              Building extraordinary digital experiences
            </p>
          </div>
        </div>

      </div>
    </div>
  `,
    };

    await transporter.sendMail(mailOptions);

    console.log("Password reset OTP sent successfully to:", normalizedEmail);

    res.json({
      status: "success",
      message: "OTP sent successfully to your email",
    });
  } catch (error) {
    console.error("Send OTP error:", error);
    res.status(500).json({
      status: "error",
      message: "Failed to send OTP",
    });
  }
});

// Verify OTP for Password Reset
router.post("/verify-otp", async (req, res) => {
  try {
    const { email, otp } = req.body;
    const normalizedEmail = email.toLowerCase().trim();

    console.log("Verifying password reset OTP:", {
      email: normalizedEmail,
      otp,
    });

    // Find OTP record in database for password reset
    const otpData = await Otp.findOne({
      identifier: normalizedEmail,
      type: "password_reset",
    });

    if (!otpData) {
      return res.status(400).json({
        status: "error",
        message: "OTP not found or expired. Please request a new OTP.",
      });
    }

    if (Date.now() > otpData.expiresAt.getTime()) {
      await Otp.deleteOne({ _id: otpData._id });
      return res.status(400).json({
        status: "error",
        message: "OTP has expired. Please request a new OTP.",
      });
    }

    if (otpData.otp !== otp) {
      return res.status(400).json({
        status: "error",
        message: "Invalid OTP. Please check and try again.",
      });
    }

    // OTP verified successfully - mark as verified for password reset
    await Otp.updateOne({ _id: otpData._id }, { verified: true });

    console.log(
      "Password reset OTP verified successfully for:",
      normalizedEmail,
    );

    res.json({
      status: "verified",
      message: "OTP verified successfully! You can now reset your password.",
    });
  } catch (error) {
    console.error("Verify OTP error:", error);
    res.status(500).json({
      status: "error",
      message: "Failed to verify OTP",
    });
  }
});

// Reset Password
router.post("/reset-password", async (req, res) => {
  try {
    const { email, newPassword } = req.body;
    const normalizedEmail = email.toLowerCase().trim();

    console.log("Resetting password for:", normalizedEmail);

    // Check if OTP was verified in database
    const otpData = await Otp.findOne({
      identifier: normalizedEmail,
      type: "password_reset",
      verified: true,
    });

    if (!otpData) {
      return res.status(400).json({
        status: "error",
        message: "Please verify your OTP first before resetting password",
      });
    }

    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    // Update password in both collections using findOneAndUpdate to avoid validation issues
    let updateResult = await User.findOneAndUpdate(
      { email: normalizedEmail },
      { password: hashedPassword },
      { new: true },
    );

    if (updateResult) {
      console.log("Password updated for user:", normalizedEmail);
    } else {
      updateResult = await ServiceProvider.findOneAndUpdate(
        { email: normalizedEmail },
        { password: hashedPassword },
        { new: true },
      );

      if (updateResult) {
        console.log("Password updated for service provider:", normalizedEmail);
      } else {
        return res.status(404).json({
          status: "error",
          message: "User not found",
        });
      }
    }

    // Clear OTP data after successful password reset
    await Otp.deleteOne({
      identifier: normalizedEmail,
      type: "password_reset",
    });

    res.json({
      status: "success",
      message: "Password reset successfully",
    });
  } catch (error) {
    console.error("Reset password error:", error);
    res.status(500).json({
      status: "error",
      message: "Failed to reset password",
    });
  }
});

// Check if email is verified
router.post("/check-email-verified", async (req, res) => {
  try {
    const { email } = req.body;

    // Find verified OTP in database for signup
    const otpData = await Otp.findOne({
      identifier: email,
      type: "signup",
      verified: true,
    });

    if (otpData) {
      res.json({ verified: true });
    } else {
      res.json({ verified: false });
    }
  } catch (error) {
    console.error("Check email verified error:", error);
    res.status(500).json({ verified: false });
  }
});

module.exports = router;
