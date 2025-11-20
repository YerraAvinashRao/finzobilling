import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _firestore = FirebaseFirestore.instance;
  final _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  String? _ticketId;
  bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initializeTicket();
  }

  // Create or get existing support ticket
  Future<void> _initializeTicket() async {
    setState(() => _isLoading = true);
    
    try {
      // Check if user has an open ticket
      final existingTickets = await _firestore
          .collection('support_tickets')
          .where('userId', isEqualTo: _userId)
          .where('status', isEqualTo: 'open')
          .limit(1)
          .get();

      if (existingTickets.docs.isNotEmpty) {
        _ticketId = existingTickets.docs.first.id;
      } else {
        // Create new ticket
        final newTicket = await _firestore.collection('support_tickets').add({
          'userId': _userId,
          'userName': FirebaseAuth.instance.currentUser?.displayName ?? 'User',
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'open',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadBySupportCount': 0,
          'unreadByUserCount': 0,
        });
        _ticketId = newTicket.id;
        
        // Send welcome message from system
        await _sendSystemMessage(
          'Hello! 👋 Welcome to FinzoBilling Support!\n\n'
          'I\'m here to help you. Our support team will respond shortly.\n\n'
          'Average response time: 5-10 minutes during business hours (9 AM - 6 PM IST)'
        );
      }
    } catch (e) {
      debugPrint('Error initializing ticket: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Send user message
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _ticketId == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _firestore
          .collection('support_tickets')
          .doc(_ticketId)
          .collection('messages')
          .add({
        'text': message,
        'senderId': _userId,
        'senderType': 'user',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Update ticket
      await _firestore.collection('support_tickets').doc(_ticketId).update({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': message,
        'unreadBySupportCount': FieldValue.increment(1),
      });

      // Scroll to bottom
      Future.delayed(Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message. Please try again.')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  // Send system/auto message
  Future<void> _sendSystemMessage(String message) async {
    if (_ticketId == null) return;

    await _firestore
        .collection('support_tickets')
        .doc(_ticketId)
        .collection('messages')
        .add({
      'text': message,
      'senderId': 'system',
      'senderType': 'system',
      'createdAt': FieldValue.serverTimestamp(),
      'read': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Support Chat'),
          backgroundColor: Color(0xFF667eea),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Support Chat', style: TextStyle(fontSize: 18)),
            Text(
              'Usually replies within 10 min',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Color(0xFF667eea),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showSupportInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _ticketId == null
                ? Center(child: Text('Loading...'))
                : StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('support_tickets')
                        .doc(_ticketId)
                        .collection('messages')
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error loading messages'));
                      }

                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }

                      final messages = snapshot.data!.docs;

                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, 
                                   size: 64, 
                                   color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Start a conversation',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index].data() as Map<String, dynamic>;
                          return _buildMessageBubble(message);
                        },
                      );
                    },
                  ),
          ),

          // Input
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Quick action buttons
                  IconButton(
                    icon: Icon(Icons.attach_file, color: Color(0xFF667eea)),
                    onPressed: () {
                      // Future: Attach screenshots/files
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('File attachment coming soon!')),
                      );
                    },
                  ),
                  
                  // Message input
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  
                  SizedBox(width: 8),
                  
                  // Send button
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Icon(Icons.send, color: Colors.white),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['senderType'] == 'user';
    final isSystem = message['senderType'] == 'system';
    final timestamp = (message['createdAt'] as Timestamp?)?.toDate();
    
    if (isSystem) {
      return Center(
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message['text'],
            style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Color(0xFF667eea) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'Support Team',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF667eea),
                  ),
                ),
              ),
            Text(
              message['text'],
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (timestamp != null)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('HH:mm').format(timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isUser ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSupportInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Support Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📧 Email: support@finzobilling.com'),
            SizedBox(height: 8),
            Text('📱 WhatsApp: +91 XXXXX XXXXX'),
            SizedBox(height: 8),
            Text('⏰ Hours: 9 AM - 6 PM IST (Mon-Sat)'),
            SizedBox(height: 16),
            Text(
              'Average Response Time:\n• Chat: 5-10 minutes\n• Email: Within 24 hours',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
