import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final _firestore = FirebaseFirestore.instance;
  
  // 🍎 Apple Colors
  static const Color appleBackground = Color(0xFFF2F2F7);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleRed = Color(0xFFFF3B30);
  static const Color appleGreen = Color(0xFF34C759);
  static const Color appleOrange = Color(0xFFFF9500);

  // Settings
  bool _maintenanceMode = false;
  bool _allowNewRegistrations = true;
  bool _emailVerificationRequired = false;
  bool _twoFactorEnabled = false;
  bool _analyticsEnabled = true;
  bool _crashReportingEnabled = true;
  bool _autoBackupEnabled = true;
  int _maxLoginAttempts = 5;
  int _sessionTimeoutMinutes = 30;
  String _appVersion = '1.0.0';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _firestore.collection('system_settings').doc('config').get();
      
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _maintenanceMode = data['maintenanceMode'] ?? false;
          _allowNewRegistrations = data['allowNewRegistrations'] ?? true;
          _emailVerificationRequired = data['emailVerificationRequired'] ?? false;
          _twoFactorEnabled = data['twoFactorEnabled'] ?? false;
          _analyticsEnabled = data['analyticsEnabled'] ?? true;
          _crashReportingEnabled = data['crashReportingEnabled'] ?? true;
          _autoBackupEnabled = data['autoBackupEnabled'] ?? true;
          _maxLoginAttempts = data['maxLoginAttempts'] ?? 5;
          _sessionTimeoutMinutes = data['sessionTimeoutMinutes'] ?? 30;
          _appVersion = data['appVersion'] ?? '1.0.0';
          _isLoading = false;
        });
      } else {
        // Create default settings
        await _saveDefaultSettings();
      }
    } catch (e) {
      print('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDefaultSettings() async {
    await _firestore.collection('system_settings').doc('config').set({
      'maintenanceMode': false,
      'allowNewRegistrations': true,
      'emailVerificationRequired': false,
      'twoFactorEnabled': false,
      'analyticsEnabled': true,
      'crashReportingEnabled': true,
      'autoBackupEnabled': true,
      'maxLoginAttempts': 5,
      'sessionTimeoutMinutes': 30,
      'appVersion': '1.0.0',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    setState(() => _isLoading = false);
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      await _firestore.collection('system_settings').doc('config').update({
        key: value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.email ?? 'system',
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Setting saved successfully'),
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
                'System Settings',
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
          // 🚨 Critical Settings
          _buildSectionHeader('Critical Settings', Icons.warning_rounded, appleRed),
          const SizedBox(height: 12),
          _buildCriticalSettings(),
          
          const SizedBox(height: 24),
          
          // 🔐 Security Settings
          _buildSectionHeader('Security', Icons.security_rounded, appleOrange),
          const SizedBox(height: 12),
          _buildSecuritySettings(),
          
          const SizedBox(height: 24),
          
          // 📊 Analytics & Monitoring
          _buildSectionHeader('Analytics & Monitoring', Icons.analytics_rounded, appleAccent),
          const SizedBox(height: 12),
          _buildAnalyticsSettings(),
          
          const SizedBox(height: 24),
          
          // ⚙️ App Configuration
          _buildSectionHeader('App Configuration', Icons.settings_rounded, Colors.grey),
          const SizedBox(height: 12),
          _buildAppConfiguration(),
          
          const SizedBox(height: 24),
          
          // 🗄️ Database Actions
          _buildSectionHeader('Database Actions', Icons.storage_rounded, Colors.purple),
          const SizedBox(height: 12),
          _buildDatabaseActions(),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
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

  Widget _buildCriticalSettings() {
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
          _buildSwitchTile(
            'Maintenance Mode',
            'Put app in maintenance mode (users cannot access)',
            _maintenanceMode,
            appleRed,
            (value) {
              setState(() => _maintenanceMode = value);
              _saveSetting('maintenanceMode', value);
            },
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildSwitchTile(
            'Allow New Registrations',
            'Enable or disable new user signups',
            _allowNewRegistrations,
            appleGreen,
            (value) {
              setState(() => _allowNewRegistrations = value);
              _saveSetting('allowNewRegistrations', value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySettings() {
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
          _buildSwitchTile(
            'Email Verification Required',
            'Require email verification for new accounts',
            _emailVerificationRequired,
            appleOrange,
            (value) {
              setState(() => _emailVerificationRequired = value);
              _saveSetting('emailVerificationRequired', value);
            },
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildSwitchTile(
            'Two-Factor Authentication',
            'Enable 2FA for all admin accounts',
            _twoFactorEnabled,
            appleAccent,
            (value) {
              setState(() => _twoFactorEnabled = value);
              _saveSetting('twoFactorEnabled', value);
            },
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildNumberTile(
            'Max Login Attempts',
            'Maximum failed login attempts before lockout',
            _maxLoginAttempts,
            1,
            10,
            (value) {
              setState(() => _maxLoginAttempts = value);
              _saveSetting('maxLoginAttempts', value);
            },
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildNumberTile(
            'Session Timeout (minutes)',
            'Auto-logout after inactivity',
            _sessionTimeoutMinutes,
            5,
            120,
            (value) {
              setState(() => _sessionTimeoutMinutes = value);
              _saveSetting('sessionTimeoutMinutes', value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSettings() {
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
          _buildSwitchTile(
            'Analytics Tracking',
            'Collect usage analytics',
            _analyticsEnabled,
            appleAccent,
            (value) {
              setState(() => _analyticsEnabled = value);
              _saveSetting('analyticsEnabled', value);
            },
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildSwitchTile(
            'Crash Reporting',
            'Send crash reports to Firebase Crashlytics',
            _crashReportingEnabled,
            appleOrange,
            (value) {
              setState(() => _crashReportingEnabled = value);
              _saveSetting('crashReportingEnabled', value);
            },
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildSwitchTile(
            'Auto Backup',
            'Automatic daily database backup',
            _autoBackupEnabled,
            appleGreen,
            (value) {
              setState(() => _autoBackupEnabled = value);
              _saveSetting('autoBackupEnabled', value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppConfiguration() {
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Version',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current version: $_appVersion',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(
                height: 36, // ✅ ADDED FIXED HEIGHT
                child: ElevatedButton.icon(
                  onPressed: () => _showVersionDialog(),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Update'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero, // ✅ ADDED THIS
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap, // ✅ ADDED THIS
                  ),
                ),
              ),

            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseActions() {
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
            'Export Database',
            'Download complete database backup',
            Icons.download_rounded,
            appleAccent,
            () => _exportDatabase(),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildActionTile(
            'Clear Cache',
            'Clear all cached data',
            Icons.cleaning_services_rounded,
            appleOrange,
            () => _clearCache(),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildActionTile(
            'View Activity Logs',
            'See all system activity logs',
            Icons.history_rounded,
            Colors.purple,
            () => _viewLogs(),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildActionTile(
            'Delete Old Data',
            'Remove data older than 1 year',
            Icons.delete_sweep_rounded,  // ✅ CORRECT - This is an IconData
            appleRed,
            () => _deleteOldData(),
          ),

        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Color color, Function(bool) onChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: color,
      ),
    );
  }

  Widget _buildNumberTile(String title, String subtitle, int value, int min, int max, Function(int) onChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: SizedBox(
        width: 140, // ✅ ADDED FIXED WIDTH
        child: Row(
          mainAxisSize: MainAxisSize.min, // ✅ ADDED THIS
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20), // ✅ Reduced icon size
              onPressed: value > min ? () => onChanged(value - 1) : null,
              color: appleAccent,
              padding: EdgeInsets.zero, // ✅ ADDED THIS
              constraints: const BoxConstraints(), // ✅ ADDED THIS
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: appleAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value.toString(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20), // ✅ Reduced icon size
              onPressed: value < max ? () => onChanged(value + 1) : null,
              color: appleAccent,
              padding: EdgeInsets.zero, // ✅ ADDED THIS
              constraints: const BoxConstraints(), // ✅ ADDED THIS
            ),
          ],
        ),
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

  void _showVersionDialog() {
    final controller = TextEditingController(text: _appVersion);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update App Version'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Version Number',
            hintText: 'e.g., 1.0.1',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _appVersion = controller.text);
              _saveSetting('appVersion', controller.text);
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _exportDatabase() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📥 Database export started...')),
    );
    // TODO: Implement actual export
  }

  void _clearCache() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🧹 Cache cleared!')),
    );
  }

  void _viewLogs() {
    // Navigate to logs screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📝 Activity logs feature coming soon')),
    );
  }

  void _deleteOldData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Warning'),
        content: const Text('This will permanently delete data older than 1 year. Continue?'),
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
                const SnackBar(content: Text('🗑️ Old data deletion started...')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
