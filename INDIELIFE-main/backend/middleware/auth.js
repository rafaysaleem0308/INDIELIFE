const jwt = require("jsonwebtoken");
const { isProduction } = require("../utils/env");

const JWT_SECRET = process.env.JWT_SECRET || (isProduction ? undefined : "dev_jwt_secret_change_me");

if (!JWT_SECRET) {
    throw new Error("JWT_SECRET is required");
}

/**
 * Verify JWT token middleware
 * Attaches decoded user info to req.user
 */
const verifyToken = (req, res, next) => {
    const authHeader = req.headers.authorization;
    if (!authHeader) {
        return res.status(401).json({ success: false, message: "No authorization header provided" });
    }

    const token = authHeader.split(" ")[1];
    if (!token) {
        return res.status(401).json({ success: false, message: "No token provided" });
    }

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;
        next();
    } catch (error) {
        console.error("Token verification error:", error.message);
        return res.status(401).json({ success: false, message: "Invalid or expired token" });
    }
};

/**
 * Role-based access control middleware
 * @param  {...string} roles - Allowed roles (e.g., 'service_provider', 'user', 'admin')
 */
const requireRole = (...roles) => {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({ success: false, message: "Authentication required" });
        }
        if (!roles.includes(req.user.role)) {
            return res.status(403).json({ success: false, message: "Insufficient permissions" });
        }
        next();
    };
};

module.exports = { verifyToken, requireRole, JWT_SECRET };
