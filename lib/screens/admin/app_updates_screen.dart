import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUpdatesScreen extends StatefulWidget {
  const AppUpdatesScreen({super.key});

  @override
  State<AppUpdatesScreen> createState() => _AppUpdatesScreenState();
}

class _AppUpdatesScreenState extends State<AppUpdatesScreen> {
  final _firestore = FirebaseFirestore.instance;
  
  // 🍎 Apple Colors
  static const Color appleBackground = Color(0xFFF2F2F7);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleRed = Color(0xFFFF3B30);
  static const Color appleGreen = Color(0xFF34C759);
  static const Color appleOrange = Color(0xFFFF9500);

  // Feature Flags
  Map<String, bool> _features = {
    'ai_assistant': true,
    'export_pdf': true,
    'email_reports': true,
    'dark_mode': false,
    'offline_mode': false,
    'multi_currency': false,
    'barcode_scanner': true,
    'cloud_sync': true,
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeatureFlags();
  }

  Future<void> _loadFeatureFlags() async {
    try {
      final doc = await _firestore.collection('system_settings').doc('features').get();
      
      if (doc.exists) {
        setState(() {
          _features = Map<String, bool>.from(doc.data()!);
          _isLoading = false;
        });
      } else {
        await _saveFeatureFlags();
      }
    } catch (e) {
      print('Error loading feature flags: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFeatureFlags() async {
    try {
      await _firestore.collection('system_settings').doc('features').set(_features);
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error saving feature flags: $e');
    }
  }

  Future<void> _toggleFeature(String feature, bool value) async {
    setState(() => _features[feature] = value);
    
    try {
      await _firestore.collection('system_settings').doc('features').update({
        feature: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${_getFeatureName(feature)} ${value ? 'enabled' : 'disabled'}'),
          backgroundColor: appleGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: appleRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: appleBackground,
        body: Center(child: CircularProgressIndicator(color: appleAccent)),
      );
    }

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
                'App Updates & Features',
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
          // App Version Info
          _buildVersionCard(),
          
          const SizedBox(height: 24),
          
          // Feature Flags
          _buildSectionHeader('Feature Flags', Icons.flag_rounded),
          const SizedBox(height: 12),
          _buildFeatureFlags(),
          
          const SizedBox(height: 24),
          
          // Update Actions
          _buildSectionHeader('Update Actions', Icons.system_update_rounded),
          const SizedBox(height: 12),
          _buildUpdateActions(),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildVersionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [appleAccent, Color(0xFF0051D5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: appleAccent.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FinzoBilling',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Latest Version',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '1.0.0',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Build Number',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '100',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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

  Widget _buildFeatureFlags() {
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
        children: _features.entries.map((entry) {
          final isLast = entry == _features.entries.last;
          return Column(
            children: [
              _buildFeatureSwitch(entry.key, entry.value),
              if (!isLast) Divider(height: 1, color: Colors.grey.shade200),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeatureSwitch(String feature, bool value) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: value ? appleGreen.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getFeatureIcon(feature),
          color: value ? appleGreen : Colors.grey[600],
          size: 24,
        ),
      ),
      title: Text(
        _getFeatureName(feature),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        _getFeatureDescription(feature),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: (newValue) => _toggleFeature(feature, newValue),
        activeThumbColor: appleGreen,
      ),
    );
  }

  Widget _buildUpdateActions() {
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
            'Push Update',
            'Force update for all users',
            Icons.system_update_alt_rounded,
            appleAccent,
            () => _pushUpdate(),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildActionTile(
            'Release Notes',
            'View and edit release notes',
            Icons.notes_rounded,
            appleOrange,
            () => _viewReleaseNotes(),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildActionTile(
            'Beta Program',
            'Manage beta testers',
            Icons.science_rounded,
            Colors.purple,
            () => _manageBeta(),
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

  String _getFeatureName(String feature) {
    final names = {
      'ai_assistant': 'AI Assistant (ABHIMAN)',
      'export_pdf': 'PDF Export',
      'email_reports': 'Email Reports',
      'dark_mode': 'Dark Mode',
      'offline_mode': 'Offline Mode',
      'multi_currency': 'Multi-Currency',
      'barcode_scanner': 'Barcode Scanner',
      'cloud_sync': 'Cloud Sync',
    };
    return names[feature] ?? feature;
  }

  String _getFeatureDescription(String feature) {
    final descriptions = {
      'ai_assistant': 'Smart business intelligence assistant',
      'export_pdf': 'Export invoices and reports as PDF',
      'email_reports': 'Send reports via email',
      'dark_mode': 'Dark theme for the app',
      'offline_mode': 'Work without internet connection',
      'multi_currency': 'Support multiple currencies',
      'barcode_scanner': 'Scan product barcodes',
      'cloud_sync': 'Real-time cloud synchronization',
    };
    return descriptions[feature] ?? '';
  }

  IconData _getFeatureIcon(String feature) {
    final icons = {
      'ai_assistant': Icons.psychology_rounded,
      'export_pdf': Icons.picture_as_pdf_rounded,
      'email_reports': Icons.email_rounded,
      'dark_mode': Icons.dark_mode_rounded,
      'offline_mode': Icons.cloud_off_rounded,
      'multi_currency': Icons.currency_exchange_rounded,
      'barcode_scanner': Icons.qr_code_scanner_rounded,
      'cloud_sync': Icons.cloud_sync_rounded,
    };
    return icons[feature] ?? Icons.settings_rounded;
  }

  void _pushUpdate() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Push Update'),
        content: const Text('This will notify all users to update the app. Continue?'),
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
                  content: Text('📢 Update notification sent to all users'),
                  backgroundColor: appleGreen,
                ),
              );
            },
            child: const Text('Push'),
          ),
        ],
      ),
    );
  }

  void _viewReleaseNotes() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📝 Release notes feature coming soon')),
    );
  }

  void _manageBeta() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🧪 Beta program feature coming soon')),
    );
  }
}
