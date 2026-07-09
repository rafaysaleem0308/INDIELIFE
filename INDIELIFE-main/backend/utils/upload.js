const multer = require("multer");
const path = require("path");
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const cloudinary = require("cloudinary").v2;
const { isProduction } = require("./env");

const hasCloudinaryConfig =
  process.env.CLOUDINARY_CLOUD_NAME &&
  process.env.CLOUDINARY_API_KEY &&
  process.env.CLOUDINARY_API_SECRET;

if (hasCloudinaryConfig) {
  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
  });
} else if (isProduction) {
  throw new Error("Cloudinary environment variables are required in production");
}

function safePublicId(prefix, file) {
  const base = path.parse(file.originalname).name.replace(/[^a-z0-9_-]/gi, "-");
  return `${prefix}-${Date.now()}-${base}`.toLowerCase();
}

function createUpload(folder, prefix) {
  if (hasCloudinaryConfig) {
    const storage = new CloudinaryStorage({
      cloudinary,
      params: {
        folder,
        allowed_formats: ["jpg", "jpeg", "png", "webp"],
        public_id: (req, file) => safePublicId(prefix, file),
      },
    });

    return multer({
      storage,
      limits: { fileSize: 5 * 1024 * 1024 },
    });
  }

  const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, "uploads/"),
    filename: (req, file, cb) => {
      cb(null, `${safePublicId(prefix, file)}${path.extname(file.originalname)}`);
    },
  });

  return multer({
    storage,
    limits: { fileSize: 5 * 1024 * 1024 },
  });
}

function getUploadedFileUrl(file) {
  return file?.path || file?.secure_url || (file?.filename ? `/uploads/${file.filename}` : "");
}

module.exports = {
  createUpload,
  getUploadedFileUrl,
};
