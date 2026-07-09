require("dotenv").config();
const mongoose = require("mongoose");
const bcrypt = require("bcrypt");
const User = require("./models/user.model");
const { connectDatabase } = require("./config/database");

const seedAdmin = async () => {
    try {
        await connectDatabase();

        const adminEmail = process.env.ADMIN_EMAIL || "admin@indielife.com";
        const adminPassword = process.env.ADMIN_PASSWORD || "Admin@123";
        const existingAdmin = await User.findOne({ email: adminEmail });

        if (existingAdmin) {
            console.log("Admin already exists.");
            process.exit(0);
        }

        const hashedPassword = await bcrypt.hash(adminPassword, 10);

        const admin = new User({
            role: "admin",
            username: "superadmin",
            email: adminEmail,
            password: hashedPassword,
            firstName: "Super",
            lastName: "Admin",
            phone: "03001234567",
            city: "Islamabad",
            address: "IndieLife HQ",
            accountStatus: "active"
        });

        await admin.save();
        console.log("Super Admin created successfully.");
        console.log(`Email: ${adminEmail}`);
        process.exit(0);
    } catch (error) {
        console.error("Error seeding admin:", error);
        process.exit(1);
    }
};

seedAdmin();
