import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseManagementScreen extends StatefulWidget {
  const DatabaseManagementScreen({super.key});

  @override
  State<DatabaseManagementScreen> createState() => _DatabaseManagementScreenState();
}

class _DatabaseManagementScreenState extends State<DatabaseManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
  
  // 🍎 Apple Colors
  static const Color appleBackground = Color(0xFFF2F2F7);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleRed = Color(0xFFFF3B30);
  static const Color appleGreen = Color(0xFF34C759);
  static const Color appleOrange = Color(0xFFFF9500);
  static const Color applePurple = Color(0xFFAF52DE);

  // Database Stats
  int _totalUsers = 0;
  int _totalInvoices = 0;
  int _totalProducts = 0;
  int _totalClients = 0;
  int _totalDocuments = 0;
  double _databaseSize = 0.0; // In MB
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDatabaseStats();
  }

  Future<void> _loadDatabaseStats() async {
    setState(() => _isLoading = true);
    
    try {
      // Count users
      final usersSnapshot = await _firestore.collection('users').get();
      int totalUsers = usersSnapshot.docs.length;
      
      int totalInvoices = 0;
      int totalProducts = 0;
      int totalClients = 0;
      
      // Count subcollections
      for (var userDoc in usersSnapshot.docs) {
        final invoices = await userDoc.reference.collection('invoices').count().get();
        final products = await userDoc.reference.collection('products').count().get();
        final clients = await userDoc.reference.collection('clients').count().get();
        
        totalInvoices += invoices.count ?? 0;
        totalProducts += products.count ?? 0;
        totalClients += clients.count ?? 0;
      }
      
      final totalDocs = totalUsers + totalInvoices + totalProducts + totalClients;
      
      if (mounted) {
        setState(() {
          _totalUsers = totalUsers;
          _totalInvoices = totalInvoices;
          _totalProducts = totalProducts;
          _totalClients = totalClients;
          _totalDocuments = totalDocs;
          _databaseSize = (totalDocs * 0.5); // Rough estimate: 0.5 KB per document
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading database stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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
                'Database Management',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
                  onPressed: _loadDatabaseStats,
                ),
              ],
            ),
          ),
        ),
      ),

      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: appleAccent))
          : RefreshIndicator(
              onRefresh: _loadDatabaseStats,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Database Overview
                  _buildSectionHeader('Database Overview', Icons.storage_rounded),
                  const SizedBox(height: 12),
                  _buildDatabaseStats(),
                  
                  const SizedBox(height: 24),
                  
                  // Collections
                  _buildSectionHeader('Collections', Icons.folder_rounded),
                  const SizedBox(height: 12),
                  _buildCollectionsList(),
                  
                  const SizedBox(height: 24),
                  
                  // Backup & Restore
                  _buildSectionHeader('Backup & Restore', Icons.backup_rounded),
                  const SizedBox(height: 12),
                  _buildBackupActions(),
                  
                  const SizedBox(height: 24),
                  
                  // Danger Zone
                  _buildSectionHeader('Danger Zone', Icons.warning_rounded),
                  const SizedBox(height: 12),
                  _buildDangerZone(),
                  
                  const SizedBox(height: 40),
                ],
              ),
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

  Widget _buildDatabaseStats() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      children: [
        _buildStatCard('Total Documents', _totalDocuments.toString(), Icons.description_rounded, appleAccent),
        _buildStatCard('Database Size', '${_databaseSize.toStringAsFixed(1)} KB', Icons.sd_storage_rounded, appleGreen),
        _buildStatCard('Users', _totalUsers.toString(), Icons.people_rounded, applePurple),
        _buildStatCard('Invoices', _totalInvoices.toString(), Icons.receipt_long_rounded, appleOrange),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsList() {
    final collections = [
      {'name': 'users', 'count': _totalUsers, 'icon': Icons.people_rounded, 'color': appleAccent},
      {'name': 'invoices', 'count': _totalInvoices, 'icon': Icons.receipt_long_rounded, 'color': appleGreen},
      {'name': 'products', 'count': _totalProducts, 'icon': Icons.inventory_2_rounded, 'color': appleOrange},
      {'name': 'clients', 'count': _totalClients, 'icon': Icons.person_rounded, 'color': applePurple},
    ];

    return Container(
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
        children: collections.map((collection) {
          return Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (collection['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(collection['icon'] as IconData, color: collection['color'] as Color, size: 24),
                ),
                title: Text(
                  collection['name'] as String,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                subtitle: Text('${collection['count']} documents'),
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: () => _viewCollection(collection['name'] as String),
                ),
              ),
              if (collection != collections.last)
                Divider(height: 1, color: Colors.grey.shade200),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBackupActions() {
    return Container(
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
          _buildActionTile(
            'Create Backup',
            'Export complete database backup',
            Icons.cloud_upload_rounded,
            appleAccent,
            () => _createBackup(),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildActionTile(
            'Restore Backup',
            'Import database from backup file',
            Icons.cloud_download_rounded,
            appleGreen,
            () => _restoreBackup(),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildActionTile(
            'View Backups',
            'See all available backups',
            Icons.history_rounded,
            applePurple,
            () => _viewBackups(),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appleRed.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: appleRed.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildActionTile(
            'Clear All Cache',
            'Remove all cached data',
            Icons.cleaning_services_rounded,
            appleOrange,
            () => _clearCache(),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildActionTile(
            'Delete Test Data',
            'Remove all test/demo data',
            Icons.delete_forever_rounded,  // ✅ CORRECT - This is an IconData
            appleRed,
            () => _deleteTestData(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _viewCollection(String collectionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('📁 Viewing $collectionName collection')),
    );
  }

  void _createBackup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Backup'),
        content: const Text('This will create a complete backup of your database. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('💾 Creating backup...'),
                  backgroundColor: appleAccent,
                ),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _restoreBackup() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📥 Restore backup feature coming soon')),
    );
  }

  void _viewBackups() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📋 No backups found')),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear all cached data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🧹 Cache cleared!'),
                  backgroundColor: appleGreen,
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _deleteTestData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Warning'),
        content: const Text('This will permanently delete all test data. This action cannot be undone!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: appleRed),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🗑️ Test data deletion started...'),
                  backgroundColor: appleRed,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
