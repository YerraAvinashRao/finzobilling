import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UserSupportScreen extends StatefulWidget {
  const UserSupportScreen({super.key});

  @override
  State<UserSupportScreen> createState() => _UserSupportScreenState();
}

class _UserSupportScreenState extends State<UserSupportScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  // Apple Colors
  static const Color appleBackground = Color(0xFFF2F2F7);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleGreen = Color(0xFF34C759);
  static const Color appleOrange = Color(0xFFFF9500);
  static const Color appleRed = Color(0xFFFF3B30);

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
                'My Support Tickets',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('support_tickets')
            .where('userId', isEqualTo: _auth.currentUser?.uid)
            .orderBy('createdAt', descending: true)
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

          final tickets = snapshot.data!.docs;

          if (tickets.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index].data() as Map<String, dynamic>;
              final ticketId = tickets[index].id;
              return _buildTicketCard(ticket, ticketId);
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTicketDialog(),
        backgroundColor: appleAccent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Ticket'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.support_agent_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Support Tickets',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first support ticket',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateTicketDialog(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Ticket'),
            style: ElevatedButton.styleFrom(
              backgroundColor: appleAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket, String ticketId) {
    final subject = ticket['subject'] ?? 'No Subject';
    final status = ticket['status'] ?? 'open';
    final createdAt = (ticket['createdAt'] as Timestamp?)?.toDate();
    final priority = ticket['priority'] ?? 'normal';

    final statusColor = status == 'open' ? appleGreen : Colors.grey;
    final priorityColor = _getPriorityColor(priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTicketDetails(ticketId, ticket),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subject,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.priority_high, size: 16, color: priorityColor),
                    const SizedBox(width: 4),
                    Text(
                      '${priority.toUpperCase()} Priority',
                      style: TextStyle(
                        fontSize: 12,
                        color: priorityColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (createdAt != null)
                      Text(
                        DateFormat('MMM dd, yyyy').format(createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return appleRed;
      case 'medium':
        return appleOrange;
      default:
        return appleGreen;
    }
  }

  void _showCreateTicketDialog() {
    final subjectController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedPriority = 'normal';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Create Support Ticket',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    hintText: 'Brief description of your issue',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Provide detailed information...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Priority',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildPriorityChip('Low', selectedPriority, (value) {
                      setState(() => selectedPriority = value);
                    }),
                    const SizedBox(width: 8),
                    _buildPriorityChip('Normal', selectedPriority, (value) {
                      setState(() => selectedPriority = value);
                    }),
                    const SizedBox(width: 8),
                    _buildPriorityChip('High', selectedPriority, (value) {
                      setState(() => selectedPriority = value);
                    }),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (subjectController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a subject')),
                  );
                  return;
                }

                await _createTicket(
                  subjectController.text,
                  descriptionController.text,
                  selectedPriority,
                );
                
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: appleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Create Ticket'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String label, String selectedPriority, Function(String) onSelect) {
    final isSelected = selectedPriority.toLowerCase() == label.toLowerCase();
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(label.toLowerCase()),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? appleAccent : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createTicket(String subject, String description, String priority) async {
    try {
      final user = _auth.currentUser!;
      
      await _firestore.collection('support_tickets').add({
        'userId': user.uid,
        'userEmail': user.email,
        'userName': user.displayName ?? user.email?.split('@')[0] ?? 'User',
        'subject': subject,
        'description': description,
        'priority': priority,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Ticket created successfully!'),
          backgroundColor: appleGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: appleRed,
        ),
      );
    }
  }

  void _showTicketDetails(String ticketId, Map<String, dynamic> ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailsScreen(ticketId: ticketId, ticket: ticket),
      ),
    );
  }
}

// Simple ticket details screen
class TicketDetailsScreen extends StatelessWidget {
  final String ticketId;
  final Map<String, dynamic> ticket;

  const TicketDetailsScreen({
    super.key,
    required this.ticketId,
    required this.ticket,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ticket['subject'] ?? 'No Subject',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(ticket['description'] ?? 'No description'),
          ],
        ),
      ),
    );
  }
}
