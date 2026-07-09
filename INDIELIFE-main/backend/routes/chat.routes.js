const express = require("express");
const router = express.Router();
const mongoose = require("mongoose");
const Chat = require("../models/chat.model");
const Message = require("../models/message.model");
const User = require("../models/user.model");
const ServiceProvider = require("../models/service-provider.model");
const Service = require("../models/service.model");
const { verifyToken } = require("../middleware/auth");

// Start or get a chat
router.post("/start", verifyToken, async (req, res) => {
    try {
        const { providerId, serviceId } = req.body;
        const myId = req.user.userId || req.user.spId;
        const myModel = req.user.role === 'user' ? 'User' : 'ServiceProvider';



        if (!providerId) {
            return res.status(400).json({ success: false, message: "providerId is required" });
        }

        // Convert to ObjectId for reliable lookup
        const myObjectId = new mongoose.Types.ObjectId(myId);
        const providerObjectId = new mongoose.Types.ObjectId(providerId);
        let normalizedServiceId = null;

        if (serviceId && mongoose.Types.ObjectId.isValid(serviceId)) {
            const serviceExists = await Service.exists({ _id: serviceId });
            if (serviceExists) normalizedServiceId = serviceId;
        }

        // Find existing chat containing both participants
        let chat = await Chat.findOne({
            $and: [
                { "participants.user": myObjectId },
                { "participants.user": providerObjectId }
            ]
        });

        if (chat) {

            // Update serviceId if it was missing
            if (normalizedServiceId && !chat.serviceId) {
                chat.serviceId = normalizedServiceId;
                await chat.save();
            }
        } else {

            chat = new Chat({
                participants: [
                    { user: myObjectId, modelType: myModel },
                    { user: providerObjectId, modelType: myModel === 'User' ? 'ServiceProvider' : 'User' }
                ],
                serviceId: normalizedServiceId
            });
            await chat.save();
        }

        res.status(200).json({ success: true, chat });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
});

// Send a message
router.post("/message", verifyToken, async (req, res) => {
    try {
        const { chatId, content, receiverId } = req.body;
        const senderId = req.user.userId || req.user.spId;

        const message = new Message({
            chatId,
            senderId,
            receiverId,
            content
        });
        await message.save();

        await Chat.findByIdAndUpdate(chatId, { lastMessage: message._id });

        // Emit socket event for real-time update
        const io = req.app.get("io");
        if (io) {
            io.to(receiverId.toString()).emit("new_message", message);
            io.to(senderId.toString()).emit("new_message", message);
        }

        res.status(201).json({ success: true, message });
    } catch (err) {
        console.error(`❌ [MSG] Send error:`, err);
        res.status(500).json({ success: false, message: err.message });
    }
});

// Get messages for a chat
router.get("/messages/:chatId", verifyToken, async (req, res) => {
    try {
        const messages = await Message.find({ chatId: req.params.chatId }).sort({ createdAt: 1 });
        res.status(200).json({ success: true, messages });
    } catch (err) {
        console.error(`❌ [MSG] Fetch error:`, err);
        res.status(500).json({ success: false, message: err.message });
    }
});

// Get all chats for a user
router.get("/my-chats", verifyToken, async (req, res) => {
    try {
        const myId = req.user.userId || req.user.spId;

        // Find chats where user is a participant (support both new and old structure)
        const chats = await Chat.find({
            "participants.user": myId
        })
            .populate("lastMessage")
            .populate("serviceId", "serviceName")
            .sort({ updatedAt: -1 });

        // Map chats to include the other participant's name
        const enhancedChats = await Promise.all(chats.map(async (chat) => {
            const chatObj = chat.toObject();

            // Find the other participant
            const otherParticipantData = chat.participants.find(p => {
                const id = p.user ? p.user.toString() : (typeof p === 'string' ? p : p.toString());
                return id !== myId.toString();
            });

            let otherUserName = "User";
            let otherUserImage = "";

            if (otherParticipantData) {
                const otherId = otherParticipantData.user || otherParticipantData;
                const modelType = otherParticipantData.modelType;

                // 1. Try ServiceProvider lookup if it might be one
                if (!modelType || modelType === 'ServiceProvider') {
                    const sp = await ServiceProvider.findById(otherId);
                    if (sp) {
                        otherUserName = sp.serviceName || (sp.firstName ? `${sp.firstName} ${sp.lastName}` : "Service");
                        otherUserImage = sp.profileImage || "";
                    }
                }

                // 2. If name still default, try User lookup
                if (otherUserName === "User" || !modelType || modelType === 'User') {
                    const u = await User.findById(otherId);
                    if (u) {
                        // If user is a provider, prefer their business name
                        if (u.role === 'service_provider' || u.spName) {
                            otherUserName = u.spName || (u.firstName ? `${u.firstName} ${u.lastName}` : u.username);
                        } else {
                            otherUserName = u.firstName ? `${u.firstName} ${u.lastName}` : u.username;
                        }
                        if (!otherUserImage) otherUserImage = u.profileImage || "";
                    }
                }

                // 3. Last fallback: use service name tag if it's a "New conversation"
                if (otherUserName === "User" && chat.serviceId?.serviceName) {
                    otherUserName = chat.serviceId.serviceName;
                }
            }

            return {
                ...chatObj,
                otherUserName,
                otherUserImage,
                serviceName: chat.serviceId?.serviceName || "Service"
            };
        }));

        res.status(200).json({ success: true, chats: enhancedChats });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
});

module.exports = router;
