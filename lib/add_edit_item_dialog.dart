import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // ✅ Add this to pubspec.yaml
import 'line_item.dart';

double _parseDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

class AddEditItemDialog extends StatefulWidget {
  final LineItem? editingItem;
  final List<Map<String, dynamic>> allProducts;

  const AddEditItemDialog({
    super.key,
    this.editingItem,
    required this.allProducts,
  });

  @override
  State<AddEditItemDialog> createState() => _AddEditItemDialogState();
}

class _AddEditItemDialogState extends State<AddEditItemDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _qtyController;
  late final TextEditingController _discountController;

  String _finalProductName = '';
  String? _selectedProductId;
  double _selectedTaxRate = 0.18;
  double _selectedPrice = 0.0;
  String _selectedHSN = '';
  double _selectedCostPrice = 0.0;
  bool _productSelected = false;

  double _discountPercent = 0;
  double _discountAmount = 0;
  bool _isDiscountPercent = true;

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
    final item = widget.editingItem;

    _qtyController = TextEditingController(
      text: (item?.quantity ?? 1).toString(),
    );

    _discountController = TextEditingController(text: '0');

    if (item != null) {
      _finalProductName = item.name;
      _selectedProductId = item.id;
      _selectedTaxRate = item.taxRate;
      _selectedPrice = item.price;
      _selectedHSN = item.hsnSac ?? '';
      _selectedCostPrice = item.costPrice ?? 0.0;
      _productSelected = true;

      _discountPercent = item.discountPercent;
      _discountAmount = item.discountAmount;
      if (_discountAmount > 0) {
        _isDiscountPercent = false;
        _discountController.text = _discountAmount.toString();
      } else if (_discountPercent > 0) {
        _discountController.text = _discountPercent.toString();
      }
    }

    debugPrint('📦 Dialog received ${widget.allProducts.length} products');
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _fillProductData(Map<String, dynamic> product) {
    setState(() {
      _selectedProductId = product['id']?.toString();
      _finalProductName = (product['name'] ?? '').toString();
      
      _selectedPrice = _parseDouble(product['sellingPrice'] ?? product['price']);
      _selectedCostPrice = _parseDouble(product['costPrice']);
      _selectedHSN = (product['hsnSac'] ?? '').toString();
      
      final cgst = _parseDouble(product['cgst']);
      final sgst = _parseDouble(product['sgst']);
      final igst = _parseDouble(product['igst']);
      
      if (igst > 0) {
        _selectedTaxRate = igst / 100;
      } else if (cgst > 0 || sgst > 0) {
        _selectedTaxRate = (cgst + sgst) / 100;
      } else {
        _selectedTaxRate = 0.18;
      }
      
      _productSelected = true;
      
      debugPrint('✅ Auto-filled: $_finalProductName');
      debugPrint('   💰 Selling Price: ₹$_selectedPrice');
      debugPrint('   📊 Tax Rate: ${(_selectedTaxRate * 100)}%');
    });
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
      // Search for product by barcode
      final product = widget.allProducts.firstWhere(
        (p) => (p['barcode'] ?? '').toString() == result,
        orElse: () => {},
      );

      if (product.isNotEmpty) {
        _fillProductData(product);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product found: ${product['name']}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No product found with this barcode'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  double get _calculatedDiscount {
    final qty = _parseDouble(_qtyController.text);
    final subtotal = _selectedPrice * qty;
    
    if (_isDiscountPercent) {
      return subtotal * (_discountPercent / 100);
    } else {
      return _discountAmount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingItem != null;

    final qty = _parseDouble(_qtyController.text);
    final subtotal = _selectedPrice * qty;
    final discountValue = _calculatedDiscount;
    final afterDiscount = subtotal - discountValue;
    
    final taxableValue = afterDiscount / (1 + _selectedTaxRate);
    final taxAmount = afterDiscount - taxableValue;
    final lineTotal = afterDiscount;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                          isEditing ? Icons.edit_outlined : Icons.add_rounded,
                          color: appleAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEditing ? 'Edit Item' : 'Add Item',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: appleText,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
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
                          // Product Selection
                          if (!isEditing) ...[
                            Autocomplete<Map<String, dynamic>>(
                              displayStringForOption: (p) => (p['name'] ?? '').toString(),
                              optionsBuilder: (TextEditingValue text) {
                                if (text.text.trim().isEmpty) {
                                  return const Iterable<Map<String, dynamic>>.empty();
                                }
                                final query = text.text.trim().toLowerCase();
                                return widget.allProducts.where((p) {
                                  final name = (p['name'] ?? '').toString().toLowerCase();
                                  final barcode = (p['barcode'] ?? '').toString().toLowerCase();
                                  return name.contains(query) || barcode.contains(query);
                                }).toList();
                              },
                              onSelected: _fillProductData,
                              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Product/Service Name *',
                                    hintText: 'Start typing to search...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.inventory_rounded),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.qr_code_scanner_rounded),
                                      onPressed: _scanBarcode,
                                      tooltip: 'Scan Barcode',
                                      color: appleAccent,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (!_productSelected) {
                                      return 'Please select a product';
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => onSubmit(),
                                 );
                              },
                            ),
                            const SizedBox(height: 16),  // ✅ This is fine
                          ] else ...[
                            TextFormField(
                              initialValue: _finalProductName,
                              decoration: InputDecoration(
                                labelText: 'Product/Service Name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.inventory_rounded),
                                filled: true,
                                fillColor: appleSubtle,
                              ),
                              enabled: false,
                              style: const TextStyle(
                                color: appleText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // HSN/SAC
                          TextFormField(
                            initialValue: _selectedHSN,
                            decoration: InputDecoration(
                              labelText: 'HSN/SAC',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.tag_rounded),
                              suffixIcon: const Icon(Icons.lock_outline, size: 18),
                              helperText: 'Edit in Products screen',
                              helperStyle: TextStyle(
                                fontSize: 11,
                                color: appleSecondary,
                              ),
                              filled: true,
                              fillColor: appleSubtle,
                            ),
                            enabled: false,
                            style: const TextStyle(color: appleText),
                          ),
                          
                          const SizedBox(height: 16),

                          // Quantity
                          TextFormField(
                            controller: _qtyController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Quantity *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.production_quantity_limits_rounded),
                              suffixIcon: Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              helperText: 'Editable field',
                              helperStyle: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                            autofocus: isEditing,
                            validator: (v) => (_parseDouble(v) <= 0) 
                                ? 'Enter positive quantity' 
                                : null,
                            onChanged: (_) => setState(() {}),
                          ),
                          
                          const SizedBox(height: 16),

                          // Selling Price
                          TextFormField(
                            initialValue: _selectedPrice.toStringAsFixed(2),
                            decoration: InputDecoration(
                              labelText: 'Selling Price (incl. GST)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.currency_rupee_rounded),
                              suffixIcon: const Icon(Icons.lock_outline, size: 18),
                              helperText: 'Edit in Products screen',
                              helperStyle: TextStyle(
                                fontSize: 11,
                                color: appleSecondary,
                              ),
                              filled: true,
                              fillColor: appleSubtle,
                            ),
                            enabled: false,
                            style: const TextStyle(
                              color: appleText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 24),
                          Divider(color: appleDivider.withOpacity(0.5)),
                          const SizedBox(height: 16),

                          // Discount Section
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.discount_rounded,
                                  size: 18,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Discount (Optional)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: appleText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _discountController,
                                  decoration: InputDecoration(
                                    labelText: _isDiscountPercent ? 'Discount %' : 'Discount ₹',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: Icon(
                                      _isDiscountPercent ? Icons.percent : Icons.currency_rupee_rounded,
                                      color: Colors.orange,
                                    ),
                                    hintText: '0',
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      final parsed = _parseDouble(value);
                                      if (_isDiscountPercent) {
                                        _discountPercent = parsed > 100 ? 100 : parsed;
                                        _discountAmount = 0;
                                      } else {
                                        _discountAmount = parsed;
                                        _discountPercent = 0;
                                      }
                                    });
                                  },
                                  validator: (v) {
                                    final val = _parseDouble(v);
                                    if (_isDiscountPercent && val > 100) {
                                      return 'Max 100%';
                                    }
                                    if (!_isDiscountPercent && val > subtotal) {
                                      return 'Exceeds subtotal';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.orange),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    _buildDiscountToggle('%', _isDiscountPercent, true),
                                    _buildDiscountToggle('₹', !_isDiscountPercent, false),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (discountValue > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Discount Applied:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '- ₹${discountValue.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),
                          Divider(color: appleDivider.withOpacity(0.5)),
                          const SizedBox(height: 16),

                          // Price Breakdown
                          if (_selectedPrice > 0 && _productSelected)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    appleAccent.withOpacity(0.05),
                                    appleAccent.withOpacity(0.15),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: appleAccent.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calculate_rounded,
                                        size: 18,
                                        color: appleAccent,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Price Breakdown',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: appleText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Divider(height: 20, color: appleAccent.withOpacity(0.2)),
                                  
                                  if (qty > 1)
                                    _buildBreakdownRow(
                                      'Subtotal (${qty.toStringAsFixed(1)} × ₹${_selectedPrice.toStringAsFixed(2)})',
                                      subtotal,
                                    ),
                                  
                                  if (discountValue > 0) ...[
                                    const SizedBox(height: 8),
                                    _buildBreakdownRow('Discount', -discountValue, color: Colors.orange.shade700),
                                    Divider(height: 16, color: appleAccent.withOpacity(0.2)),
                                    _buildBreakdownRow('After Discount', afterDiscount, isBold: true),
                                    const SizedBox(height: 8),
                                  ],
                                  
                                  _buildBreakdownRow('Taxable Value', taxableValue),
                                  const SizedBox(height: 8),
                                  _buildBreakdownRow(
                                    'GST (${(_selectedTaxRate * 100).toStringAsFixed(0)}%)',
                                    taxAmount,
                                    color: Colors.orange.shade700,
                                  ),
                                  Divider(height: 16, color: appleAccent.withOpacity(0.2)),
                                  
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: _buildBreakdownRow(
                                      'Line Total',
                                      lineTotal,
                                      isBold: true,
                                      color: Colors.green.shade700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Help Text
                          if (!_productSelected && !isEditing) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline_rounded,
                                    size: 20,
                                    color: Colors.amber.shade700,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Tip: Search or scan barcode to select a product. You can adjust quantity and add discount.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                          onPressed: () => Navigator.pop(context),
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
                          onPressed: () {
                            if (!_formKey.currentState!.validate()) return;

                            if (!_productSelected) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a product first'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            final item = LineItem(
                              id: _selectedProductId,
                              name: _finalProductName,
                              quantity: _parseDouble(_qtyController.text),
                              price: _selectedPrice,
                              taxRate: _selectedTaxRate,
                              hsnSac: _selectedHSN.isEmpty ? null : _selectedHSN,
                              costPrice: _selectedCostPrice > 0 ? _selectedCostPrice : null,
                              discountPercent: _discountPercent,
                              discountAmount: _discountAmount,
                            );

                            Navigator.pop(context, item);
                          },
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
                            isEditing ? 'Update' : 'Add',
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

  Widget _buildDiscountToggle(String label, bool isSelected, bool isPercent) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _isDiscountPercent = isPercent;
            _discountController.text = '0';
            _discountPercent = 0;
            _discountAmount = 0;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : Colors.orange,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    double value, {
    bool isBold = false,
    Color? color,
    double fontSize = 13,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              color: color ?? appleSecondary,
            ),
          ),
        ),
        Text(
          '₹${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color ?? appleText,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

// ✅ NEW: Barcode Scanner Screen
// ✅ FIXED: Barcode Scanner Screen
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
          
          // Overlay with scanning guide
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
          
          // Instructions
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

