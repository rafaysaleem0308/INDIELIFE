import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hello/core/services/api_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:hello/core/services/chat_service.dart';
import 'dart:async';

class MyChatsScreen extends StatefulWidget {
  const MyChatsScreen({super.key});

  @override
  _MyChatsScreenState createState() => _MyChatsScreenState();
}

class _MyChatsScreenState extends State<MyChatsScreen> {
  List<dynamic> _chats = [];
  bool _isLoading = true;
  String? _myId;
  StreamSubscription? _socketSubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    ChatService.init(); // Join socket room
    _loadChats();
    
    // Listen for new messages to refresh the chat list
    _socketSubscription = ChatService.messageStream.listen((message) {
      if (mounted) {
        _loadChats(silent: true); // Refresh list to show new last message/order
      }
    });

    _refreshTimer = Timer.periodic(Duration(seconds: 15), (_) => _loadChats(silent: true));
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChats({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    try {
      final userData = await ApiService.getUserData();
      _myId = userData['_id'] ?? userData['id'];
      final result = await ApiService.getMyChats();
      if (mounted) {
        setState(() {
          _chats = result['success'] == true ? (result['chats'] ?? []) : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading chats: $e");
      if (mounted && !silent) {
        setState(() => _isLoading = false);
        _showErrorSnackBar("Failed to load messages");
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontSize: 14)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(20),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _loadChats(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Messages", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 22)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(icon: Icon(Icons.search, color: Colors.black87), onPressed: () {}),
          IconButton(icon: Icon(Icons.more_vert, color: Colors.black87), onPressed: () {}),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: Color(0xFF1E293B)))
        : _chats.isEmpty 
          ? _buildEmptyState()
          : ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8),
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                return _buildChatTile(chat).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(color: Color(0xFFF5F7FA), shape: BoxShape.circle),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 60, color: Colors.grey[300]),
          ),
          SizedBox(height: 24),
          Text("No messages yet", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
          SizedBox(height: 8),
          Text("Conversations with providers will appear here", style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildChatTile(dynamic chat) {
    final String otherName = chat['otherUserName'] ?? "User";
    final String otherImage = chat['otherUserImage'] ?? "";
    final String lastMsg = chat['lastMessage']?['content'] ?? "New conversation";
    final String serviceName = chat['serviceName'] ?? "Service";
    
    String time = "";
    try {
      if (chat['updatedAt'] != null) {
        DateTime date = DateTime.parse(chat['updatedAt']);
        DateTime now = DateTime.now();
        if (date.day == now.day && date.month == now.month && date.year == now.year) {
          time = DateFormat('h:mm a').format(date);
        } else {
          time = DateFormat('MMM d').format(date);
        }
      }
    } catch (_) {}

    return InkWell(
      onTap: () async {
        final List participants = chat['participants'] ?? [];
        String receiverId = "";
        for (var p in participants) {
          String pId = (p is Map) ? (p['user']?.toString() ?? "") : p.toString();
          if (pId != _myId.toString() && pId.isNotEmpty) {
            receiverId = pId;
            break;
          }
        }

        await Navigator.pushNamed(context, '/chat', arguments: {
          'chatId': chat['_id'],
          'otherUserName': otherName,
          'otherUserImage': otherImage,
          'serviceName': serviceName,
          'receiverId': receiverId,
        });
        _loadChats(); // Refresh on return
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFF1E293B).withOpacity(0.1),
                  backgroundImage: otherImage.isNotEmpty ? NetworkImage(ApiService.resolveImageUrl(otherImage)) : null,
                  child: otherImage.isEmpty ? Text(
                    otherName[0].toUpperCase(),
                    style: GoogleFonts.poppins(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 20),
                  ) : null,
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(otherName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
                      Text(time, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFFF0F2F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          serviceName,
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

