import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finzobilling/models/invoice_settings.dart';
import 'package:finzobilling/services/logo_storage_service.dart';

class InvoiceSettingsScreen extends StatefulWidget {
  const InvoiceSettingsScreen({super.key});

  @override
  State<InvoiceSettingsScreen> createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends State<InvoiceSettingsScreen> {
  final _logoService = LogoStorageService();
  
  late InvoiceSettings _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<Map<String, String>> _templates = [
    {'id': 'classic', 'name': 'Classic Professional', 'desc': 'Traditional formal layout'},
    {'id': 'modern', 'name': 'Modern Minimal', 'desc': 'Clean minimalist design'},
    {'id': 'colorful', 'name': 'Colorful Business', 'desc': 'Vibrant brand colors'},
    {'id': 'service', 'name': 'Service Invoice', 'desc': 'For consultancy/services'},
    {'id': 'retail', 'name': 'Retail Bill', 'desc': 'Quick POS-style receipt'},
  ];

  final List<String> _logoPositions = ['left', 'center', 'right'];
  final List<String> _paymentTerms = ['Net 7 Days', 'Net 15 Days', 'Net 30 Days', 'Net 45 Days', 'Due on Receipt'];
  final List<String> _watermarkOptions = ['ORIGINAL', 'COPY', 'PAID', 'UNPAID', 'DUPLICATE'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('invoice_settings');
      
      if (settingsJson != null) {
        _settings = InvoiceSettings.fromJson(settingsJson);
      } else {
        _settings = InvoiceSettings();
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Error loading settings: $e');
      _settings = InvoiceSettings();
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('invoice_settings', _settings.toJson());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Invoice settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _pickLogo() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Logo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    File? logoFile;
    if (result == 'gallery') {
      logoFile = await _logoService.pickLogoFromGallery();
    } else {
      logoFile = await _logoService.captureLogoFromCamera();
    }

    if (logoFile != null) {
      setState(() {
        if (_settings.logoPath != null) {
          _logoService.deleteImage(_settings.logoPath);
        }
        _settings = _settings.copyWith(logoPath: logoFile!.path);
      });
    }
  }

  Future<void> _pickSignature() async {
    final signFile = await _logoService.pickSignatureFromGallery();
    
    if (signFile != null) {
      setState(() {
        if (_settings.signaturePath != null) {
          _logoService.deleteImage(_settings.signaturePath);
        }
        _settings = _settings.copyWith(signaturePath: signFile.path);
      });
    }
  }

  void _pickColor(bool isPrimary) {
    Color currentColor = _parseColor(isPrimary ? _settings.primaryColor : _settings.secondaryColor);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPrimary ? 'Primary Color' : 'Secondary Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) => currentColor = color,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final hexColor = '#${currentColor.value.toRadixString(16).substring(2).toUpperCase()}';
                if (isPrimary) {
                  _settings = _settings.copyWith(primaryColor: hexColor);
                } else {
                  _settings = _settings.copyWith(secondaryColor: hexColor);
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceAll('#', 'FF'), radix: 16));
    } catch (e) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Settings'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Branding & Appearance'),
          const SizedBox(height: 12),
          
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: const Icon(Icons.image, color: Colors.blue),
              ),
              title: const Text('Company Logo'),
              subtitle: _settings.logoPath != null
                  ? const Text('Logo uploaded ✓')
                  : const Text('No logo uploaded'),
              trailing: _settings.logoPath != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility, size: 20),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                child: Image.file(File(_settings.logoPath!)),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _logoService.deleteImage(_settings.logoPath);
                              _settings = _settings.copyWith(logoPath: '');
                            });
                          },
                        ),
                      ],
                    )
                  : const Icon(Icons.add_photo_alternate),
              onTap: _pickLogo,
            ),
          ),
          const SizedBox(height: 8),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Invoice Template',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ..._templates.map((template) {
                    return RadioListTile<String>(
                      dense: true,
                      title: Text(template['name']!),
                      subtitle: Text(template['desc']!, style: const TextStyle(fontSize: 12)),
                      value: template['id']!,
                      groupValue: _settings.templateStyle,
                      onChanged: (value) {
                        setState(() {
                          _settings = _settings.copyWith(templateStyle: value);
                        });
                      },
                      activeColor: Colors.blue,
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Brand Colors',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickColor(true),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: _parseColor(_settings.primaryColor),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: const Center(
                              child: Text(
                                'Primary Color',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickColor(false),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: _parseColor(_settings.secondaryColor),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: const Center(
                              child: Text(
                                'Secondary Color',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Logo Position',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: _logoPositions.map((pos) {
                      return ButtonSegment(
                        value: pos,
                        label: Text(pos.toUpperCase()),
                      );
                    }).toList(),
                    selected: {_settings.logoPosition},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() {
                        _settings = _settings.copyWith(logoPosition: selection.first);
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Show Watermark'),
                    value: _settings.showWatermark,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(showWatermark: value);
                      });
                    },
                  ),
                  if (_settings.showWatermark)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Watermark Text',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _settings.watermarkText,
                      items: _watermarkOptions.map((text) {
                        return DropdownMenuItem(value: text, child: Text(text));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _settings = _settings.copyWith(watermarkText: value);
                        });
                      },
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
            // ℹ️ Payment details are managed in Business Settings
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Payment details (UPI, Bank Account) are managed in Business Settings',
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),


          const SizedBox(height: 24),
          
          _buildSectionHeader('Signature & Authorization'),
          const SizedBox(height: 12),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: const Icon(Icons.draw, color: Colors.green),
                    ),
                    title: const Text('Digital Signature'),
                    subtitle: _settings.signaturePath != null
                        ? const Text('Signature uploaded ✓')
                        : const Text('No signature uploaded'),
                    trailing: _settings.signaturePath != null
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _logoService.deleteImage(_settings.signaturePath);
                                _settings = _settings.copyWith(signaturePath: '');
                              });
                            },
                          )
                        : const Icon(Icons.add),
                    onTap: _pickSignature,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _settings.signatoryName,
                    decoration: const InputDecoration(
                      labelText: 'Signatory Name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _settings = _settings.copyWith(signatoryName: value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _settings.signatoryDesignation,
                    decoration: const InputDecoration(
                      labelText: 'Designation',
                      hintText: 'e.g., Managing Director',
                      prefixIcon: Icon(Icons.work),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _settings = _settings.copyWith(signatoryDesignation: value);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          
          _buildSectionHeader('Terms & Conditions'),
          const SizedBox(height: 12),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextFormField(
                initialValue: _settings.termsAndConditions,
                decoration: const InputDecoration(
                  labelText: 'Default Terms',
                  border: OutlineInputBorder(),
                  helperText: 'These terms will appear on all invoices',
                  helperMaxLines: 2,
                ),
                maxLines: 8,
                onChanged: (value) {
                  _settings = _settings.copyWith(termsAndConditions: value);
                },
              ),
            ),
          ),

          const SizedBox(height: 24),
          
          _buildSectionHeader('Additional Fields'),
          const SizedBox(height: 12),
          
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Show PO Number'),
                  value: _settings.showPONumber,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(showPONumber: value);
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Show Delivery Note'),
                  value: _settings.showDeliveryNote,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(showDeliveryNote: value);
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Show Transport Details'),
                  value: _settings.showTransportDetails,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(showTransportDetails: value);
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Show E-Way Bill Number'),
                  value: _settings.showEWayBill,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(showEWayBill: value);
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Detailed Tax Breakdown (B2C)'),
                  subtitle: const Text('Show separate CGST/SGST for B2C invoices'),
                  value: _settings.showDetailedTaxBreakdown,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(showDetailedTaxBreakdown: value);
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save),
            label: const Text('Save Invoice Settings'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          color: Colors.blue,
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }
}
