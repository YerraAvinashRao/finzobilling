import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:finzobilling/models/product_model.dart';
import 'package:finzobilling/services/audit_service.dart';
import 'package:finzobilling/services/analytics_service.dart';

class AddEditProductDialog extends StatefulWidget {
  final ProductModel? product;

  const AddEditProductDialog({super.key, this.product});

  @override
  State<AddEditProductDialog> createState() => _AddEditProductDialogState();
}

class _AddEditProductDialogState extends State<AddEditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _hsnController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _openingStockController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'General';
  String _selectedUnit = 'Pcs';
  double _selectedGSTRate = 18.0;
  bool _trackInventory = true;
  bool _isActive = true;
  bool _isLoading = false;

  // 🍎 Apple iOS Premium Colors
  static const Color appleBackground = Color(0xFFFBFBFD);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleText = Color(0xFF1D1D1F);
  static const Color appleSecondary = Color(0xFF86868B);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleDivider = Color(0xFFD2D2D7);
  static const Color appleSubtle = Color(0xFFF5F5F7);

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _loadProductData();
    }
  }

  void _loadProductData() {
    final p = widget.product!;
    _nameController.text = p.name;
    _skuController.text = p.sku ?? '';
    _barcodeController.text = p.barcode ?? '';
    _hsnController.text = p.hsnCode ?? '';
    _sellingPriceController.text = p.sellingPrice.toString();
    _purchasePriceController.text = p.purchasePrice?.toString() ?? '';
    _mrpController.text = p.mrp?.toString() ?? '';
    _openingStockController.text = p.openingStock?.toString() ?? '';
    _reorderLevelController.text = p.reorderLevel?.toString() ?? '';
    _descriptionController.text = p.description ?? '';
    _selectedCategory = p.category;
    _selectedUnit = p.unit;
    _selectedGSTRate = p.gstRate;
    _trackInventory = p.trackInventory;
    _isActive = p.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _hsnController.dispose();
    _sellingPriceController.dispose();
    _purchasePriceController.dispose();
    _mrpController.dispose();
    _openingStockController.dispose();
    _reorderLevelController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ✅ NEW: Barcode Scanner
  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => _BarcodeScannerScreen(),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _barcodeController.text = result;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barcode scanned: $result'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showInfoDialog(String title, String content, {List<String>? examples}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: appleAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.info_outline, color: appleAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: appleText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                content,
                style: TextStyle(
                  fontSize: 14,
                  color: appleSecondary,
                  height: 1.5,
                ),
              ),
              if (examples != null && examples.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Examples:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: appleText,
                  ),
                ),
                const SizedBox(height: 8),
                ...examples.map((ex) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontSize: 16)),
                          Expanded(
                            child: Text(
                              ex,
                              style: TextStyle(
                                fontSize: 13,
                                color: appleSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showHSNLookup() async {
    final selectedHSN = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const HSNLookupDialog(),
    );

    if (selectedHSN != null) {
      setState(() {
        _hsnController.text = selectedHSN['code']!;
        final gstRate = selectedHSN['gst'];
        if (gstRate != null) {
          _selectedGSTRate = double.parse(gstRate);
        }
      });
    }
  }

  double _calculateProfitMargin() {
    final purchase = double.tryParse(_purchasePriceController.text) ?? 0;
    final selling = double.tryParse(_sellingPriceController.text) ?? 0;
    if (purchase > 0 && selling > 0) {
      return ((selling - purchase) / purchase * 100);
    }
    return 0;
  }
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final now = Timestamp.now();

      final productData = {
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
        'sku': _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
        'barcode': _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        'hsnSac': _hsnController.text.trim().isEmpty ? null : _hsnController.text.trim(),
        'unit': _selectedUnit,
        'sellingPrice': double.parse(_sellingPriceController.text),
        'purchasePrice': _purchasePriceController.text.isEmpty ? null : double.parse(_purchasePriceController.text),
        'mrp': _mrpController.text.isEmpty ? null : double.parse(_mrpController.text),
        'gstRate': _selectedGSTRate,
        'cgst': _selectedGSTRate / 2,
        'sgst': _selectedGSTRate / 2,
        'igst': _selectedGSTRate,
        'trackInventory': _trackInventory,
        'reorderLevel': _reorderLevelController.text.isEmpty ? 10 : int.parse(_reorderLevelController.text),
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'isActive': _isActive,
        'updatedAt': now,
      };

      if (widget.product == null) {
        productData['currentStock'] = _openingStockController.text.isEmpty ? 0 : double.parse(_openingStockController.text);
        productData['openingStock'] = _openingStockController.text.isEmpty ? 0 : double.parse(_openingStockController.text);
        productData['createdAt'] = now;
        productData['createdBy'] = user.email;

        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('products')
            .add(productData);

        await AuditService().logAction(
          entityType: 'product',
          entityId: docRef.id,
          action: 'CREATE',
          afterData: productData,
          reason: 'Product created',
        );

        await AnalyticsService().logProductCreated(productId: docRef.id);
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('products')
            .doc(widget.product!.id)
            .update(productData);

        await AuditService().logAction(
          entityType: 'product',
          entityId: widget.product!.id,
          action: 'UPDATE',
          afterData: productData,
          reason: 'Product updated',
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.product == null ? 'Product created!' : 'Product updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
              maxWidth: 600,
            ),
            decoration: BoxDecoration(
              color: appleCard.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: appleDivider.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: appleDivider.withOpacity(0.5),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: appleAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_outlined : Icons.add_box_outlined,
                          color: appleAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEditing ? 'Edit Product' : 'Add Product',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: appleText,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: appleAccent,
                          ),
                        )
                      else
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: appleSecondary,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Name
                          _buildSectionHeader('Basic Information', Icons.info_outline),
                          const SizedBox(height: 12),
                          
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Product/Service Name *',
                              hintText: 'e.g., iPhone 15 Pro',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.inventory_rounded),
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),

                          const SizedBox(height: 16),

                          // Category & Unit - FIXED OVERFLOW
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedCategory,
                                  decoration: InputDecoration(
                                    labelText: 'Category *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.category_rounded),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16), // ✅ ADD THIS
                                  ),
                                  isExpanded: true, // ✅ ADD THIS
                                  items: ProductCategories.all.map((cat) {
                                    return DropdownMenuItem(
                                      value: cat,
                                      child: Text(
                                        cat,
                                        overflow: TextOverflow.ellipsis, // ✅ ADD THIS
                                        maxLines: 1, // ✅ ADD THIS
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedCategory = val!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedUnit,
                                  decoration: InputDecoration(
                                    labelText: 'Unit *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.straighten_rounded),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16), // ✅ ADD THIS
                                  ),
                                  isExpanded: true, // ✅ ADD THIS
                                  items: ['Pcs', 'Kg', 'Ltr', 'Box', 'Set', 'Service'].map((unit) {
                                    return DropdownMenuItem(
                                      value: unit,
                                      child: Text(
                                        unit,
                                        overflow: TextOverflow.ellipsis, // ✅ ADD THIS
                                        maxLines: 1, // ✅ ADD THIS
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedUnit = val!),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          Divider(color: appleDivider.withOpacity(0.5)),
                          const SizedBox(height: 16),

                          // Identification
                          _buildSectionHeader('Identification', Icons.qr_code_rounded),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _skuController,
                                  decoration: InputDecoration(
                                    labelText: 'SKU',
                                    hintText: 'Stock Keeping Unit',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.tag_rounded),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.help_outline, size: 18),
                                      onPressed: () => _showInfoDialog(
                                        'SKU (Stock Keeping Unit)',
                                        'A unique code to identify and track your products in inventory.',
                                        examples: ['PHONE-001', 'SHIRT-M-BLUE', 'LAPTOP-HP-15'],
                                      ),
                                    ),
                                  ),
                                  textCapitalization: TextCapitalization.characters,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _barcodeController,
                                  decoration: InputDecoration(
                                    labelText: 'Barcode',
                                    hintText: 'Scan or enter',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.qr_code_2_rounded),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.qr_code_scanner_rounded),
                                      onPressed: _scanBarcode,
                                      tooltip: 'Scan Barcode',
                                      color: appleAccent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // HSN/SAC
                          TextFormField(
                            controller: _hsnController,
                            decoration: InputDecoration(
                              labelText: 'HSN/SAC Code',
                              hintText: 'For GST compliance',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.numbers_rounded),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.search, size: 20),
                                    onPressed: _showHSNLookup,
                                    tooltip: 'Lookup HSN',
                                    color: appleAccent,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.help_outline, size: 18),
                                    onPressed: () => _showInfoDialog(
                                      'HSN/SAC Code',
                                      'Harmonized System of Nomenclature (HSN) for goods or Service Accounting Code (SAC) for services.',
                                      examples: ['8517 - Mobile phones', '9973 - Consulting services'],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                          Divider(color: appleDivider.withOpacity(0.5)),
                          const SizedBox(height: 16),

                          // Pricing
                          _buildSectionHeader('Pricing', Icons.currency_rupee_rounded),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _sellingPriceController,
                                  decoration: InputDecoration(
                                    labelText: 'Selling Price *',
                                    hintText: '0.00',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.sell_rounded),
                                    prefixText: '₹ ',
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) {
                                    final val = double.tryParse(v ?? '');
                                    if (val == null || val <= 0) return 'Required';
                                    return null;
                                  },
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _purchasePriceController,
                                  decoration: InputDecoration(
                                    labelText: 'Purchase Price',
                                    hintText: '0.00',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.shopping_cart_rounded),
                                    prefixText: '₹ ',
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _mrpController,
                            decoration: InputDecoration(
                              labelText: 'MRP (Maximum Retail Price)',
                              hintText: '0.00',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.local_offer_rounded),
                              prefixText: '₹ ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),

                          // Profit Margin Display
                          if (_calculateProfitMargin() > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green.shade50,
                                    Colors.green.shade100.withOpacity(0.3),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.trending_up_rounded, color: Colors.green.shade700, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Profit Margin',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${_calculateProfitMargin().toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),
                          Divider(color: appleDivider.withOpacity(0.5)),
                          const SizedBox(height: 16),

                          // GST
                          _buildSectionHeader('GST & Tax', Icons.receipt_rounded),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<double>(
                            initialValue: _selectedGSTRate,
                            decoration: InputDecoration(
                              labelText: 'GST Rate *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.percent_rounded),
                            ),
                            items: [0.0, 0.25, 3.0, 5.0, 12.0, 18.0, 28.0].map((rate) {
                              return DropdownMenuItem(
                                value: rate,
                                child: Text('${rate.toStringAsFixed(rate == 0.25 ? 2 : 0)}%'),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedGSTRate = val!),
                          ),

                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: appleSubtle,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _buildTaxBreakdownRow('CGST', _selectedGSTRate / 2),
                                const SizedBox(height: 6),
                                _buildTaxBreakdownRow('SGST', _selectedGSTRate / 2),
                                const SizedBox(height: 6),
                                _buildTaxBreakdownRow('IGST', _selectedGSTRate),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                          Divider(color: appleDivider.withOpacity(0.5)),
                          const SizedBox(height: 16),

                          // Inventory
                          _buildSectionHeader('Inventory', Icons.warehouse_rounded),
                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: appleSubtle,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Track Inventory',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: appleText,
                                  ),
                                ),
                                Switch(
                                  value: _trackInventory,
                                  onChanged: (val) => setState(() => _trackInventory = val),
                                  activeThumbColor: appleAccent,
                                ),
                              ],
                            ),
                          ),

                          if (_trackInventory) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                if (!isEditing)
                                  Expanded(
                                    child: TextFormField(
                                      controller: _openingStockController,
                                      decoration: InputDecoration(
                                        labelText: 'Opening Stock',
                                        hintText: '0',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        prefixIcon: const Icon(Icons.inventory_2_rounded),
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ),
                                if (!isEditing) const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _reorderLevelController,
                                    decoration: InputDecoration(
                                      labelText: 'Reorder Level',
                                      hintText: '10',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(Icons.notification_important_rounded),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 24),
                          Divider(color: appleDivider.withOpacity(0.5)),
                          const SizedBox(height: 16),

                          // Description & Status
                          _buildSectionHeader('Additional Details', Icons.description_outlined),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              hintText: 'Product details, specifications, etc.',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              // ✅ alignedLabel removed
                            ),
                            maxLines: 3,
                          ),

                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isActive ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isActive ? Colors.green.shade300 : Colors.red.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
                                      color: _isActive ? Colors.green.shade700 : Colors.red.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Product Status',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: _isActive ? Colors.green.shade700 : Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _isActive,
                                  onChanged: (val) => setState(() => _isActive = val),
                                  activeThumbColor: Colors.green,
                                  inactiveThumbColor: Colors.red,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Footer Actions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: appleDivider.withOpacity(0.5),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appleSubtle,
                            foregroundColor: appleText,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            isEditing ? 'Update' : 'Save',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: appleAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: appleAccent),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: appleText,
          ),
        ),
      ],
    );
  }

  Widget _buildTaxBreakdownRow(String label, double rate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: appleSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 2)}%',
          style: const TextStyle(
            fontSize: 13,
            color: appleText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Barcode Scanner Screen (same as before)
class _BarcodeScannerScreen extends StatefulWidget {
  @override
  State<_BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<_BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanned = false;
  bool _isTorchOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.yellow : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
              cameraController.toggleTorch();
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_isScanned) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  setState(() {
                    _isScanned = true;
                  });
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),
          
          Center(
            child: Container(
              width: 300,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Position the barcode within the frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  backgroundColor: Colors.black.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

// HSN Lookup Dialog (simplified version - you can expand this)
class HSNLookupDialog extends StatelessWidget {
  const HSNLookupDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final commonHSN = [
      {'code': '8517', 'desc': 'Mobile phones', 'gst': '12'},
      {'code': '8471', 'desc': 'Laptops/Computers', 'gst': '18'},
      {'code': '9973', 'desc': 'Consulting services', 'gst': '18'},
      {'code': '6203', 'desc': 'Men\'s clothing', 'gst': '12'},
      {'code': '2401', 'desc': 'Food items', 'gst': '5'},
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Common HSN Codes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...commonHSN.map((hsn) => ListTile(
                  title: Text('${hsn['code']} - ${hsn['desc']}'),
                  subtitle: Text('GST: ${hsn['gst']}%'),
                  onTap: () => Navigator.pop(context, hsn),
                )),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
