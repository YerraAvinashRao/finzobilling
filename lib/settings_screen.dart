// lib/settings_screen.dart
import 'package:finzobilling/screens/invoice_settings_screen.dart';
import 'package:finzobilling/screens/privacy_policy_screen.dart';
import 'package:finzobilling/screens/terms_of_service_screen.dart';
import 'package:finzobilling/services/backup_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _gstinController = TextEditingController();
  final _panController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _termsController = TextEditingController();

  String _selectedState = 'Karnataka';
  bool _isLoading = false;
  bool _isFetching = true;
  String _appVersion = 'Loading...';
  DateTime? _lastBackupTime;
  bool _isBackingUp = false;

  // 🍎 APPLE iOS COLORS
  static const Color appleBackground = Color(0xFFFBFBFD);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleText = Color(0xFF1D1D1F);
  static const Color appleSecondary = Color(0xFF86868B);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleDivider = Color(0xFFD2D2D7);
  static const Color appleSubtle = Color(0xFFF5F5F7);

  final Map<String, String> _indianStates = {
    'Andhra Pradesh': '37',
    'Arunachal Pradesh': '12',
    'Assam': '18',
    'Bihar': '10',
    'Chhattisgarh': '22',
    'Goa': '30',
    'Gujarat': '24',
    'Haryana': '06',
    'Himachal Pradesh': '02',
    'Jharkhand': '20',
    'Karnataka': '29',
    'Kerala': '32',
    'Madhya Pradesh': '23',
    'Maharashtra': '27',
    'Manipur': '14',
    'Meghalaya': '17',
    'Mizoram': '15',
    'Nagaland': '13',
    'Odisha': '21',
    'Punjab': '03',
    'Rajasthan': '08',
    'Sikkim': '11',
    'Tamil Nadu': '33',
    'Telangana': '36',
    'Tripura': '16',
    'Uttar Pradesh': '09',
    'Uttarakhand': '05',
    'West Bengal': '19',
    'Delhi': '07',
    'Puducherry': '34',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setDefaultTerms();
    _loadAppVersion();
  }

  void _setDefaultTerms() {
    _termsController.text = '''1. Payment is due within 30 days from invoice date.
2. Late payments may attract interest charges.
3. Goods once sold will not be taken back.
4. Subject to local jurisdiction only.''';
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _upiIdController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> _getSettingsDocRef() {
    final user = FirebaseAuth.instance.currentUser!;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('business_details');
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _getSettingsDocRef().get();
      if (mounted && doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _businessNameController.text = data['name'] as String? ?? '';
        _gstinController.text = data['gstin'] as String? ?? '';
        _panController.text = data['pan'] as String? ?? '';
        _addressController.text = data['address'] as String? ?? '';
        _cityController.text = data['city'] as String? ?? '';
        _pincodeController.text = data['pincode'] as String? ?? '';
        _phoneController.text = data['phone'] as String? ?? '';
        _emailController.text = data['email'] as String? ?? '';
        _upiIdController.text = data['upiId'] as String? ?? '';
        _bankNameController.text = data['bankName'] as String? ?? '';
        _accountNumberController.text = data['accountNumber'] as String? ?? '';
        _ifscController.text = data['ifsc'] as String? ?? '';
        _termsController.text =
            data['terms'] as String? ?? _termsController.text;
        _selectedState = data['state'] as String? ?? 'Karnataka';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  String? _validateGSTIN(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final gstin = value.trim().toUpperCase();
    if (gstin.length != 15) return 'GSTIN must be 15 characters';

    final gstinRegex =
        RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
    if (!gstinRegex.hasMatch(gstin)) return 'Invalid GSTIN format';

    return null;
  }

  String? _validatePAN(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final pan = value.trim().toUpperCase();
    if (pan.length != 10) return 'PAN must be 10 characters';

    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    if (!panRegex.hasMatch(pan)) return 'Invalid PAN format';

    return null;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are not logged in.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      await _getSettingsDocRef().set({
        'name': _businessNameController.text.trim(),
        'gstin': _gstinController.text.trim().toUpperCase(),
        'pan': _panController.text.trim().toUpperCase(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _selectedState,
        'stateCode': _indianStates[_selectedState],
        'pincode': _pincodeController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'upiId': _upiIdController.text.trim(),
        'bankName': _bankNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'ifsc': _ifscController.text.trim().toUpperCase(),
        'terms': _termsController.text.trim(),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (e) {
      setState(() => _appVersion = '1.0.0');
    }
  }

  // [KEEP ALL YOUR BACKUP METHODS - _backupAllData, _exportInvoicesCSV, etc]
  Future<void> _backupAllData() async {
    setState(() => _isBackingUp = true);

    try {
      await BackupService().shareBackup();

      setState(() {
        _lastBackupTime = DateTime.now();
        _isBackingUp = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Backup created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isBackingUp = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportInvoicesCSV() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final filePath = await BackupService().exportInvoicesToCSV();
      if (mounted) Navigator.pop(context);
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportProductsCSV() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final filePath = await BackupService().exportProductsToCSV();
      if (mounted) Navigator.pop(context);
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportClientsCSV() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final filePath = await BackupService().exportClientsToCSV();
      if (mounted) Navigator.pop(context);
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirm Restore'),
        content: const Text(
          'This will replace ALL your current data with the backup. '
          'This action cannot be undone!\n\n'
          'Make sure you have a recent backup before proceeding.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final file = File(result.files.single.path!);
      final jsonData = await file.readAsString();

      await BackupService().importFromBackup(jsonData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data restored successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Restore failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appleBackground,
      appBar: AppBar(
        backgroundColor: appleCard,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: appleText,
            fontWeight: FontWeight.w600,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: appleText),
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  // Business Profile Card
                  _buildBusinessProfileCard(),

                  const SizedBox(height: 12),

                  // Invoice Settings Card
                  _buildInvoiceSettingsCard(),

                  const SizedBox(height: 12),

                  // Backup & Data Card
                  _buildBackupCard(),

                  const SizedBox(height: 12),

                  // Legal & Privacy Card
                  _buildLegalCard(),

                  const SizedBox(height: 12),

                  // About Card
                  _buildAboutCard(),

                  const SizedBox(height: 12),

                  // Logout Button
                  _buildLogoutButton(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

    // 🍎 BUSINESS PROFILE CARD
  Widget _buildBusinessProfileCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appleDivider.withOpacity(0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: appleAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business_rounded,
                      color: appleAccent, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Business Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: appleText,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: appleDivider.withOpacity(0.5), height: 1),
          _buildListTile(
            icon: Icons.edit_rounded,
            title: 'Edit Business Details',
            subtitle: _businessNameController.text.isEmpty
                ? 'Set up your business information'
                : _businessNameController.text,
            onTap: () => _showBusinessDetailsSheet(),
          ),
        ],
      ),
    );
  }

  // 🍎 INVOICE SETTINGS CARD
  Widget _buildInvoiceSettingsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appleDivider.withOpacity(0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: Colors.purple, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Invoice & Branding',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: appleText,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: appleDivider.withOpacity(0.5), height: 1),
          _buildListTile(
            icon: Icons.palette_rounded,
            title: 'Invoice Templates',
            subtitle: 'Customize PDF design & branding',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const InvoiceSettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  // 🍎 BACKUP & DATA CARD
  Widget _buildBackupCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appleDivider.withOpacity(0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.backup_rounded,
                      color: Colors.green, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Backup & Export',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: appleText,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_lastBackupTime != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last backup: ${DateFormat('dd MMM yyyy, hh:mm a').format(_lastBackupTime!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Divider(color: appleDivider.withOpacity(0.5), height: 1),
          _buildListTile(
            icon: Icons.cloud_upload_rounded,
            title: 'Backup All Data',
            subtitle: 'Export everything to JSON file',
            onTap: _isBackingUp ? null : _backupAllData,
            trailing: _isBackingUp
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          Divider(color: appleDivider.withOpacity(0.5), height: 1),
          _buildListTile(
            icon: Icons.table_chart_rounded,
            title: 'Export Invoices (CSV)',
            subtitle: 'Download as spreadsheet',
            onTap: _exportInvoicesCSV,
          ),
          Divider(color: appleDivider.withOpacity(0.5), height: 1),
          _buildListTile(
            icon: Icons.inventory_2_rounded,
            title: 'Export Products (CSV)',
            subtitle: 'Download product list',
            onTap: _exportProductsCSV,
          ),
          Divider(color: appleDivider.withOpacity(0.5), height: 1),
          _buildListTile(
            icon: Icons.people_rounded,
            title: 'Export Clients (CSV)',
            subtitle: 'Download client database',
            onTap: _exportClientsCSV,
          ),
          Divider(color: appleDivider.withOpacity(0.5), height: 1),
          _buildListTile(
            icon: Icons.cloud_download_rounded,
            iconColor: Colors.orange,
            title: 'Restore from Backup',
            subtitle: 'Import data from file',
            onTap: _restoreBackup,
          ),
        ],
      ),
    );
  }

  // 🍎 LEGAL & PRIVACY CARD
  Widget _buildLegalCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appleDivider.withOpacity(0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.policy_rounded,
                      color: Colors.blue, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Legal & Privacy',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: appleText,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: appleDivider.withOpacity(0.5), height: 1),
          _buildListTile(
            icon: Icons.security_rounded,
            title: 'Privacy Policy',
            subtitle: 'How we protect your data',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),
          Divider(color: appleDivider.withOpacity(0.5), height: 1),
          _buildListTile(
            icon: Icons.description_rounded,
            title: 'Terms of Service',
            subtitle: 'App usage terms',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  // 🍎 ABOUT CARD
  Widget _buildAboutCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appleDivider.withOpacity(0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: appleSecondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.info_rounded,
                      color: appleSecondary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'About',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: appleText,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: appleDivider.withOpacity(0.5), height: 1),
          _buildListTile(
            icon: Icons.app_settings_alt_rounded,
            title: 'App Version',
            subtitle: _appVersion,
          ),
          Divider(color: appleDivider.withOpacity(0.5), height: 1),
          _buildListTile(
            icon: Icons.email_rounded,
            title: 'Contact Support',
            subtitle: 'support@finzobilling.com',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email: support@finzobilling.com')),
              );
            },
          ),
        ],
      ),
    );
  }

  // 🍎 REUSABLE LIST TILE
  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? appleSecondary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: appleText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: appleSecondary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right_rounded,
                    color: appleSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  // 🍎 LOGOUT BUTTON
  Widget _buildLogoutButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Sign Out?'),
              content: const Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          );

          if (confirm == true) {
            await FirebaseAuth.instance.signOut();
          }
        },
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

    // 🍎 BUSINESS DETAILS BOTTOM SHEET (Apple iOS Style)
  void _showBusinessDetailsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: appleBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: appleDivider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Business Details',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: appleText,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),

                Divider(color: appleDivider.withOpacity(0.5), height: 1),

                // Scrollable Form
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Business Info Section
                      _buildSectionHeader('Business Information'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _businessNameController,
                        label: 'Business Name',
                        icon: Icons.business_rounded,
                        required: true,
                      ),
                      const SizedBox(height: 12),

                      // GST & Tax Section
                      _buildSectionHeader('GST & Tax Details'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _gstinController,
                        label: 'GSTIN (Optional)',
                        hint: '22AAAAA0000A1Z5',
                        icon: Icons.receipt_long_rounded,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 15,
                        validator: _validateGSTIN,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _panController,
                        label: 'PAN (Optional)',
                        hint: 'AAAAA0000A',
                        icon: Icons.credit_card_rounded,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 10,
                        validator: _validatePAN,
                      ),
                      const SizedBox(height: 12),

                      // Address Section
                      _buildSectionHeader('Address Details'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _addressController,
                        label: 'Address',
                        icon: Icons.location_on_rounded,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cityController,
                              label: 'City',
                              icon: Icons.location_city_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 120,
                            child: _buildTextField(
                              controller: _pincodeController,
                              label: 'Pincode',
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildStateDropdown(),
                      const SizedBox(height: 12),

                      // Contact Section
                      _buildSectionHeader('Contact Information'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Business Phone',
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),

                      // Payment Section
                      _buildSectionHeader('Payment Details'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _upiIdController,
                        label: 'UPI ID',
                        hint: 'yourname@oksbi',
                        icon: Icons.payment_rounded,
                        required: true,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _bankNameController,
                        label: 'Bank Name (Optional)',
                        icon: Icons.account_balance_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _accountNumberController,
                        label: 'Account Number (Optional)',
                        icon: Icons.numbers_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _ifscController,
                        label: 'IFSC Code (Optional)',
                        hint: 'SBIN0001234',
                        icon: Icons.code_rounded,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 11,
                      ),
                      const SizedBox(height: 12),

                      // Terms Section
                      _buildSectionHeader('Invoice Terms & Conditions'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _termsController,
                        label: 'Default Terms (Optional)',
                        icon: Icons.description_rounded,
                        maxLines: 5,
                      ),

                      const SizedBox(height: 32),

                      // Save Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appleAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Settings',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.4,
                                ),
                              ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🍎 SECTION HEADER
  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: appleSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  // 🍎 TEXT FIELD
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    bool required = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        filled: true,
        fillColor: appleCard,
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: appleDivider.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: appleDivider.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: appleAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty)
                  ? '$label is required'
                  : null
              : null),
    );
  }

  // 🍎 STATE DROPDOWN
  Widget _buildStateDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedState,
      decoration: InputDecoration(
        labelText: 'State *',
        prefixIcon: const Icon(Icons.map_rounded, size: 20),
        filled: true,
        fillColor: appleCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: appleDivider.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: appleDivider.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: appleAccent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: _indianStates.keys.map((state) {
        return DropdownMenuItem(
          value: state,
          child: Text(
            '$state (${_indianStates[state]})',
            style: const TextStyle(fontSize: 15, letterSpacing: -0.2),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedState = value);
        }
      },
    );
  }

  // END OF CLASS
}
