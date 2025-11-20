import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() => _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  final _firestore = FirebaseFirestore.instance;
  
  // 🍎 Apple Colors
  static const Color appleBackground = Color(0xFFF2F2F7);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleRed = Color(0xFFFF3B30);
  static const Color appleGreen = Color(0xFF34C759);
  static const Color appleOrange = Color(0xFFFF9500);

  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedTarget = 'all'; // all, users, admins
  String _selectedPriority = 'normal'; // low, normal, high, urgent

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appleBackground,
      
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: appleCard.withOpacity(0.8),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Notifications Center',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Send New Notification
          _buildSectionHeader('Send Notification', Icons.send_rounded),
          const SizedBox(height: 12),
          _buildNotificationForm(),
          
          const SizedBox(height: 24),
          
          // Scheduled Notifications
          _buildSectionHeader('Scheduled Notifications', Icons.schedule_rounded),
          const SizedBox(height: 12),
          _buildScheduledNotifications(),
          
          const SizedBox(height: 24),
          
          // Notification History
          _buildSectionHeader('Recent Notifications', Icons.history_rounded),
          const SizedBox(height: 12),
          _buildNotificationHistory(),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: appleAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: appleAccent, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Notification Title',
              hintText: 'Enter title...',
              prefixIcon: const Icon(Icons.title_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Message
          TextField(
            controller: _messageController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Message',
              hintText: 'Enter message...',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.message_rounded),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Target Audience
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send To',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTargetChip('all', 'All Users'),
                    const SizedBox(height: 6),
                    _buildTargetChip('users', 'Regular Users'),
                    const SizedBox(height: 6),
                    _buildTargetChip('admins', 'Admins Only'),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Priority
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Priority',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPriorityChip('low', 'Low', Colors.grey),
                    const SizedBox(height: 6),
                    _buildPriorityChip('normal', 'Normal', appleAccent),
                    const SizedBox(height: 6),
                    _buildPriorityChip('high', 'High', appleOrange),
                    const SizedBox(height: 6),
                    _buildPriorityChip('urgent', 'Urgent', appleRed),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Send Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _sendNotification,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: appleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetChip(String value, String label) {
    final isSelected = _selectedTarget == value;
    return InkWell(
      onTap: () => setState(() => _selectedTarget = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // ✅ Reduced padding
        decoration: BoxDecoration(
          color: isSelected ? appleAccent : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // ✅ ADDED THIS
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              size: 16, // ✅ Reduced from 18 to 16
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6), // ✅ Reduced from 8 to 6
            Flexible( // ✅ WRAPPED IN FLEXIBLE
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 12, // ✅ Reduced from 13 to 12
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis, // ✅ ADDED
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPriorityChip(String value, String label, Color color) {
    final isSelected = _selectedPriority == value;
    return InkWell(
      onTap: () => setState(() => _selectedPriority = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledNotifications() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.schedule_rounded, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No Scheduled Notifications',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Schedule notifications for future delivery',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .orderBy('sentAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: appleAccent));
        }

        final notifications = snapshot.data!.docs;

        if (notifications.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: appleCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.notifications_none_rounded, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No Notifications Sent',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: notifications.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _buildNotificationCard(data);
          }).toList(),
        );
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> data) {
    final title = data['title'] ?? 'No title';
    final message = data['message'] ?? '';
    final target = data['target'] ?? 'all';
    final priority = data['priority'] ?? 'normal';
    final sentAt = (data['sentAt'] as Timestamp?)?.toDate();
    
    final priorityColor = _getPriorityColor(priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: priorityColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.people_outline, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Sent to: $target',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const Spacer(),
              if (sentAt != null)
                Text(
                  DateFormat('MMM dd, HH:mm').format(sentAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return appleRed;
      case 'high':
        return appleOrange;
      case 'low':
        return Colors.grey;
      default:
        return appleAccent;
    }
  }

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please fill in all fields'),
          backgroundColor: appleOrange,
        ),
      );
      return;
    }

    try {
      await _firestore.collection('notifications').add({
        'title': title,
        'message': message,
        'target': _selectedTarget,
        'priority': _selectedPriority,
        'sentAt': FieldValue.serverTimestamp(),
        'sentBy': 'admin', // TODO: Add actual admin name
        'read': false,
      });

      _titleController.clear();
      _messageController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Notification sent successfully!'),
          backgroundColor: appleGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: appleRed,
        ),
      );
    }
  }
}
