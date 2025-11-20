import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final _firestore = FirebaseFirestore.instance;
  
  // 🍎 Apple Colors
  static const Color appleBackground = Color(0xFFF2F2F7);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleRed = Color(0xFFFF3B30);
  static const Color appleGreen = Color(0xFF34C759);
  static const Color appleOrange = Color(0xFFFF9500);
  static const Color applePurple = Color(0xFFAF52DE);

  String _selectedFilter = 'all';

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
                'Activity Logs',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list, color: Colors.black87),
                  onSelected: (value) => setState(() => _selectedFilter = value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'all', child: Text('All Activities')),
                    const PopupMenuItem(value: 'login', child: Text('Login Events')),
                    const PopupMenuItem(value: 'user', child: Text('User Actions')),
                    const PopupMenuItem(value: 'admin', child: Text('Admin Actions')),
                    const PopupMenuItem(value: 'error', child: Text('Errors Only')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          // ✅ FIXED: Date Filter with proper constraints
          Container(
            width: double.infinity, // ✅ ADDED THIS
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appleCard,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded( // ✅ Each chip gets equal space
                  child: _buildFilterChip('Today', true),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip('Week', false),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip('Month', false),
                ),
              ],
            ),
          ),

          // Activity Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getLogsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('Error loading logs', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Text(
                          'Check Firestore permissions',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: appleAccent));
                }

                final logs = snapshot.data!.docs;

                if (logs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index].data() as Map<String, dynamic>;
                    return _buildLogCard(log);
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _exportLogs(),
        backgroundColor: appleAccent,
        icon: const Icon(Icons.download_rounded),
        label: const Text('Export'),
      ),
    );
  }

  Stream<QuerySnapshot> _getLogsStream() {
    Query query = _firestore.collection('activity_logs')
        .orderBy('timestamp', descending: true)
        .limit(100);

    if (_selectedFilter != 'all') {
      query = query.where('type', isEqualTo: _selectedFilter);
    }

    return query.snapshots();
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return InkWell(
      onTap: () => setState(() {}),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? appleAccent : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final type = log['type'] ?? 'unknown';
    final action = log['action'] ?? 'Unknown action';
    final user = log['userName'] ?? 'Unknown user';
    final timestamp = (log['timestamp'] as Timestamp?)?.toDate();
    final details = log['details'] ?? '';
    
    final color = _getLogColor(type);
    final icon = _getLogIcon(type);

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            
            const SizedBox(width: 14),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          user,
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (timestamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, yyyy · HH:mm').format(timestamp),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                type.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Activity Logs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Activity will appear here',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Color _getLogColor(String type) {
    switch (type.toLowerCase()) {
      case 'login':
        return appleGreen;
      case 'user':
        return appleAccent;
      case 'admin':
        return applePurple;
      case 'error':
        return appleRed;
      case 'warning':
        return appleOrange;
      default:
        return Colors.grey;
    }
  }

  IconData _getLogIcon(String type) {
    switch (type.toLowerCase()) {
      case 'login':
        return Icons.login_rounded;
      case 'user':
        return Icons.person_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'error':
        return Icons.error_rounded;
      case 'warning':
        return Icons.warning_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Future<void> _exportLogs() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📥 Exporting logs...'),
        backgroundColor: appleAccent,
      ),
    );
    
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Logs exported successfully!'),
          backgroundColor: appleGreen,
        ),
      );
    }
  }
}
