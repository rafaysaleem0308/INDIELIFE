require("dotenv").config();

const express = require("express");
const cors = require("cors");
const http = require("http");
const fs = require("fs");
const { Server } = require("socket.io");
const { validateEnvironment } = require("./utils/env");

validateEnvironment();

// Ensure uploads directory exists (it's gitignored)
fs.mkdirSync("uploads", { recursive: true });

const { connectDatabase } = require("./config/database");
const {
  globalLimiter,
  authLimiter,
  otpLimiter,
  paymentLimiter,
  signupLimiter,
} = require("./middleware/rateLimit");

// ─── Initialize Express App ───────────────────────────────────────────────────
const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 3000;
const allowedOrigins = [
  process.env.ADMIN_ORIGIN,
  process.env.MOBILE_ORIGIN,
  process.env.FRONTEND_ORIGIN,
  "http://localhost:5173",
  "http://localhost:3000",
]
  .filter(Boolean)
  .map((origin) => origin.replace(/\/$/, ""));

const corsOptions = {
  origin(origin, callback) {
    if (!origin || process.env.NODE_ENV !== "production") {
      return callback(null, true);
    }

    const normalizedOrigin = origin.replace(/\/$/, "");
    if (allowedOrigins.includes(normalizedOrigin)) {
      return callback(null, true);
    }

    return callback(new Error(`CORS blocked origin: ${origin}`));
  },
  credentials: true,
};

const io = new Server(server, { cors: corsOptions });

// ─── CRITICAL: Stripe Webhook Route (must be BEFORE express.json()) ──────────
// Stripe requires the raw unparsed body to verify webhook signatures
const webhookRoutes = require("./routes/webhook.routes");
app.use("/stripe/webhook", webhookRoutes);

// ─── Middleware ───────────────────────────────────────────────────────────────
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));
app.use(cors(corsOptions));

// ─── SECURITY: Apply Global Rate Limiter ──────────────────────────────────────
app.use(globalLimiter);

// ─── Request Logger ──────────────────────────────────────────────────────────
app.use((req, res, next) => {
  const timestamp = new Date().toLocaleTimeString();
  console.log(`[${timestamp}] ${req.method} ${req.url}`);
  next();
});

// ─── Pass Socket.io to Routes ────────────────────────────────────────────────
app.set("io", io);

// ─── Socket.io Connection ────────────────────────────────────────────────────
io.on("connection", (socket) => {
  console.log("🔌 User connected:", socket.id);

  socket.on("join", (userId) => {
    socket.join(userId);
    console.log(`👤 User ${userId} joined their room`);
  });

  socket.on("disconnect", () => {
    console.log("🔌 User disconnected:", socket.id);
  });
});

// ─── Static Files ────────────────────────────────────────────────────────────
app.use("/uploads", express.static("uploads"));

// ─── API Routes ──────────────────────────────────────────────────────────────
const userRoutes = require("./routes/user.routes");
const spRoutes = require("./routes/service-provider.routes");
const otpRoutes = require("./routes/otp.routes");
const serviceRoutes = require("./routes/service.routes");
const orderRoutes = require("./routes/order.routes");
const chatRoutes = require("./routes/chat.routes");
const reviewRoutes = require("./routes/review.routes");
const notificationRoutes = require("./routes/notification.routes");
const authRoutes = require("./routes/auth.routes");
const adminRoutes = require("./routes/admin.routes");
const housingRoutes = require("./routes/housing.routes");
const cartRoutes = require("./routes/cart.routes");
const paymentRoutes = require("./routes/payment.routes");
const communityRoutes = require("./routes/community.routes");
const recommendationsRoutes = require("./routes/recommendations.routes");

app.use("/api/orders", orderRoutes);
app.use("/signup/user", signupLimiter, userRoutes);
app.use("/signup/service-provider", signupLimiter, spRoutes);
app.use("/auth", otpLimiter, otpRoutes); // OTP routes with rate limiting
app.use("/auth", authLimiter, authRoutes); // Auth routes with rate limiting
app.use("/api/services", serviceRoutes);
app.use("/api/housing", housingRoutes);
app.use("/api/cart", cartRoutes);
app.use("/api/chat", chatRoutes);
app.use("/api/reviews", reviewRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/admin", adminRoutes);
app.use("/api/payments", paymentLimiter, paymentRoutes); // Payment routes with rate limiting
app.use("/api/community", communityRoutes);
app.use("/api/recommendations", recommendationsRoutes);

// ─── Health Check ────────────────────────────────────────────────────────────
app.get("/health", (req, res) => {
  res.status(200).json({ status: "ok", uptime: process.uptime() });
});

// ─── 404 Handler ─────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route ${req.method} ${req.url} not found`,
  });
});

// ─── Global Error Handler ────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error("Unhandled error:", err.stack);
  res.status(500).json({ success: false, message: "Internal server error" });
});

// ─── Start Server ────────────────────────────────────────────────────────────
connectDatabase().then(() => {
  // Validate Stripe key on startup
  if (
    !process.env.STRIPE_SECRET_KEY ||
    !process.env.STRIPE_SECRET_KEY.startsWith("sk_")
  ) {
    console.error("❌ STRIPE_SECRET_KEY is missing or invalid in .env!");
  } else {
    console.log(
      "✅ Stripe initialized in",
      process.env.STRIPE_SECRET_KEY.includes("test") ? "TEST" : "LIVE",
      "mode",
    );
  }

  server.listen(PORT, "0.0.0.0", () => {
    console.log(`\n🚀 IndieLife Server running on http://0.0.0.0:${PORT}`);
    console.log(`📦 Environment: ${process.env.NODE_ENV || "development"}\n`);
  });
});
