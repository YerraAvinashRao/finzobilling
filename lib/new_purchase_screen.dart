// new_purchase_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'add_edit_purchase_item_dialog.dart';
import 'line_item.dart';
import 'add_edit_supplier_screen.dart';
import 'suppliers_screen.dart';
import 'imgbb_upload_helper.dart';

// [KEEP YOUR EXISTING CLASSES - SupplierLookup and PurchaseLineItem UNCHANGED]
class SupplierLookup {
  final String id;
  final String name;
  final String? gstin;
  final String? address;
  final String? state;
  final String? stateCode;

  SupplierLookup({
    required this.id,
    required this.name,
    this.gstin,
    this.address,
    this.state,
    this.stateCode,
  });

  @override
  String toString() => name;
}

class PurchaseLineItem extends LineItem {
  @override
  double? costPrice;
  double cgst;
  double sgst;
  double igst;
  String unit;

  PurchaseLineItem({
    super.id,
    required super.name,
    required super.quantity,
    required super.price,
    this.costPrice,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    required this.unit,
    super.hsnSac,
  }) : super(
          costPrice: costPrice,
        );

  double get totalCostValue => (costPrice ?? 0) * quantity;
  double get taxRatePercent => cgst + sgst + igst;
  @override
  double get totalTaxAmount => totalCostValue * (taxRatePercent / 100);

  @override
  Map<String, dynamic> toMap() {
    return {
      'productId': id,
      'productName': name,
      'quantity': quantity,
      'price': price,
      'costPrice': costPrice,
      'cgst': cgst,
      'sgst': sgst,
      'igst': igst,
      'hsnSac': hsnSac,
      'unit': unit,
      'totalCostValue': totalCostValue,
      'totalTaxAmount': totalTaxAmount,
      'lineTotal': totalCostValue + totalTaxAmount,
    };
  }
}

class NewPurchaseScreen extends StatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  State<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends State<NewPurchaseScreen> {
  // 🍎 APPLE iOS COLORS
  static const Color appleBackground = Color(0xFFFBFBFD);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleText = Color(0xFF1D1D1F);
  static const Color appleSecondary = Color(0xFF86868B);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleDivider = Color(0xFFD2D2D7);
  static const Color appleSubtle = Color(0xFFF5F5F7);
  static const Color appleSuccess = Color(0xFF34C759);
  static const Color appleWarning = Color(0xFFFF9500);
  static const Color appleError = Color(0xFFFF3B30);

  // [KEEP ALL YOUR EXISTING VARIABLES]
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _invoiceNumberController = TextEditingController();
  final TextEditingController _placeOfSupplyController = TextEditingController();

  SupplierLookup? _selectedSupplier;
  DateTime _invoiceDate = DateTime.now();
  bool _reverseCharge = false;
  bool _itcEligible = true;

  List<SupplierLookup> _supplierSuggestions = [];
  final List<PurchaseLineItem> _items = [];
  final List<File> _attachedFiles = [];
  final List<String> _attachedFileNames = [];

  bool _isSaving = false;
  bool _isUploading = false;

  // [KEEP ALL YOUR EXISTING METHODS - getUserDocRef, initState, dispose, etc.]
  DocumentReference<Map<String, dynamic>>? _getUserDocRef() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _invoiceNumberController.dispose();
    _placeOfSupplyController.dispose();
    super.dispose();
  }

  Future<void> _fetchSuppliers() async {
    final userDocRef = _getUserDocRef();
    if (userDocRef == null) return;

    try {
      final suppliersSnapshot = await userDocRef.collection('suppliers').get();

      _supplierSuggestions = suppliersSnapshot.docs
          .map((doc) => SupplierLookup(
                id: doc.id,
                name: (doc.data()['name'] ?? 'Unnamed').toString(),
                gstin: (doc.data()['gstin'])?.toString(),
                address: (doc.data()['address'])?.toString(),
                state: (doc.data()['state'])?.toString(),
                stateCode: (doc.data()['stateCode'])?.toString(),
              ))
          .toList();

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error fetching suppliers: $e');
    }
  }

  Future<void> _selectSupplierFromList() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const SuppliersScreen(selectionMode: true),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedSupplier = SupplierLookup(
          id: result['id'],
          name: result['name'],
          gstin: result['gstin'],
          address: result['address'],
          state: result['state'],
          stateCode: result['stateCode'],
        );
        _supplierController.text = result['name'];
        _placeOfSupplyController.text = result['state'] ?? '';
      });
    }
  }

  Future<void> _addNewSupplier() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditSupplierScreen(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedSupplier = SupplierLookup(
          id: result['id'],
          name: result['name'],
          gstin: result['gstin'],
          address: result['address'],
          state: result['state'],
          stateCode: result['stateCode'],
        );
        _supplierController.text = result['name'];
        _placeOfSupplyController.text = result['state'] ?? '';
      });

      await _fetchSuppliers();
    }
  }

  // [KEEP ALL YOUR FILE PICKER METHODS]
  Future<void> _captureInvoiceImage() async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (photo != null) {
      setState(() {
        _attachedFiles.add(File(photo.path));
        _attachedFileNames.add(photo.name);
      });
    }
  }

  Future<void> _pickInvoiceImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _attachedFiles.add(File(image.path));
        _attachedFileNames.add(image.name);
      });
    }
  }

  Future<void> _pickInvoicePDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _attachedFiles.add(File(result.files.single.path!));
        _attachedFileNames.add(result.files.single.name);
      });
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: appleCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: appleDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Attach Invoice',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: appleText,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Divider(color: appleDivider.withOpacity(0.5), height: 1),
              _buildAttachmentOption(
                icon: Icons.camera_alt_rounded,
                title: 'Take Photo',
                subtitle: 'Capture invoice with camera',
                onTap: () {
                  Navigator.pop(context);
                  _captureInvoiceImage();
                },
              ),
              Divider(color: appleDivider.withOpacity(0.5), height: 1),
              _buildAttachmentOption(
                icon: Icons.photo_library_rounded,
                title: 'Choose from Gallery',
                subtitle: 'Select image from photos',
                onTap: () {
                  Navigator.pop(context);
                  _pickInvoiceImage();
                },
              ),
              Divider(color: appleDivider.withOpacity(0.5), height: 1),
              _buildAttachmentOption(
                icon: Icons.picture_as_pdf_rounded,
                title: 'Select PDF',
                subtitle: 'Choose PDF document',
                onTap: () {
                  Navigator.pop(context);
                  _pickInvoicePDF();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: appleAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: appleAccent, size: 22),
            ),
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: appleSecondary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: appleSecondary, size: 20),
          ],
        ),
      ),
    );
  } 
    // [KEEP YOUR VALIDATION METHOD]
  void _validateSupplierBeforeAddingItem() {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Please select a supplier first to determine tax type'),
              ),
            ],
          ),
          backgroundColor: appleWarning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_selectedSupplier!.state == null || _selectedSupplier!.state!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Supplier state is missing. Please update supplier details.'),
              ),
            ],
          ),
          backgroundColor: appleError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    _showAddOrEditItemDialog();
  }

  // [KEEP YOUR DIALOG METHOD - EXACTLY AS IS]
  Future<void> _showAddOrEditItemDialog({
    PurchaseLineItem? editingItem,
    int? editingIndex,
  }) async {
    if (!mounted) return;

    final userDocRef = _getUserDocRef();
    if (userDocRef == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('User not logged in'),
              ],
            ),
            backgroundColor: appleError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    if (_selectedSupplier == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Please select a supplier first'),
              ],
            ),
            backgroundColor: appleWarning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    List<Map<String, dynamic>> products = [];

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: appleCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: appleAccent),
                  SizedBox(height: 16),
                  Text(
                    'Loading products...',
                    style: TextStyle(
                      color: appleText,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final productsSnapshot = await userDocRef
          .collection('products')
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Connection timeout. Please check your internet.');
            },
          );

      products = productsSnapshot.docs
          .map((doc) {
            try {
              return {'id': doc.id, ...doc.data()};
            } catch (e) {
              debugPrint('Error parsing product ${doc.id}: $e');
              return null;
            }
          })
          .where((product) => product != null)
          .cast<Map<String, dynamic>>()
          .toList();

      if (!mounted) return;
      Navigator.pop(context);

      debugPrint('🔍 Selected Supplier: ${_selectedSupplier?.name}');
      debugPrint('🔍 Supplier State: ${_selectedSupplier?.state}');
      debugPrint('🔍 Supplier GSTIN: ${_selectedSupplier?.gstin}');
      debugPrint('🔍 Products fetched: ${products.length}');

      if (!mounted) return;
      final newItem = await showDialog<PurchaseLineItem?>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AddEditPurchaseItemDialog(
          editingItem: editingItem,
          allProducts: products,
          supplierState: _selectedSupplier?.state ?? '',
          supplierGSTIN: _selectedSupplier?.gstin ?? '',
        ),
      );

      if (newItem != null && mounted) {
        setState(() {
          if (editingIndex != null && editingIndex < _items.length) {
            _items[editingIndex] = newItem;
          } else {
            _items.add(newItem);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(editingIndex != null ? 'Item updated' : 'Item added'),
              ],
            ),
            backgroundColor: appleSuccess,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in _showAddOrEditItemDialog: $e');
      debugPrint('📍 Stack trace: $stackTrace');

      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: appleError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _showAddOrEditItemDialog(
                editingItem: editingItem,
                editingIndex: editingIndex,
              ),
            ),
          ),
        );
      }
    }
  }

  double get _totalPurchaseAmount => _items.fold(
        0.0,
        (sum, item) => sum + item.totalCostValue + item.totalTaxAmount,
      );

  // [KEEP YOUR UPLOAD METHOD]
  Future<List<String>> _uploadAttachments() async {
    if (_attachedFiles.isEmpty) return [];

    setState(() => _isUploading = true);

    List<String> downloadUrls = [];

    try {
      downloadUrls = await ImgBBUploadHelper.uploadMultipleImages(_attachedFiles);

      if (downloadUrls.length < _attachedFiles.length) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Some files failed to upload'),
                ],
              ),
              backgroundColor: appleWarning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Upload error: $e')),
              ],
            ),
            backgroundColor: appleError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }

    return downloadUrls;
  }

  // [KEEP YOUR SAVE METHOD - EXACT LOGIC]
  Future<void> _savePurchase() async {
    if (_selectedSupplier == null ||
        _invoiceNumberController.text.trim().isEmpty ||
        _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Please fill supplier, invoice number, and add items'),
              ),
            ],
          ),
          backgroundColor: appleWarning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final userDocRef = _getUserDocRef();
    if (userDocRef == null) return;

    setState(() => _isSaving = true);

    try {
      final attachmentUrls = await _uploadAttachments();

      final batch = FirebaseFirestore.instance.batch();
      final purchaseRef = userDocRef.collection('purchases').doc();
      final productIds = _items.map((item) => item.id).whereType<String>().toList();

      batch.set(purchaseRef, {
        'supplierId': _selectedSupplier!.id,
        'supplierName': _selectedSupplier!.name,
        'supplierGstin': _selectedSupplier!.gstin,
        'supplierState': _selectedSupplier!.state,
        'supplierStateCode': _selectedSupplier!.stateCode,
        'invoiceNumber': _invoiceNumberController.text.trim(),
        'invoiceDate': Timestamp.fromDate(_invoiceDate),
        'placeOfSupply': _placeOfSupplyController.text.trim(),
        'reverseCharge': _reverseCharge,
        'itcEligible': _itcEligible,
        'totalCost': _totalPurchaseAmount,
        'lineItems': _items.map((i) => i.toMap()).toList(),
        'attachments': attachmentUrls,
        'attachmentCount': attachmentUrls.length,
        'createdAt': Timestamp.now(),
        'createdBy': FirebaseAuth.instance.currentUser?.email,
        'productIds': productIds,
      });

      for (var item in _items) {
        final productRef = userDocRef.collection('products').doc(item.id);
        final productSnap = await productRef.get();

        if (productSnap.exists) {
          batch.update(productSnap.reference, {
            'currentStock': FieldValue.increment(item.quantity),
            'sellingPrice': item.price,
            'costPrice': item.costPrice,
            'name': item.name,
            'hsnSac': item.hsnSac,
            'unit': item.unit,
            'cgst': item.cgst,
            'sgst': item.sgst,
            'igst': item.igst,
            'updatedAt': Timestamp.now(),
          });
        } else {
          final newProductRef = userDocRef.collection('products').doc();
          batch.set(newProductRef, {
            'id': newProductRef.id,
            'name': item.name,
            'currentStock': item.quantity,
            'sellingPrice': item.price,
            'costPrice': item.costPrice,
            'hsnSac': item.hsnSac,
            'unit': item.unit,
            'cgst': item.cgst,
            'sgst': item.sgst,
            'igst': item.igst,
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });
        }
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Purchase saved successfully!'),
            ],
          ),
          backgroundColor: appleSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: appleError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

    @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      backgroundColor: appleBackground,
      appBar: AppBar(
        backgroundColor: appleCard,
        elevation: 0,
        title: const Text(
          'New Purchase',
          style: TextStyle(
            color: appleText,
            fontWeight: FontWeight.w600,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: appleText),
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: appleAccent,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              onPressed: _isSaving ? null : _savePurchase,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: appleAccent,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_rounded, color: appleAccent),
              tooltip: 'Save Purchase',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🍎 SUPPLIER SECTION
            _buildSectionCard(
              title: 'Supplier Details',
              icon: Icons.business_rounded,
              color: appleAccent,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectSupplierFromList,
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: _supplierController,
                              style: const TextStyle(
                                fontSize: 15,
                                letterSpacing: -0.2,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Supplier Name *',
                                hintText: 'Tap to select',
                                filled: true,
                                fillColor: appleSubtle,
                                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                                suffixIcon: _selectedSupplier != null
                                    ? IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            _selectedSupplier = null;
                                            _supplierController.clear();
                                            _placeOfSupplyController.clear();
                                          });
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: appleAccent, width: 2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: appleAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: _addNewSupplier,
                          icon: const Icon(Icons.add_rounded, color: Colors.white),
                          tooltip: 'Add New Supplier',
                        ),
                      ),
                    ],
                  ),
                  if (_selectedSupplier != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: appleAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: appleAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedSupplier!.gstin != null)
                            _buildInfoRow(Icons.receipt_long_rounded,
                                'GSTIN: ${_selectedSupplier!.gstin}'),
                          if (_selectedSupplier!.state != null) ...[
                            const SizedBox(height: 4),
                            _buildInfoRow(Icons.location_on_rounded,
                                'State: ${_selectedSupplier!.state}'),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 🍎 INVOICE DETAILS SECTION
            _buildSectionCard(
              title: 'Invoice Details',
              icon: Icons.receipt_rounded,
              color: Colors.purple,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _invoiceNumberController,
                          style: const TextStyle(fontSize: 15, letterSpacing: -0.2),
                          decoration: InputDecoration(
                            labelText: 'Invoice Number *',
                            filled: true,
                            fillColor: appleSubtle,
                            prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: appleAccent, width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _invoiceDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() => _invoiceDate = date);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: appleSubtle,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 18, color: appleSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('dd MMM yyyy').format(_invoiceDate),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: appleText,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _placeOfSupplyController,
                    style: const TextStyle(fontSize: 15, letterSpacing: -0.2),
                    decoration: InputDecoration(
                      labelText: 'Place of Supply',
                      filled: true,
                      fillColor: appleSubtle,
                      prefixIcon: const Icon(Icons.location_on_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: appleAccent, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCheckbox(
                          value: _reverseCharge,
                          title: 'Reverse Charge',
                          subtitle: 'Section 9(3)/(4)',
                          onChanged: (val) =>
                              setState(() => _reverseCharge = val ?? false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCheckbox(
                          value: _itcEligible,
                          title: 'ITC Eligible',
                          subtitle: 'Input Tax Credit',
                          onChanged: (val) =>
                              setState(() => _itcEligible = val ?? true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 🍎 ATTACHMENTS SECTION
            _buildSectionCard(
              title: 'Invoice Attachments',
              icon: Icons.attach_file_rounded,
              color: Colors.orange,
              trailing: TextButton.icon(
                onPressed: _showAttachmentOptions,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: appleAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              child: _attachedFiles.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.attachment_rounded,
                                size: 48, color: appleSecondary.withOpacity(0.5)),
                            const SizedBox(height: 8),
                            Text(
                              'No attachments',
                              style: TextStyle(
                                color: appleSecondary,
                                fontSize: 14,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Add" to attach invoice copy',
                              style: TextStyle(
                                color: appleSecondary.withOpacity(0.7),
                                fontSize: 12,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_attachedFiles.length, (index) {
                        final fileName = _attachedFileNames[index];
                        final isImage =
                            fileName.toLowerCase().endsWith('.jpg') ||
                                fileName.toLowerCase().endsWith('.jpeg') ||
                                fileName.toLowerCase().endsWith('.png');

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: appleSubtle,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: appleDivider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isImage
                                    ? Icons.image_rounded
                                    : Icons.picture_as_pdf_rounded,
                                size: 18,
                                color: isImage ? Colors.blue : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 150),
                                child: Text(
                                  fileName.length > 20
                                      ? '${fileName.substring(0, 20)}...'
                                      : fileName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _attachedFiles.removeAt(index);
                                    _attachedFileNames.removeAt(index);
                                  });
                                },
                                child: const Icon(Icons.close_rounded,
                                    size: 16, color: appleSecondary),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
            ),

            const SizedBox(height: 16),

            // 🍎 ITEMS SECTION - FIXED LAYOUT ISSUE
            _buildSectionCard(
              title: 'Purchase Items',
              icon: Icons.inventory_2_rounded,
              color: Colors.green,
              trailing: SizedBox(
                height: 36, // ✅ FIXED: Add explicit height
                child: ElevatedButton.icon(
                  onPressed: _validateSupplierBeforeAddingItem,
                  icon: const Icon(Icons.add_rounded, size: 16),  // ✅ Smaller icon
                  label: const Text('Add Item', style: TextStyle(fontSize: 14)),  // ✅ Smaller text
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appleAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),  // ✅ Reduced padding
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: Size.zero,  // ✅ CRITICAL: Allows custom sizing
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,  // ✅ No extra padding
                  ),
                ),
              ),
              child: _items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.shopping_cart_outlined,
                                size: 64, color: appleSecondary.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            Text(
                              'No items added',
                              style: TextStyle(
                                color: appleSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap "Add Item" to start',
                              style: TextStyle(
                                color: appleSecondary.withOpacity(0.7),
                                fontSize: 13,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => Divider(
                        color: appleDivider.withOpacity(0.5),
                        height: 1,
                      ),
                      itemBuilder: (_, index) {
                        final item = _items[index];
                        final lineTotal =
                            item.totalCostValue + item.totalTaxAmount;

                        return InkWell(
                          onTap: () => _showAddOrEditItemDialog(
                            editingItem: item,
                            editingIndex: index,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: appleAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_rounded,
                                    color: appleAccent,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: appleText,
                                          letterSpacing: -0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Qty: ${item.quantity} ${item.unit} • ${currency.format(item.costPrice ?? 0)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: appleSecondary,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      currency.format(lineTotal),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: appleText,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded,
                                          color: appleError, size: 20),
                                      onPressed: () {
                                        setState(() => _items.removeAt(index));
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 24),

            // 🍎 TOTAL SECTION
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    appleAccent.withOpacity(0.1),
                    appleAccent.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: appleAccent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Purchase Amount',
                        style: TextStyle(
                          fontSize: 14,
                          color: appleSecondary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Including all taxes',
                        style: TextStyle(
                          fontSize: 12,
                          color: appleSecondary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    currency.format(_totalPurchaseAmount),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: appleAccent,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // 🍎 HELPER WIDGETS
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
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
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: appleText,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Divider(color: appleDivider.withOpacity(0.5), height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: appleAccent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: appleText,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required String title,
    required String subtitle,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value ? appleAccent.withOpacity(0.1) : appleSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? appleAccent.withOpacity(0.5) : appleDivider,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: appleAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: appleText,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: appleSecondary,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // END OF CLASS
}
