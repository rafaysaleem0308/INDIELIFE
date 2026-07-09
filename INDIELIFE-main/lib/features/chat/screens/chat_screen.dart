import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hello/core/services/api_service.dart';
import 'package:hello/core/services/chat_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String otherUserImage;
  final String serviceName;
  final String receiverId;
  final String serviceId;

  const ChatScreen({super.key, 
    required this.chatId,
    required this.otherUserName,
    this.otherUserImage = "",
    required this.serviceName,
    required this.receiverId,
    this.serviceId = "",
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  String? _myId;
  String? _activeChatId;
  StreamSubscription? _socketSubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _activeChatId = widget.chatId;
    _loadData();
    _socketSubscription = ChatService.messageStream.listen((message) {
      if (_activeChatId != null && _activeChatId!.isNotEmpty && 
          message['chatId'].toString() == _activeChatId.toString()) {
        // Avoid duplicate messages
        bool alreadyExists = _messages.any((m) => m['_id'].toString() == message['_id'].toString());
        if (!alreadyExists && mounted) {
          setState(() {
            _messages.add(message);
          });
          _scrollToBottom();
        }
      }
    });
    
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _refreshTimer?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userData = await ApiService.getUserData();
    _myId = userData['_id'] ?? userData['id'];
    
    // If no chatId, try to start/get one
    if ((_activeChatId == null || _activeChatId!.isEmpty) && widget.receiverId.isNotEmpty) {
       final result = await ApiService.startChat(widget.receiverId, widget.serviceId);
       if (result['success'] == true && result['chat'] != null) {
         setState(() {
           _activeChatId = result['chat']['_id'];
         });
       }
    }
    
    if (_activeChatId != null && _activeChatId!.isNotEmpty) {
      await _loadMessages();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    try {
      if (_activeChatId == null || _activeChatId!.isEmpty) return;
      if (!silent && mounted) setState(() => _isLoading = true);
      
      final result = await ApiService.getMessages(_activeChatId!);
      if (result['success'] == true) {
        if (mounted) {
          setState(() {
            _messages = result['messages'];
            _isLoading = false;
          });
          if (!silent) _scrollToBottom(); // Only scroll on initial load
        }
      } else {
        if (mounted && !silent) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error loading messages: $e");
      if (mounted && !silent) {
         setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    Timer(Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final content = _messageController.text;
    _messageController.clear();

    try {
      // If we still don't have a chatId, try to start it now
      if (_activeChatId == null || _activeChatId!.isEmpty) {
         final startRes = await ApiService.startChat(widget.receiverId, widget.serviceId);
         if (startRes['success'] == true && startRes['chat'] != null) {
            _activeChatId = startRes['chat']['_id'];
         } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: Could not start chat")));
            return;
         }
      }

      final result = await ApiService.sendMessage(_activeChatId!, content, widget.receiverId);
      if (result['success'] == false) {
        if (!mounted) return;
        // Show error if sending failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send message: ${result['message']}")),
        );
      }
    } catch (e) {
      print("Error sending message: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error. Failed to send message.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F2F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF1E293B).withOpacity(0.1),
              backgroundImage: widget.otherUserImage.isNotEmpty 
                  ? NetworkImage(ApiService.resolveImageUrl(widget.otherUserImage)) 
                  : null,
              child: widget.otherUserImage.isEmpty ? Text(
                widget.otherUserName[0].toUpperCase(),
                style: GoogleFonts.poppins(color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
              ) : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  Text(
                    widget.serviceName,
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: Color(0xFF1E293B)))
              : _messages.isEmpty
                ? _buildEmptyChat()
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      bool isMe = msg['senderId'].toString() == _myId.toString();
                      
                      bool showDate = false;
                      if (index == 0) {
                        showDate = true;
                      } else {
                        try {
                          DateTime prevDate = DateTime.parse(_messages[index-1]['createdAt']);
                          DateTime currDate = DateTime.parse(msg['createdAt']);
                          if (prevDate.day != currDate.day) showDate = true;
                        } catch (_) {}
                      }

                      return Column(
                        children: [
                          if (showDate) _buildDateHeader(msg['createdAt']),
                          _buildMessageBubble(msg, isMe),
                        ],
                      );
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Color(0xFF1E293B).withOpacity(0.5)),
          ).animate().fadeIn().scale(),
          SizedBox(height: 16),
          Text("No messages yet", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
          Text("Start your conversation", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String? dateStr) {
    if (dateStr == null) return SizedBox.shrink();
    DateTime date = DateTime.parse(dateStr);
    String formatted = DateFormat('MMMM d, y').format(date);
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Text(
        formatted,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    String time = "";
    try {
       time = DateFormat('h:mm a').format(DateTime.parse(msg['createdAt']));
    } catch (_) {
      time = DateFormat('h:mm a').format(DateTime.now());
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMe ? null : Colors.white,
            gradient: isMe ? const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
            ),
            boxShadow: [
              if (!isMe) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
              if (isMe) BoxShadow(color: const Color(0xFF1E293B).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                msg['content'],
                style: GoogleFonts.inter(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.grey[500],
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.done_all_rounded, size: 14, color: Colors.white70),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideX(begin: isMe ? 0.05 : -0.05, end: 0);
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  style: GoogleFonts.inter(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: "Type a message...",
                    hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFF1E293B),
                child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
