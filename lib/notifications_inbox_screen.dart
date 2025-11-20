import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationsInboxScreen extends StatelessWidget {
  const NotificationsInboxScreen({super.key});

  static const Color appleBackground = Color(0xFFF2F2F7);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleRed = Color(0xFFFF3B30);
  static const Color appleOrange = Color(0xFFFF9500);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appleBackground,
      appBar: AppBar(
        backgroundColor: appleCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .orderBy('sentAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: appleAccent),
            );
          }

          final notifications = snapshot.data!.docs;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text('You\'re all caught up!', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index].data() as Map<String, dynamic>;
              return _buildNotificationCard(notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final priority = notification['priority'] ?? 'normal';
    final sentAt = (notification['sentAt'] as Timestamp?)?.toDate();

    final priorityColor = _getPriorityColor(priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: priorityColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: priorityColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getPriorityIcon(priority), color: priorityColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
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
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: priorityColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            if (sentAt != null) ...[
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM dd, yyyy · HH:mm').format(sentAt),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent': return appleRed;
      case 'high': return appleOrange;
      case 'low': return Colors.grey;
      default: return appleAccent;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'urgent': return Icons.priority_high_rounded;
      case 'high': return Icons.warning_rounded;
      case 'low': return Icons.info_outline;
      default: return Icons.notifications_rounded;
    }
  }
}
