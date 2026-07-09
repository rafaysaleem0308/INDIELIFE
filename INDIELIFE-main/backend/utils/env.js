const requiredProductionVars = [
  "MONGO_URI",
  "JWT_SECRET",
  "EMAIL_USER",
  "EMAIL_PASS",
  "CLOUDINARY_CLOUD_NAME",
  "CLOUDINARY_API_KEY",
  "CLOUDINARY_API_SECRET",
  "STRIPE_SECRET_KEY",
  "STRIPE_WEBHOOK_SECRET",
  "ADMIN_ORIGIN",
];

const optionalProductionVars = [
  "TWILIO_ACCOUNT_SID",
  "TWILIO_AUTH_TOKEN",
  "TWILIO_PHONE_NUMBER",
];

const isProduction = process.env.NODE_ENV === "production";

function requireEnv(name) {
  const value = process.env[name];
  if (!value || value.trim() === "") {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function validateEnvironment() {
  if (!isProduction) return;

  const missing = requiredProductionVars.filter((name) => !process.env[name]);
  if (missing.length > 0) {
    throw new Error(
      `Missing required production environment variables: ${missing.join(", ")}`,
    );
  }

  if (process.env.JWT_SECRET.length < 32) {
    throw new Error("JWT_SECRET must be at least 32 characters in production");
  }

  if (process.env.JWT_SECRET === "your_jwt_secret") {
    throw new Error("JWT_SECRET must not use the development fallback");
  }

  optionalProductionVars
    .filter((name) => !process.env[name])
    .forEach((name) => {
      console.warn(`Optional production environment variable not set: ${name}`);
    });
}

module.exports = {
  isProduction,
  requireEnv,
  validateEnvironment,
};
