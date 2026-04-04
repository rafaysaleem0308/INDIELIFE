const express = require("express");
const router = express.Router();
const Service = require("../models/service.model");
const ServiceProvider = require("../models/service-provider.model");
const User = require("../models/user.model");
const { verifyToken } = require("../middleware/auth");
const multer = require("multer");
const path = require("path");
const fs = require("fs");

// ─── VALIDATION & SANITIZATION ────────────────────────────────────────────
const {
  validatePrice,
  sanitizeString,
  sanitizeHtmlContent,
} = require("../utils/validators");

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, "uploads/");
  },
  filename: function (req, file, cb) {
    cb(null, "service-" + Date.now() + path.extname(file.originalname));
  },
});
const upload = multer({ storage });

// POST /api/services/:id/upload-image
router.post(
  "/:id/upload-image",
  verifyToken,
  upload.single("serviceImage"),
  async (req, res) => {
    try {
      const { id } = req.params;
      if (!req.file)
        return res
          .status(400)
          .json({ success: false, message: "No image provided" });
      const imageUrl = "/uploads/" + req.file.filename;
      const service = await Service.findByIdAndUpdate(
        id,
        { imageUrl },
        { new: true },
      );
      if (!service)
        return res
          .status(404)
          .json({ success: false, message: "Service not found" });
      res.status(200).json({ success: true, imageUrl, service });
    } catch (err) {
      res.status(500).json({ success: false, message: err.message });
    }
  },
);

// ==========================================
// 1. SPECIFIC GET ROUTES (Must come first)
// ==========================================

// GET /api/services/laundry-providers
router.get("/laundry-providers", async (req, res) => {
  console.log("HIT /laundry-providers");
  try {
    const { city, sortBy = "rating", sortOrder = "desc" } = req.query;

    let query = {
      serviceType: "Laundry",
      status: "Active",
    };

    if (city) {
      query.serviceProviderCity = new RegExp(city, "i");
    }

    const sortOptions = {};
    if (sortBy === "rating") sortOptions.rating = sortOrder === "desc" ? -1 : 1;
    if (sortBy === "price") sortOptions.price = sortOrder === "desc" ? -1 : 1;
    if (sortBy === "name")
      sortOptions.serviceName = sortOrder === "desc" ? -1 : 1;

    const services = await Service.find(query)
      .populate(
        "serviceProviderId",
        "firstName lastName email phone city address districtName districtNazim profileImage isVerified pickupAvailable deliveryAvailable",
      )
      .sort(sortOptions)
      .lean();

    const providersMap = new Map();

    services.forEach((service) => {
      const providerId =
        service.serviceProviderId?._id?.toString() ||
        service.serviceProviderId?.toString();
      if (!providerId) return;

      if (!providersMap.has(providerId)) {
        const providerData = service.serviceProviderId || {};
        let providerName = "Laundry Service";
        if (providerData.firstName || providerData.lastName) {
          providerName =
            `${providerData.firstName || ""} ${providerData.lastName || ""}`.trim();
        } else if (service.serviceProviderName) {
          providerName = service.serviceProviderName;
        }

        providersMap.set(providerId, {
          _id: providerId,
          userId: providerId,
          username: providerName,
          email: providerData.email,
          phone: providerData.phone,
          city: providerData.city,
          address: providerData.address,
          rating: 0,
          servicesCount: 0,
          isVerified: providerData.isVerified || false,
          services: [],
        });
      }

      const provider = providersMap.get(providerId);
      provider.services.push({
        _id: service._id,
        name: service.serviceName,
        description: service.description,
        price: service.price,
        unit: service.unit,
        rating: service.rating,
        laundryType: service.laundryType,
      });
    });

    const providers = Array.from(providersMap.values()).map((provider) => {
      if (provider.services.length > 0) {
        const totalRating = provider.services.reduce(
          (sum, s) => sum + (s.rating || 0),
          0,
        );
        provider.rating = parseFloat(
          (totalRating / provider.services.length).toFixed(1),
        );
      }
      provider.servicesCount = provider.services.length;
      delete provider.services;
      return provider;
    });

    providers.sort((a, b) => b.rating - a.rating);

    res.status(200).json({
      success: true,
      laundryProviders: providers,
      total: providers.length,
    });
  } catch (error) {
    console.error("Get laundry providers error:", error);
    res
      .status(500)
      .json({ success: false, message: "Server error", error: error.message });
  }
});

// GET /api/services/laundry-provider/:providerId
router.get("/laundry-provider/:providerId", async (req, res) => {
  try {
    const { providerId } = req.params;
    const provider = await ServiceProvider.findById(providerId);
    if (!provider) {
      return res
        .status(404)
        .json({ success: false, message: "Provider not found" });
    }

    const services = await Service.find({
      serviceProviderId: providerId,
      serviceType: "Laundry",
      status: "Active",
    }).sort({ createdAt: -1 });

    let averageRating = 0;
    if (services.length > 0) {
      const totalRating = services.reduce((sum, s) => sum + (s.rating || 0), 0);
      averageRating = parseFloat((totalRating / services.length).toFixed(1));
    }

    const providerData = {
      _id: provider._id,
      userId: provider._id,
      username: `${provider.firstName} ${provider.lastName}`,
      email: provider.email,
      phone: provider.phone,
      city: provider.city,
      address: provider.address,
      rating: averageRating,
      servicesCount: services.length,
      isVerified: provider.isVerified,
    };

    res.status(200).json({
      success: true,
      provider: providerData,
      services: services,
    });
  } catch (error) {
    console.error("Get laundry provider detail error:", error);
    res
      .status(500)
      .json({ success: false, message: "Server error", error: error.message });
  }
});

// GET /api/services/meal-providers
router.get("/meal-providers", async (req, res) => {
  try {
    const {
      city,
      cuisine,
      minRating,
      sortBy = "rating",
      sortOrder = "desc",
    } = req.query;
    let query = { serviceType: "Meal Provider", status: "Active" };

    if (city) query.serviceProviderCity = new RegExp(city, "i");
    if (cuisine) query.cuisineType = new RegExp(cuisine, "i");
    if (minRating) query.rating = { $gte: parseFloat(minRating) };

    const sortOptions = {};
    if (sortBy === "rating") sortOptions.rating = sortOrder === "desc" ? -1 : 1;
    if (sortBy === "price") sortOptions.price = sortOrder === "desc" ? -1 : 1;
    if (sortBy === "name")
      sortOptions.serviceName = sortOrder === "desc" ? -1 : 1;

    const meals = await Service.find(query)
      .populate(
        "serviceProviderId",
        "firstName lastName email phone city address districtName districtNazim",
      )
      .sort(sortOptions)
      .lean();

    const mealProvidersMap = new Map();

    meals.forEach((meal) => {
      const providerId =
        meal.serviceProviderId?._id?.toString() ||
        meal.serviceProviderId?.toString();
      if (!providerId) return;

      if (!mealProvidersMap.has(providerId)) {
        const providerData = meal.serviceProviderId || {};
        let providerName = "Unknown Chef";
        if (providerData.firstName || providerData.lastName) {
          providerName =
            `${providerData.firstName || ""} ${providerData.lastName || ""}`.trim();
        } else if (
          meal.serviceProviderName &&
          meal.serviceProviderName.trim()
        ) {
          providerName = meal.serviceProviderName.trim();
        } else if (meal.serviceProviderEmail) {
          providerName = meal.serviceProviderEmail.split("@")[0];
        }

        mealProvidersMap.set(providerId, {
          _id: providerId,
          userId: providerId,
          username: providerName,
          firstName: providerData.firstName,
          lastName: providerData.lastName,
          email: providerData.email || meal.serviceProviderEmail,
          phone: providerData.phone || meal.serviceProviderPhone,
          city: providerData.city || meal.serviceProviderCity,
          address: providerData.address || meal.serviceProviderAddress,
          districtName: providerData.districtName,
          districtNazim: providerData.districtNazim,
          rating: 0,
          deliveryTime: meal.deliveryTime || "30-45 min",
          meals: [],
          mealsCount: 0,
          profileImage: null,
          cuisineTypes: new Set(),
          mealTypes: new Set(),
          isVerified: providerData.isVerified || false,
        });
      }

      const provider = mealProvidersMap.get(providerId);
      provider.meals.push({
        _id: meal._id, // minimal meal data
        rating: meal.rating,
      });
      if (meal.cuisineType) provider.cuisineTypes.add(meal.cuisineType);
      if (meal.mealType) provider.mealTypes.add(meal.mealType);
    });

    let mealProviders = Array.from(mealProvidersMap.values()).map(
      (provider) => {
        if (provider.meals.length > 0) {
          const totalRating = provider.meals.reduce(
            (sum, m) => sum + (m.rating || 0),
            0,
          );
          provider.rating = parseFloat(
            (totalRating / provider.meals.length).toFixed(1),
          );
        }
        provider.mealsCount = provider.meals.length;
        provider.cuisineTypes = Array.from(provider.cuisineTypes);
        provider.mealTypes = Array.from(provider.mealTypes);
        delete provider.meals;
        return provider;
      },
    );

    mealProviders.sort((a, b) => b.rating - a.rating);

    res.status(200).json({
      success: true,
      mealProviders,
      total: mealProviders.length,
    });
  } catch (error) {
    console.error("Get meal providers error:", error);
    res
      .status(500)
      .json({ success: false, message: "Server error", error: error.message });
  }
});

// GET /api/services/meal-provider/:providerId
router.get("/meal-provider/:providerId", async (req, res) => {
  try {
    const { providerId } = req.params;
    const provider = await ServiceProvider.findById(providerId);
    if (!provider) {
      return res
        .status(404)
        .json({ success: false, message: "Meal provider not found" });
    }

    const meals = await Service.find({
      serviceProviderId: providerId,
      serviceType: "Meal Provider",
    })
      .sort({ createdAt: -1 })
      .setOptions({ strictPopulate: false });

    let averageRating = 0;
    if (meals.length > 0) {
      const totalRating = meals.reduce(
        (sum, meal) => sum + (meal.rating || 0),
        0,
      );
      averageRating = parseFloat((totalRating / meals.length).toFixed(1));
    }

    const providerData = {
      _id: provider._id,
      userId: provider._id.toString(),
      username: `${provider.firstName} ${provider.lastName}`,
      email: provider.email,
      phone: provider.phone,
      city: provider.city,
      address: provider.address,
      districtName: provider.districtName,
      districtNazim: provider.districtNazim,
      rating: averageRating,
      deliveryTime: "30-45 min",
      mealsCount: meals.length,
      profileImage: null,
      isVerified: provider.isVerified,
      isActive: provider.isActive,
      joinedDate: provider.createdAt,
    };

    const mealsData = meals.map((meal) => ({
      _id: meal._id,
      name: meal.serviceName,
      description: meal.description,
      rating: meal.rating,
      price: meal.price,
      imagePath: meal.imageUrl || "assets/images/default_meal.png",
      preparationTime: meal.preparationTime || "25 min",
      mealType: meal.mealType,
      cuisineType: meal.cuisineType,
      isVegetarian: meal.isVegetarian || false,
      isSpicy: meal.isSpicy || false,
      hasDairy: meal.hasDairy || false,
      hasGluten: meal.hasGluten || false,
      ingredients: meal.ingredients || [],
      allergens: meal.allergens || [],
      nutritionInfo: meal.nutritionInfo || {},
      availableDays: meal.availableDays || [],
      availableTimeSlots: meal.availableTimeSlots || [],
      status: meal.status,
      featured: meal.featured || false,
      discountPercentage: meal.discountPercentage || 0,
      tags: meal.tags || [],
      createdAt: meal.createdAt,
    }));

    res.status(200).json({
      success: true,
      provider: providerData,
      meals: mealsData,
      totalMeals: meals.length,
    });
  } catch (error) {
    console.error("Get meal provider error:", error);
    res
      .status(500)
      .json({ success: false, message: "Server error", error: error.message });
  }
});

// GET /api/services/meals
router.get("/meals", async (req, res) => {
  try {
    const {
      cuisine,
      mealType,
      minPrice,
      maxPrice,
      isVegetarian,
      city,
      sortBy = "rating",
      sortOrder = "desc",
      page = 1,
      limit = 20,
      lat,
      lng,
    } = req.query;
    const skip = (page - 1) * limit;

    let query = { serviceType: "Meal Provider", status: "Active" };
    if (cuisine) query.cuisineType = new RegExp(cuisine, "i");
    if (mealType) query.mealType = new RegExp(mealType, "i");
    if (isVegetarian === "true") query.isVegetarian = true;
    if (city) query.serviceProviderCity = new RegExp(city, "i");
    if (minPrice || maxPrice) {
      query.price = {};
      if (minPrice) query.price.$gte = parseFloat(minPrice);
      if (maxPrice) query.price.$lte = parseFloat(maxPrice);
    }

    const sortOptions = {};
    if (!lat || !lng) {
      if (sortBy === "rating")
        sortOptions.rating = sortOrder === "desc" ? -1 : 1;
      if (sortBy === "price") sortOptions.price = sortOrder === "desc" ? -1 : 1;
      if (sortBy === "name")
        sortOptions.serviceName = sortOrder === "desc" ? -1 : 1;
      if (sortBy === "newest")
        sortOptions.createdAt = sortOrder === "desc" ? -1 : 1;
    }

    const total = await Service.countDocuments(query);
    const meals = await Service.find(query)
      .sort(sortOptions)
      .skip(skip)
      .limit(parseInt(limit))
      .lean();

    const enrichedMeals = await Promise.all(
      meals.map(async (meal) => {
        const provider = await ServiceProvider.findById(meal.serviceProviderId);
        return {
          ...meal,
          providerInfo: provider
            ? {
                name: `${provider.firstName} ${provider.lastName}`,
                city: provider.city,
                address: provider.address,
                rating: provider.rating || 0,
                isVerified: provider.isVerified,
              }
            : null,
        };
      }),
    );

    res.status(200).json({
      success: true,
      meals: enrichedMeals,
      total,
      page: parseInt(page),
      totalPages: Math.ceil(total / limit),
      hasMore: skip + meals.length < total,
    });
  } catch (error) {
    console.error("Get meals error:", error);
    res
      .status(500)
      .json({ success: false, message: "Server error", error: error.message });
  }
});

// GET /api/services/search
router.get("/search", async (req, res) => {
  try {
    const { query, type, city, minPrice, maxPrice } = req.query;
    let searchQuery = {};
    if (query) {
      searchQuery.$or = [
        { serviceName: new RegExp(query, "i") },
        { description: new RegExp(query, "i") },
        { cuisineType: new RegExp(query, "i") },
        { tags: new RegExp(query, "i") },
      ];
    }
    if (type) searchQuery.serviceType = type;
    if (city) searchQuery.serviceProviderCity = new RegExp(city, "i");
    if (minPrice || maxPrice) {
      searchQuery.price = {};
      if (minPrice) searchQuery.price.$gte = parseFloat(minPrice);
      if (maxPrice) searchQuery.price.$lte = parseFloat(maxPrice);
    }
    searchQuery.status = "Active";

    const services = await Service.find(searchQuery)
      .sort({ rating: -1, createdAt: -1 })
      .limit(50);

    res.status(200).json({ success: true, services, total: services.length });
  } catch (error) {
    console.error("Search services error:", error);
    res
      .status(500)
      .json({ success: false, message: "Server error", error: error.message });
  }
});

// GET /api/services/providers-by-type
router.get("/providers-by-type", async (req, res) => {
  try {
    const {
      type,
      city,
      sortBy = "rating",
      minPrice,
      maxPrice,
      accommodationType,
      isShared,
      availableRooms,
    } = req.query;

    // For "Hostel/Flat Accommodation", we need to query the Services collection, not ServiceProvider
    // because specific housing details (price, type, shared) are in the Service model.

    if (type === "Hostel/Flat Accommodation") {
      let query = { serviceType: type, status: "Active" };

      if (city) query.serviceProviderCity = new RegExp(city, "i");
      if (accommodationType) query.accommodationType = accommodationType;
      if (isShared) query.isShared = isShared === "true";
      if (availableRooms)
        query.availableRooms = { $gte: parseInt(availableRooms) };
      if (minPrice || maxPrice) {
        query.price = {};
        if (minPrice) query.price.$gte = parseFloat(minPrice);
        if (maxPrice) query.price.$lte = parseFloat(maxPrice);
      }

      const sortOptions = {};
      if (sortBy === "rating") sortOptions.rating = -1;
      if (sortBy === "price_asc") sortOptions.price = 1;
      if (sortBy === "price_desc") sortOptions.price = -1;

      const services = await Service.find(query)
        .populate(
          "serviceProviderId",
          "firstName lastName email phone city address districtName districtNazim profileImage isVerified",
        )
        .sort(sortOptions)
        .lean();

      // return as providers format to match frontend expectation if needed, or just services
      // The frontend currently expects a list of providers/services.
      // Let's return the services directly but ensure provider info is top-level if needed,
      // OR just return services and let frontend handle it (Front end code uses `allProviders` which maps to services).

      // Map to a cleaner structure
      const results = services.map((service) => {
        const provider = service.serviceProviderId || {};
        return {
          _id: service._id,
          serviceProviderId: provider._id,
          username: service.serviceName, // Display Service Name as the main title
          providerName: `${provider.firstName} ${provider.lastName}`,
          city: service.serviceProviderCity || provider.city,
          address: service.address || provider.address,
          price: service.price,
          rating: service.rating || 0,
          description: service.description,
          accommodationType: service.accommodationType,
          isShared: service.isShared,
          availableRooms: service.availableRooms,
          currentOccupants: service.currentOccupants,
          maxOccupants: service.maxOccupants,
          images: service.additionalImages || [],
          contactNumber: service.contactNumber || provider.phone,
          imageUrl: service.imageUrl,
        };
      });

      return res
        .status(200)
        .json({ success: true, providers: results, total: results.length });
    }

    // Default behavior for other types (Maintenance, etc.)
    let query = { spSubRole: type, isActive: true };
    if (city) query.city = new RegExp(city, "i");

    const sortOptions = {};
    if (sortBy === "rating") sortOptions.rating = -1;

    const providers = await ServiceProvider.find(query)
      .select("-password")
      .sort(sortOptions)
      .limit(50);

    res.status(200).json({ success: true, providers, total: providers.length });
  } catch (error) {
    console.error("Get providers by type error:", error);
    res
      .status(500)
      .json({ success: false, message: "Server error", error: error.message });
  }
});

// GET /api/services/type/:type
router.get("/type/:type", async (req, res) => {
  try {
    const { type } = req.params;
    const { city, sortBy = "rating", sortOrder = "desc", lat, lng } = req.query;

    let query = { serviceType: type, status: "Active" };
    if (city) query.serviceProviderCity = new RegExp(city, "i");

    const sortOptions = {};
    if (sortBy === "rating") sortOptions.rating = sortOrder === "desc" ? -1 : 1;
    if (sortBy === "price") sortOptions.price = sortOrder === "asc" ? 1 : -1;
    if (sortBy === "newest") sortOptions.createdAt = -1;

    const services = await Service.find(query).sort(sortOptions).limit(100);
    res.status(200).json({ success: true, services, total: services.length });
  } catch (error) {
    console.error("Get services by type error:", error);
    res
      .status(500)
      .json({ success: false, message: "Server error", error: error.message });
  }
});

// ==========================================
// 2. GENERIC ROUTES (Handle /, POST, PUT, DELETE)
// ==========================================

// GET /api/services - Get services for current service provider (AUTHENTICATED)
router.get("/", verifyToken, async (req, res) => {
  try {
    const spId = req.user.spId || req.user.userId;
    if (!spId)
      return res.status(400).json({
        success: false,
        message: "Service provider ID not found in token",
      });

    const services = await Service.find({ serviceProviderId: spId }).sort({
      createdAt: -1,
    });
    res.status(200).json({ success: true, services });
  } catch (error) {
    console.error("Get services error:", error);
    res
      .status(500)
      .json({ success: false, message: "Server error", error: error.message });
  }
});

// POST /api/services - Add new service
router.post("/", verifyToken, async (req, res) => {
  try {
    console.log("Request body:", JSON.stringify(req.body, null, 2));
    console.log("User from token:", {
      spId: req.user.spId,
      userId: req.user.userId,
      spSubRole: req.user.spSubRole,
    });

    const {
      serviceName,
      description,
      price,
      unit,
      serviceType,
      // Meal
      mealType,
      cuisineType,
      isVegetarian,
      isSpicy,
      hasDairy,
      hasGluten,
      preparationTime,
      deliveryTime,
      deliveryAvailable,
      pickupAvailable,
      ingredients,
      allergens,
      nutritionInfo,
      imageUrl,
      availableDays,
      availableTimeSlots,
      tags,
      // Laundry/Others
      laundryType,
      accommodationType,
      address,
      contactNumber,
      availableRooms,
      roomFeatures,
      expertise,
      servicesOffered,
      experience,
      ...additionalFields
    } = req.body;

    if (!serviceName || !price || !unit || !serviceType) {
      console.log("❌ Validation failed: Missing required fields");
      return res.status(400).json({
        success: false,
        message:
          "Missing required fields: serviceName, price, unit, serviceType",
      });
    }

    // ─── VALIDATE SERVICE NAME ────────────────────────────────────────────
    if (serviceName.length < 2 || serviceName.length > 100) {
      return res.status(400).json({
        success: false,
        message: "Service name must be 2-100 characters",
      });
    }

    // ─── VALIDATE DESCRIPTION ─────────────────────────────────────────────
    if (description && description.length < 10) {
      return res.status(400).json({
        success: false,
        message: "Description must be at least 10 characters",
      });
    }

    // ─── VALIDATE PRICE BOUNDS ────────────────────────────────────────────
    if (!validatePrice(price, 100, 500000)) {
      return res.status(400).json({
        success: false,
        message: "Service price must be between 100 and 500,000 PKR",
      });
    }

    const spId = req.user.spId || req.user.userId;
    const spSubRole = req.user.spSubRole;
    const spFirstName = req.user.firstName;
    const spLastName = req.user.lastName;

    if (!spId) {
      console.log("❌ No service provider ID found in token");
      return res
        .status(400)
        .json({ success: false, message: "Service provider ID not found" });
    }

    // ─── SANITIZE INPUT ───────────────────────────────────────────────────
    const sanitizedServiceName = sanitizeString(serviceName);
    const sanitizedDescription = sanitizeString(description);

    const serviceProvider = await ServiceProvider.findById(spId);
    if (!serviceProvider) {
      console.log("❌ Service provider not found in database");
      return res
        .status(404)
        .json({ success: false, message: "Service provider not found" });
    }

    const serviceData = {
      serviceName: sanitizedServiceName,
      description: sanitizedDescription || "",
      price,
      unit,
      serviceType,
      serviceProviderId: spId,
      serviceProviderRole: spSubRole || "Service Provider",
      serviceProviderName: `${spFirstName} ${spLastName}`,
      serviceProviderEmail: serviceProvider.email,
      serviceProviderPhone: serviceProvider.phone,
      serviceProviderCity: serviceProvider.city,
      serviceProviderAddress: serviceProvider.address,

      rating: 0,
      totalReviews: 0,
      totalOrders: 0,
      featured: false,
      discountPercentage: 0,
      ...additionalFields,
    };

    // If lat/lng provided in body, use it. Otherwise inherit from provider.
    if (req.body.lat && req.body.lng) {
      serviceData.location = {
        type: "Point",
        coordinates: [parseFloat(req.body.lng), parseFloat(req.body.lat)],
      };
    } else if (
      serviceProvider.location &&
      serviceProvider.location.coordinates
    ) {
      serviceData.location = serviceProvider.location;
    }

    if (serviceType === "Meal Provider") {
      serviceData.mealType = mealType || "Lunch";
      serviceData.cuisineType = sanitizeString(cuisineType) || "Pakistani";
      serviceData.isVegetarian = isVegetarian || false;
      serviceData.isSpicy = isSpicy || false;
      serviceData.hasDairy = hasDairy || false;
      serviceData.hasGluten = hasGluten || false;
      serviceData.preparationTime = preparationTime || "25 min";
      serviceData.deliveryTime = deliveryTime || "30-45 min";
      serviceData.deliveryAvailable =
        deliveryAvailable !== undefined ? deliveryAvailable : true;
      serviceData.pickupAvailable =
        pickupAvailable !== undefined ? pickupAvailable : true;
      serviceData.ingredients = Array.isArray(ingredients)
        ? ingredients.map((i) => sanitizeString(i))
        : [];
      serviceData.allergens = Array.isArray(allergens)
        ? allergens.map((a) => sanitizeString(a))
        : [];
      serviceData.nutritionInfo = nutritionInfo || {};
      serviceData.imageUrl = imageUrl || "";
      serviceData.availableDays = availableDays || [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
      ];
      serviceData.availableTimeSlots = availableTimeSlots || [
        { startTime: "11:00", endTime: "22:00" },
      ];
      serviceData.tags = Array.isArray(tags)
        ? tags.map((t) => sanitizeString(t))
        : [];
    }

    if (serviceType === "Laundry") {
      serviceData.laundryType = sanitizeString(laundryType);
      serviceData.deliveryAvailable =
        deliveryAvailable !== undefined ? deliveryAvailable : true;
      serviceData.pickupAvailable =
        pickupAvailable !== undefined ? pickupAvailable : true;
    }

    if (serviceType === "Hostel/Flat Accommodation") {
      serviceData.accommodationType = sanitizeString(accommodationType);
      serviceData.address = sanitizeString(address) || "";
      serviceData.contactNumber = contactNumber || "";
      serviceData.availableRooms = availableRooms || 0;
      serviceData.roomFeatures = Array.isArray(roomFeatures)
        ? roomFeatures.map((f) => sanitizeString(f))
        : [];
      serviceData.isShared = req.body.isShared || false;
      serviceData.currentOccupants = req.body.currentOccupants || 0;
      serviceData.maxOccupants = req.body.maxOccupants || 1;
      if (req.body.lat && req.body.lng) {
        serviceData.location = {
          type: "Point",
          coordinates: [parseFloat(req.body.lng), parseFloat(req.body.lat)],
        };
      }
    }

    if (serviceType === "Maintenance") {
      serviceData.expertise = sanitizeString(expertise) || "";
      serviceData.experience = sanitizeString(experience) || "";
      serviceData.servicesOffered = Array.isArray(servicesOffered)
        ? servicesOffered
            .map((s) => sanitizeString(s))
            .filter((s) => s.length > 0)
        : [];
    }

    const service = new Service(serviceData);
    await service.save();

    // Sync Image to Provider Profile if provided
    if (imageUrl && imageUrl.trim().length > 0) {
      console.log("🖼️ Updating provider profile image...");
      await ServiceProvider.findByIdAndUpdate(spId, { profileImage: imageUrl });
    }

    // Update provider's spSubRole if it's Maintenance and not already set
    if (
      serviceType === "Maintenance" &&
      serviceProvider.spSubRole !== "Maintenance"
    ) {
      console.log(
        `🔄 Updating provider spSubRole from "${serviceProvider.spSubRole}" to "Maintenance"`,
      );
      await ServiceProvider.findByIdAndUpdate(spId, {
        spSubRole: "Maintenance",
      });
    }

    res
      .status(201)
      .json({ success: true, message: "Service added successfully", service });
  } catch (error) {
    console.error("❌ Add service error:", error);
    console.error("Error stack:", error.stack);
    res
      .status(500)
      .json({ success: false, message: "Server error", error: error.message });
  }
});

// PUT /api/services/:id
router.put("/:id", verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    let updateData = req.body;
    const service = await Service.findById(id);
    if (!service)
      return res
        .status(404)
        .json({ success: false, message: "Service not found" });

    const spId = req.user.spId || req.user.userId;
    if (service.serviceProviderId.toString() !== spId) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to update this service",
      });
    }

    // ─── VALIDATE AND SANITIZE UPDATES ────────────────────────────────────
    if (updateData.serviceName) {
      if (
        updateData.serviceName.length < 2 ||
        updateData.serviceName.length > 100
      ) {
        return res.status(400).json({
          success: false,
          message: "Service name must be 2-100 characters",
        });
      }
      updateData.serviceName = sanitizeString(updateData.serviceName);
    }

    if (updateData.description) {
      if (updateData.description.length < 10) {
        return res.status(400).json({
          success: false,
          message: "Description must be at least 10 characters",
        });
      }
      updateData.description = sanitizeString(updateData.description);
    }

    if (updateData.price) {
      if (!validatePrice(updateData.price, 100, 500000)) {
        return res.status(400).json({
          success: false,
          message: "Service price must be between 100 and 500,000 PKR",
        });
      }
      updateData.price = Number(updateData.price);
    }

    // Sanitize array fields
    if (updateData.tags && Array.isArray(updateData.tags)) {
      updateData.tags = updateData.tags.map((t) => sanitizeString(t));
    }

    if (updateData.ingredients && Array.isArray(updateData.ingredients)) {
      updateData.ingredients = updateData.ingredients.map((i) =>
        sanitizeString(i),
      );
    }

    if (updateData.allergens && Array.isArray(updateData.allergens)) {
      updateData.allergens = updateData.allergens.map((a) => sanitizeString(a));
    }

    if (updateData.roomFeatures && Array.isArray(updateData.roomFeatures)) {
      updateData.roomFeatures = updateData.roomFeatures.map((f) =>
        sanitizeString(f),
      );
    }

    // Sanitize cuisine type, laundry type, etc.
    if (updateData.cuisineType) {
      updateData.cuisineType = sanitizeString(updateData.cuisineType);
    }

    if (updateData.laundryType) {
      updateData.laundryType = sanitizeString(updateData.laundryType);
    }

    if (updateData.accommodationType) {
      updateData.accommodationType = sanitizeString(
        updateData.accommodationType,
      );
    }

    if (updateData.address) {
      updateData.address = sanitizeString(updateData.address);
    }

    if (
      updateData.servicesOffered &&
      Array.isArray(updateData.servicesOffered)
    ) {
      updateData.servicesOffered = updateData.servicesOffered
        .map((s) => sanitizeString(s))
        .filter((s) => s.length > 0);
    }

    if (updateData.expertise) {
      updateData.expertise = sanitizeString(updateData.expertise);
    }

    if (updateData.experience) {
      updateData.experience = sanitizeString(updateData.experience);
    }

    const updatedService = await Service.findByIdAndUpdate(
      id,
      { ...updateData, updatedAt: Date.now() },
      { new: true, runValidators: true },
    );
    res.status(200).json({
      success: true,
      message: "Service updated successfully",
      service: updatedService,
    });
  } catch (error) {
    console.error("Update service error:", error);
    res
      .status(500)
      .json({ success: false, message: "Server error", error: error.message });
  }
});

// DELETE /api/services/:id
router.delete("/:id", verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const service = await Service.findById(id);
    if (!service)
      return res
        .status(404)
        .json({ success: false, message: "Service not found" });

    const spId = req.user.spId || req.user.userId;
    if (service.serviceProviderId.toString() !== spId) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to delete this service",
      });
    }

    await Service.findByIdAndDelete(id);
    res
      .status(200)
      .json({ success: true, message: "Service deleted successfully" });
  } catch (error) {
    console.error("Delete service error:", error);
    res
      .status(500)
      .json({ success: false, message: "Server error", error: error.message });
  }
});

// ==========================================
// 3. GENERIC ID ROUTE (MUST BE LAST)
// ==========================================

// GET /api/services/:id
router.get("/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const service = await Service.findById(id);
    if (!service)
      return res
        .status(404)
        .json({ success: false, message: "Service not found" });

    const provider = await ServiceProvider.findById(service.serviceProviderId);

    res.status(200).json({
      success: true,
      service: {
        ...service.toObject(),
        providerInfo: provider
          ? {
              name: `${provider.firstName} ${provider.lastName}`,
              email: provider.email,
              phone: provider.phone,
              city: provider.city,
              address: provider.address,
              rating: provider.rating || 0,
              isVerified: provider.isVerified,
              joinedDate: provider.createdAt,
            }
          : null,
      },
    });
  } catch (error) {
    // console.error("Get service by ID error:", error); // Reduce noise
    res
      .status(500)
      .json({ success: false, message: "Server error", error: error.message });
  }
});

module.exports = router;
