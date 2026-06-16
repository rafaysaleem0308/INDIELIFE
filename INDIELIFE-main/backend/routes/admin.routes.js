const express = require("express");
const router = express.Router();
const User = require("../models/user.model");
const ServiceProvider = require("../models/service-provider.model");
const Order = require("../models/order.model");
const HousingBooking = require("../models/housing-booking.model");
const HousingProperty = require("../models/housing-property.model");
const Message = require("../models/message.model");
const Chat = require("../models/chat.model");
const Settings = require("../models/settings.model");
const Service = require("../models/service.model");
const { verifyToken, requireRole } = require("../middleware/auth");
const {
  buildAdminResponse,
  generateAccessToken,
  generateRefreshToken,
  buildSpPayload,
  REFRESH_TOKEN_EXPIRY_DAYS,
} = require("./auth.routes");
const RefreshToken = require("../models/refresh-token.model");
const bcrypt = require("bcrypt");

// ─── ADMIN LOGIN ─────────────────────────────────────────────────────────────
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res
        .status(400)
        .json({ success: false, message: "Email and password are required" });
    }

    const user = await User.findOne({ email, role: "admin" });
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid credentials or not an admin",
      });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res
        .status(401)
        .json({ success: false, message: "Invalid credentials" });
    }

    const accessToken = generateAccessToken({
      userId: user._id,
      email: user.email,
      role: "admin",
      firstName: user.firstName,
      lastName: user.lastName,
    });

    const refreshToken = generateRefreshToken();

    await RefreshToken.create({
      token: refreshToken,
      userId: user._id.toString(),
      role: "admin",
      userModel: "User",
      deviceInfo: req.headers["user-agent"] || "unknown",
      expiresAt: new Date(
        Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000,
      ),
    });

    res.status(200).json({
      success: true,
      accessToken,
      refreshToken,
      user: buildAdminResponse(user),
    });
  } catch (error) {
    console.error("Admin login error:", error.message);
    res
      .status(500)
      .json({ success: false, message: "Server error during login" });
  }
});

// Helper to get or create settings
const getSettings = async () => {
  let settings = await Settings.findOne();
  if (!settings) {
    settings = await Settings.create({});
  }
  return settings;
};

// ─── DASHBOARD STATS ──────────────────────────────────────────────────────────
router.get(
  "/dashboard-stats",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const totalUsers = await User.countDocuments({ role: "user" });
      const totalProviders = await ServiceProvider.countDocuments();
      const totalBookings = await Order.countDocuments();
      const pendingApprovals = await ServiceProvider.countDocuments({
        status: "pending",
      });
      const activeProviders = await ServiceProvider.countDocuments({
        status: "approved",
      });
      const suspendedProviders = await ServiceProvider.countDocuments({
        status: "suspended",
      });

      // Total Revenue calculation
      const revenueData = await Order.aggregate([
        { $match: { paymentStatus: "Completed" } },
        {
          $group: {
            _id: null,
            total: { $sum: "$totalAmount" },
            commission: { $sum: "$platformCommission" },
          },
        },
      ]);

      const totalRevenue = revenueData.length > 0 ? revenueData[0].total : 0;
      const totalCommission =
        revenueData.length > 0 ? revenueData[0].commission : 0;

      // Pending payouts (revenue minus commission for non-settled orders)
      const pendingPayoutData = await Order.aggregate([
        { $match: { paymentStatus: "Completed" } },
        { $group: { _id: null, total: { $sum: "$providerEarnings" } } },
      ]);
      const pendingPayouts =
        pendingPayoutData.length > 0 ? pendingPayoutData[0].total : 0;

      // Recent orders count (last 24h)
      const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
      const recentOrders = await Order.countDocuments({
        createdAt: { $gte: oneDayAgo },
      });

      // Charts data (Last 30 days)
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const userGrowth = await User.aggregate([
        { $match: { createdAt: { $gte: thirtyDaysAgo }, role: "user" } },
        {
          $group: {
            _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } },
            count: { $sum: 1 },
          },
        },
        { $sort: { _id: 1 } },
      ]);

      const bookingGrowth = await Order.aggregate([
        { $match: { createdAt: { $gte: thirtyDaysAgo } } },
        {
          $group: {
            _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } },
            count: { $sum: 1 },
          },
        },
        { $sort: { _id: 1 } },
      ]);

      const revenueGrowth = await Order.aggregate([
        {
          $match: {
            createdAt: { $gte: thirtyDaysAgo },
            paymentStatus: "Completed",
          },
        },
        {
          $group: {
            _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } },
            total: { $sum: "$totalAmount" },
          },
        },
        { $sort: { _id: 1 } },
      ]);

      // Recent bookings for quick view
      const recentBookings = await Order.find()
        .sort({ createdAt: -1 })
        .limit(5)
        .select(
          "orderNumber name providerServiceName totalAmount status createdAt",
        );

      res.status(200).json({
        success: true,
        stats: {
          totalUsers,
          totalProviders,
          totalBookings,
          totalRevenue,
          totalCommission,
          pendingApprovals,
          activeProviders,
          suspendedProviders,
          pendingPayouts,
          recentOrders,
        },
        charts: {
          userGrowth,
          bookingGrowth,
          revenueGrowth,
        },
        recentBookings,
      });
    } catch (error) {
      console.error("Dashboard stats error:", error.message);
      res
        .status(500)
        .json({ success: false, message: "Failed to fetch dashboard stats" });
    }
  },
);

// ─── PROVIDER MANAGEMENT ──────────────────────────────────────────────────────
router.get(
  "/providers",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const { status, spSubRole } = req.query;
      const query = {};
      if (status) query.status = status;
      if (spSubRole) query.spSubRole = spSubRole;
      const providers = await ServiceProvider.find(query).sort({
        createdAt: -1,
      });
      res.status(200).json({ success: true, providers });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

router.get(
  "/providers/:id",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const provider = await ServiceProvider.findById(req.params.id);
      if (!provider) {
        return res
          .status(404)
          .json({ success: false, message: "Provider not found" });
      }
      res.status(200).json({ success: true, provider });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

router.patch(
  "/providers/:id/status",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const { status } = req.body;
      if (!["pending", "approved", "rejected", "suspended"].includes(status)) {
        return res
          .status(400)
          .json({ success: false, message: "Invalid status value" });
      }

      const provider = await ServiceProvider.findByIdAndUpdate(
        req.params.id,
        {
          status,
          isVerified: status === "approved",
          isActive: status === "approved",
        },
        { new: true },
      );

      if (!provider) {
        return res
          .status(404)
          .json({ success: false, message: "Provider not found" });
      }

      // If approved, create auth tokens
      let tokens = null;
      if (status === "approved") {
        const accessToken = generateAccessToken(buildSpPayload(provider));
        const refreshToken = generateRefreshToken();

        await RefreshToken.create({
          token: refreshToken,
          userId: provider._id.toString(),
          role: "service_provider",
          userModel: "ServiceProvider",
          expiresAt: new Date(
            Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000,
          ),
        });

        tokens = { accessToken, refreshToken };
      }

      // Also update the linked User record if exists
      await User.updateMany(
        { spId: provider._id, role: "service_provider" },
        { isVerified: status === "approved" },
      );

      res.status(200).json({
        success: true,
        message: `Provider ${status} successfully`,
        provider,
        tokens,
      });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

router.delete(
  "/providers/:id",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const provider = await ServiceProvider.findByIdAndDelete(req.params.id);
      if (!provider) {
        return res
          .status(404)
          .json({ success: false, message: "Provider not found" });
      }
      res
        .status(200)
        .json({ success: true, message: "Provider deleted successfully" });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

// ─── USER MANAGEMENT ──────────────────────────────────────────────────────────
router.get("/users", verifyToken, requireRole("admin"), async (req, res) => {
  try {
    const users = await User.find({ role: "user" })
      .sort({ createdAt: -1 })
      .select("-password");
    res.status(200).json({ success: true, users });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get(
  "/users/:id",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const user = await User.findById(req.params.id).select("-password");
      if (!user)
        return res
          .status(404)
          .json({ success: false, message: "User not found" });
      res.status(200).json({ success: true, user });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

router.patch(
  "/users/:id/status",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const { accountStatus } = req.body;
      if (!["active", "suspended", "deactivated"].includes(accountStatus)) {
        return res
          .status(400)
          .json({ success: false, message: "Invalid status value" });
      }
      const user = await User.findByIdAndUpdate(
        req.params.id,
        { accountStatus },
        { new: true },
      ).select("-password");
      if (!user)
        return res
          .status(404)
          .json({ success: false, message: "User not found" });
      res.status(200).json({ success: true, user });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

router.delete(
  "/users/:id",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const user = await User.findByIdAndDelete(req.params.id);
      if (!user)
        return res
          .status(404)
          .json({ success: false, message: "User not found" });
      res
        .status(200)
        .json({ success: true, message: "User deleted successfully" });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

// ─── BOOKING MANAGEMENT ───────────────────────────────────────────────────────
router.get("/bookings", verifyToken, requireRole("admin"), async (req, res) => {
  try {
    const { status, serviceType, type } = req.query; // type: "service", "housing", or undefined for all

    let bookings = [];

    // Fetch service/order bookings
    if (!type || type === "service") {
      const orderQuery = {};
      if (status) orderQuery.status = status;
      if (serviceType) orderQuery["items.serviceType"] = serviceType;

      const orders = await Order.find(orderQuery)
        .populate("customerId", "firstName lastName email phone")
        .populate("serviceProviderSpId", "firstName lastName email phone")
        .sort({ createdAt: -1 })
        .lean();

      // Add bookingType to distinguish from housing
      const formattedOrders = orders.map((o) => ({
        ...o,
        bookingType: "service",
        displayName: o.name || `${o.firstName} ${o.lastName}`,
        displayProvider: o.providerName,
      }));

      bookings.push(...formattedOrders);
    }

    // Fetch housing bookings
    if (!type || type === "housing") {
      try {
        const housingQuery = {};
        if (status) housingQuery.status = status;

        const housingBookings = await HousingBooking.find(housingQuery)
          .populate("tenantId", "firstName lastName email phone")
          .populate("ownerId", "firstName lastName email phone")
          .populate("propertyId", "title city address")
          .sort({ createdAt: -1 })
          .lean();

        // Format housing bookings to match Order structure for admin display
        const formattedHousing = housingBookings.map((h) => ({
          ...h,
          bookingType: "housing",
          orderNumber: h.bookingNumber,
          displayName:
            h.tenantName ||
            (h.tenantId
              ? `${h.tenantId.firstName} ${h.tenantId.lastName}`
              : "N/A"),
          displayProvider: h.ownerName,
          items: [
            {
              serviceName: `Housing Booking - ${h.propertyTitle}`,
              serviceType: h.propertyType,
              unitPrice: h.monthlyRent,
              totalPrice: h.totalAmount,
            },
          ],
          deliveryAddress: h.propertyAddress,
        }));

        bookings.push(...formattedHousing);
      } catch (hErr) {
        console.error("[ERROR] Housing booking fetch error:", hErr);
      }
    }

    // Sort all by date
    bookings = bookings.sort(
      (a, b) => new Date(b.createdAt) - new Date(a.createdAt),
    );

    res.status(200).json({ success: true, bookings });
  } catch (error) {
    console.error("Error fetching bookings:", error);
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get(
  "/bookings/:id",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const booking = await Order.findById(req.params.id);
      if (!booking)
        return res
          .status(404)
          .json({ success: false, message: "Booking not found" });
      res.status(200).json({ success: true, booking });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

router.patch(
  "/bookings/:id/cancel",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const reason = sanitizeString(req.body.reason || "Cancelled by Admin");
      const booking = await Order.findByIdAndUpdate(
        req.params.id,
        {
          status: "Cancelled",
          cancellationReason: reason,
          cancellationDate: new Date(),
        },
        { new: true },
      );
      if (!booking)
        return res
          .status(404)
          .json({ success: false, message: "Booking not found" });
      res
        .status(200)
        .json({ success: true, message: "Booking cancelled", booking });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

router.patch(
  "/bookings/:id/status",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const { status } = req.body;
      const booking = await Order.findByIdAndUpdate(
        req.params.id,
        { status },
        { new: true },
      );
      if (!booking)
        return res
          .status(404)
          .json({ success: false, message: "Booking not found" });
      res.status(200).json({ success: true, booking });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

// ─── CHAT MONITORING ──────────────────────────────────────────────────────────
router.get("/chats", verifyToken, requireRole("admin"), async (req, res) => {
  try {
    const chats = await Chat.find()
      .populate("lastMessage")
      .sort({ updatedAt: -1 })
      .lean();

    // Manually populate participant details for the nested schema
    for (const chat of chats) {
      if (chat.participants && chat.participants.length > 0) {
        for (let i = 0; i < chat.participants.length; i++) {
          const p = chat.participants[i];
          const Model = p.modelType === "User" ? User : ServiceProvider;
          const userData = await Model.findById(p.user)
            .select("firstName lastName email role profileImage spSubRole")
            .lean();
          chat.participants[i] = {
            ...p,
            details: userData || { firstName: "Unknown", lastName: "User" },
          };
        }
      }
    }

    res.status(200).json({ success: true, chats });
  } catch (error) {
    console.error("Chats fetch error:", error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get(
  "/chats/:chatId/messages",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const messages = await Message.find({ chatId: req.params.chatId })
        .sort({ createdAt: 1 })
        .lean();

      // Populate sender info
      for (const msg of messages) {
        let sender = await User.findById(msg.senderId)
          .select("firstName lastName role")
          .lean();
        if (!sender) {
          sender = await ServiceProvider.findById(msg.senderId)
            .select("firstName lastName spSubRole")
            .lean();
        }
        msg.senderInfo = sender || { firstName: "Unknown", lastName: "" };
      }

      res.status(200).json({ success: true, messages });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

// ─── PAYMENT & COMMISSION ─────────────────────────────────────────────────────
router.get("/payments", verifyToken, requireRole("admin"), async (req, res) => {
  try {
    const payments = await Order.find({
      paymentStatus: { $in: ["Completed", "Pending"] },
    })
      .sort({ createdAt: -1 })
      .select(
        "orderNumber name providerName totalAmount platformCommission providerEarnings paymentMethod paymentStatus createdAt",
      );
    res.status(200).json({ success: true, payments });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ─── NOTIFICATIONS ────────────────────────────────────────────────────────────
router.post(
  "/notifications/send",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const { target, specificId } = req.body;
      const title = sanitizeString(req.body.title);
      const message = sanitizeString(req.body.message);

      if (!title || !message) {
        return res
          .status(400)
          .json({ success: false, message: "Title and message are required" });
      }

      // Build the target query
      let targetUsers = [];

      if (target === "all") {
        // Get all regular users
        const users = await User.find({ role: "user" }).select("_id").lean();

        // Get all service providers (from ServiceProvider model)
        const providers = await ServiceProvider.find().select("_id").lean();

        targetUsers = [...users, ...providers.map((p) => ({ _id: p._id }))];
      } else if (target === "users") {
        targetUsers = await User.find({ role: "user" }).select("_id").lean();
      } else if (target === "providers") {
        // Get service providers from ServiceProvider model
        const providers = await ServiceProvider.find().select("_id").lean();
        targetUsers = providers.map((p) => ({ _id: p._id }));
      } else if (target === "specific" && specificId) {
        targetUsers = [{ _id: specificId }];
      }

      // Create DB Notification & Emit via Socket.IO
      const io = req.app.get("io");
      const Notification = require("../models/notification.model");

      console.log(
        `Creating notifications for ${targetUsers.length} recipients (target: ${target})`,
      );

      const notificationPromises = targetUsers.map(async (u) => {
        try {
          const notif = await Notification.create({
            userId: u._id,
            title,
            body: message,
            type: "admin_broadcast",
            icon: "campaign",
          });

          console.log(`✓ Notification created for user ${u._id}`);

          if (io) {
            // Must perfectly match the Flutter app's socket listener logic
            io.to(u._id.toString()).emit("new_notification", notif);
            // Maintain legacy emit just in case
            io.to(u._id.toString()).emit("notification", {
              title,
              message,
              type: "admin_broadcast",
              createdAt: new Date(),
            });
          }
        } catch (err) {
          console.error(
            `✗ Error creating notification for user ${u._id}:`,
            err.message,
          );
          throw err;
        }
      });

      const results = await Promise.allSettled(notificationPromises);
      const successful = results.filter((r) => r.status === "fulfilled").length;
      const failed = results.filter((r) => r.status === "rejected").length;

      if (failed > 0) {
        console.warn(
          `Notifications: ${successful} successful, ${failed} failed`,
        );
      }

      res.status(200).json({
        success: true,
        message: `Notification sent to ${targetUsers.length} recipient(s)`,
        recipientCount: targetUsers.length,
        successful,
        failed,
      });
    } catch (error) {
      console.error("Notification send error:", error.message);
      console.error("Full error:", error);
      res.status(500).json({
        success: false,
        message: `Failed to send notification: ${error.message}`,
      });
    }
  },
);

// ─── SETTINGS ─────────────────────────────────────────────────────────────────
router.get("/settings", verifyToken, requireRole("admin"), async (req, res) => {
  try {
    const settings = await getSettings();
    res.status(200).json({ success: true, settings });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put("/settings", verifyToken, requireRole("admin"), async (req, res) => {
  try {
    const settings = await Settings.findOneAndUpdate({}, req.body, {
      new: true,
      upsert: true,
    });
    res.status(200).json({ success: true, settings });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ════════════════════════════════════════════════════════════════════════════════
// HOUSING MANAGEMENT — Admin
// ════════════════════════════════════════════════════════════════════════════════

// GET /api/admin/housing — List all properties (filterable by status)
router.get("/housing", verifyToken, requireRole("admin"), async (req, res) => {
  try {
    const { status, city, propertyType, page = 1, limit = 50 } = req.query;
    let query = {};
    if (status) query.status = status;
    if (city) query.city = new RegExp(city, "i");
    if (propertyType) query.propertyType = propertyType;

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const [properties, total] = await Promise.all([
      HousingProperty.find(query)
        .populate("ownerId", "firstName lastName email phone city profileImage")
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(parseInt(limit))
        .lean(),
      HousingProperty.countDocuments(query),
    ]);

    res.json({
      success: true,
      properties,
      total,
      page: parseInt(page),
      totalPages: Math.ceil(total / parseInt(limit)),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/admin/housing/stats — Housing stats for admin dashboard
router.get(
  "/housing/stats",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const [
        total,
        pending,
        approved,
        rejected,
        suspended,
        totalBookings,
        pendingBookings,
      ] = await Promise.all([
        HousingProperty.countDocuments(),
        HousingProperty.countDocuments({ status: "pending_approval" }),
        HousingProperty.countDocuments({ status: "approved" }),
        HousingProperty.countDocuments({ status: "rejected" }),
        HousingProperty.countDocuments({ status: "suspended" }),
        HousingBooking.countDocuments(),
        HousingBooking.countDocuments({ status: "Pending" }),
      ]);

      const earningsAgg = await HousingBooking.aggregate([
        { $match: { paymentStatus: "Completed" } },
        { $group: { _id: null, total: { $sum: "$platformCommission" } } },
      ]);

      res.json({
        success: true,
        stats: {
          total,
          pending,
          approved,
          rejected,
          suspended,
          totalBookings,
          pendingBookings,
          platformEarnings: earningsAgg[0]?.total || 0,
        },
      });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

// GET /api/admin/housing/:id — Single property detail
router.get(
  "/housing/:id",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      let property = await HousingProperty.findById(req.params.id)
        .populate(
          "ownerId",
          "firstName lastName email phone city address profileImage createdAt",
        )
        .lean();

      // Handle legacy hostel fallback
      if (!property) {
        const legacy = await Service.findById(req.params.id)
          .populate("serviceProviderId")
          .lean();
        if (legacy && legacy.serviceType === "Hostel/Flat Accommodation") {
          property = {
            _id: legacy._id,
            title: legacy.serviceName || legacy.title,
            description: legacy.description,
            propertyType: "Hostel",
            monthlyRent: legacy.price,
            status:
              legacy.status === "Active" ? "approved" : "pending_approval",
            city: legacy.serviceProviderCity || "Local",
            address: legacy.address,
            isLegacy: true,
            ownerId: legacy.serviceProviderId,
          };
        }
      }

      if (!property)
        return res
          .status(404)
          .json({ success: false, message: "Property not found" });
      res.json({ success: true, property });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

// PATCH /api/admin/housing/:id/status — Approve/Reject/Suspend property
router.patch(
  "/housing/:id/status",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const { status, rejectionReason } = req.body;
      const validStatuses = [
        "approved",
        "rejected",
        "suspended",
        "pending_approval",
      ];
      if (!validStatuses.includes(status)) {
        return res.status(400).json({
          success: false,
          message: `Invalid status. Must be one of: ${validStatuses.join(", ")}`,
        });
      }

      const updateData = { status };
      if (status === "approved") {
        updateData.approvedBy = req.user.userId || req.user._id;
        updateData.approvedAt = new Date();
      }
      if (status === "rejected" && rejectionReason) {
        updateData.rejectionReason = rejectionReason;
      }

      let property = await HousingProperty.findByIdAndUpdate(
        req.params.id,
        updateData,
        { new: true },
      ).populate("ownerId", "firstName lastName email");

      // Handle legacy hostel fallback
      if (!property) {
        const legacyStatusMap = {
          approved: "Active",
          rejected: "Inactive",
          suspended: "Suspended",
          pending_approval: "Pending",
        };
        const legacy = await Service.findOneAndUpdate(
          { _id: req.params.id, serviceType: "Hostel/Flat Accommodation" },
          { status: legacyStatusMap[status] || "Active" },
          { new: true },
        );
        if (legacy) {
          property = {
            _id: legacy._id,
            title: legacy.serviceName || legacy.title,
            status,
          };
        }
      }

      // Notify the owner
      const Notification = require("../models/notification.model");
      const ownerUser = await User.findOne({
        spId: property.ownerId._id || property.ownerId,
      });
      if (ownerUser) {
        await Notification.create({
          userId: ownerUser._id,
          title:
            status === "approved"
              ? "Property Approved!"
              : status === "rejected"
                ? "Property Rejected"
                : "Property Suspended",
          body:
            status === "approved"
              ? `Your property "${property.title}" has been approved and is now live!`
              : status === "rejected"
                ? `Your property "${property.title}" was rejected. Reason: ${rejectionReason || "Not specified"}`
                : `Your property "${property.title}" has been suspended.`,
          type: "system",
          referenceId: property._id.toString(),
        });
      }

      res.json({ success: true, message: `Property ${status}`, property });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

// DELETE /api/admin/housing/:id — Admin delete property
router.delete(
  "/housing/:id",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      let property = await HousingProperty.findByIdAndDelete(req.params.id);

      // Handle legacy hostel fallback
      if (!property) {
        property = await Service.findOneAndDelete({
          _id: req.params.id,
          serviceType: "Hostel/Flat Accommodation",
        });
      }

      if (!property)
        return res
          .status(404)
          .json({ success: false, message: "Property not found" });
      res.json({ success: true, message: "Property deleted by admin" });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

// GET /api/admin/housing-bookings — All housing bookings
router.get(
  "/housing-bookings",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const { status, page = 1, limit = 50 } = req.query;
      let query = {};
      if (status) query.status = status;

      const skip = (parseInt(page) - 1) * parseInt(limit);
      const [bookings, total] = await Promise.all([
        HousingBooking.find(query)
          .populate("propertyId", "title city address propertyType images")
          .populate("tenantId", "firstName lastName email phone")
          .sort({ createdAt: -1 })
          .skip(skip)
          .limit(parseInt(limit))
          .lean(),
        HousingBooking.countDocuments(query),
      ]);

      res.json({
        success: true,
        bookings,
        total,
        page: parseInt(page),
        totalPages: Math.ceil(total / parseInt(limit)),
      });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

// ─── ADMIN: SERVICES ─────────────────────────────────────────────────────────
// GET /api/admin/services — All services with provider info
router.get("/services", verifyToken, requireRole("admin"), async (req, res) => {
  try {
    const { serviceType, status } = req.query;
    let query = {};
    if (serviceType) query.serviceType = serviceType;
    if (status) query.status = status;
    const services = await Service.find(query)
      .populate(
        "serviceProviderId",
        "firstName lastName email phone city spSubRole",
      )
      .sort({ createdAt: -1 })
      .lean();
    const enriched = services.map((s) => {
      const provider = s.serviceProviderId;

      // Try to get name from provider, fall back to serviceProviderName field
      let providerName = "N/A";
      if (provider && (provider.firstName || provider.lastName)) {
        providerName =
          `${provider.firstName || ""} ${provider.lastName || ""}`.trim();
      } else if (s.serviceProviderName) {
        providerName = s.serviceProviderName;
      }

      return {
        ...s,
        providerName: providerName,
        providerEmail: provider?.email || s.serviceProviderEmail || "N/A",
        providerPhone: provider?.phone || s.serviceProviderPhone || "N/A",
        providerCity: provider?.city || s.serviceProviderCity || "N/A",
      };
    });
    res.json({ success: true, services: enriched, total: enriched.length });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/admin/services/:id — Get single service details
router.get(
  "/services/:id",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const service = await Service.findById(req.params.id)
        .populate("serviceProviderId", "firstName lastName email phone city")
        .lean();

      if (!service) {
        return res
          .status(404)
          .json({ success: false, message: "Service not found" });
      }

      // Enrich with provider info
      const provider = service.serviceProviderId;
      let providerName = "N/A";
      if (provider && (provider.firstName || provider.lastName)) {
        providerName =
          `${provider.firstName || ""} ${provider.lastName || ""}`.trim();
      } else if (service.serviceProviderName) {
        providerName = service.serviceProviderName;
      }

      const enriched = {
        ...service,
        providerName: providerName,
        providerEmail: provider?.email || service.serviceProviderEmail || "N/A",
        providerPhone: provider?.phone || service.serviceProviderPhone || "N/A",
        providerCity: provider?.city || service.serviceProviderCity || "N/A",
      };

      res.json({ success: true, service: enriched });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

// PATCH /api/admin/services/:id/status — Activate / Deactivate a service
router.patch(
  "/services/:id/status",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      const { status } = req.body;
      const service = await Service.findByIdAndUpdate(
        req.params.id,
        { status },
        { new: true },
      );
      if (!service)
        return res
          .status(404)
          .json({ success: false, message: "Service not found" });
      res.json({ success: true, message: `Service ${status}`, service });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

// DELETE /api/admin/services/:id — Remove a service
router.delete(
  "/services/:id",
  verifyToken,
  requireRole("admin"),
  async (req, res) => {
    try {
      await Service.findByIdAndDelete(req.params.id);
      res.json({ success: true, message: "Service deleted by admin" });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

module.exports = router;
