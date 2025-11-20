import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'new_purchase_screen.dart';

// 🍎 Apple iOS Premium Colors
const Color appleBackground = Color(0xFFFBFBFD);
const Color appleCard = Color(0xFFFFFFFF);
const Color appleText = Color(0xFF1D1D1F);
const Color appleSecondary = Color(0xFF86868B);
const Color appleAccent = Color(0xFF007AFF);
const Color appleDivider = Color(0xFFD2D2D7);
const Color appleSubtle = Color(0xFFF5F5F7);

double parseDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

class ProductCategories {
  static const List<String> all = [
    'Electronics', 'Clothing', 'Food & Beverages', 'Home & Kitchen',
    'Beauty & Health', 'Sports & Fitness', 'Books & Stationery',
    'Toys & Games', 'Automotive', 'Furniture', 'Groceries',
    'Medical', 'Services', 'Other',
  ];
}

class ProductUnits {
  static const List<String> all = [
    'Pcs', 'Kg', 'Ltr', 'Box', 'Dozen', 'Meter', 'Feet',
    'Gram', 'Ton', 'Carton', 'Pack', 'Bundle', 'Roll', 'Set',
  ];
}

class GSTRates {
  static const List<double> all = [0, 0.25, 3, 5, 12, 18, 28];
}

class AddEditPurchaseItemDialog extends StatefulWidget {
  final PurchaseLineItem? editingItem;
  final List<Map<String, dynamic>> allProducts;
  final String? supplierState;
  final String? supplierGSTIN;

  const AddEditPurchaseItemDialog({
    super.key,
    this.editingItem,
    required this.allProducts,
    this.supplierState,
    this.supplierGSTIN,
  });

  @override
  State<AddEditPurchaseItemDialog> createState() => _AddEditPurchaseItemDialogState();
}

class _AddEditPurchaseItemDialogState extends State<AddEditPurchaseItemDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _barcodeController;
  late TextEditingController _hsnController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _mrpController;
  late TextEditingController _quantityController;
  late TextEditingController _reorderLevelController;
  late TextEditingController _descriptionController;
  
  String? _selectedProductId;
  String _selectedCategory = 'Other';
  String _selectedUnit = 'Pcs';
  double _selectedGSTRate = 18.0;
  
  bool _isInterState = false;
  double _cgst = 9.0;
  double _sgst = 9.0;
  double _igst = 0.0;
  bool _isSaving = false;
  
  String? _businessState;
  String? _businessGSTIN;

  @override
  void initState() {
    super.initState();
    
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔍 DIALOG OPENED');
    debugPrint('🔍 Supplier State: "${widget.supplierState}"');
    debugPrint('🔍 Supplier GSTIN: ${widget.supplierGSTIN}');
    debugPrint('═══════════════════════════════════════');
    
    final item = widget.editingItem;
    _selectedProductId = item?.id;
    _nameController = TextEditingController(text: item?.name ?? '');
    _skuController = TextEditingController();
    _barcodeController = TextEditingController();
    _hsnController = TextEditingController(text: item?.hsnSac ?? '');
    _sellingPriceController = TextEditingController(text: item?.price.toString() ?? '');
    _purchasePriceController = TextEditingController(text: item?.costPrice?.toString() ?? '');
    _mrpController = TextEditingController();
    _quantityController = TextEditingController(text: item?.quantity.toString() ?? '1');
    _reorderLevelController = TextEditingController();
    _descriptionController = TextEditingController();
    _selectedUnit = item?.unit ?? 'Pcs';
    _selectedCategory = 'Other';
    
    if (item != null) {
      _selectedGSTRate = item.cgst + item.sgst + item.igst;
      _cgst = item.cgst;
      _sgst = item.sgst;
      _igst = item.igst;
      _isInterState = item.igst > 0;
    }
    
    _loadBusinessDetails();
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
    _quantityController.dispose();
    _reorderLevelController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in');
        return;
      }

      // ✅ Read from settings/business_details sub-document
      final businessDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('business_details')
          .get();

      if (businessDoc.exists && mounted) {
        final data = businessDoc.data();
        
        setState(() {
          _businessGSTIN = data?['gstin'];
          _businessState = data?['state'];
        });
        
        debugPrint('✅ Business GSTIN: $_businessGSTIN');
        debugPrint('✅ Business State: $_businessState');
        debugPrint('✅ State Code: ${data?['stateCode']}');
        
        _determineInterState();
      } else {
        debugPrint('❌ business_details document not found');
      }
    } catch (e) {
      debugPrint('❌ Error loading business details: $e');
    }
  }


  String? _extractStateCodeFromGSTIN(String? gstin) {
    if (gstin == null || gstin.isEmpty) return null;
    final cleaned = gstin.trim();
    if (cleaned.length < 2) return null;
    return cleaned.substring(0, 2);
  }

  String? _getStateFromCode(String? code) {
    if (code == null) return null;
    
    final Map<String, String> stateCodeMap = {
      '01': 'Jammu and Kashmir', '02': 'Himachal Pradesh', '03': 'Punjab',
      '04': 'Chandigarh', '05': 'Uttarakhand', '06': 'Haryana', '07': 'Delhi',
      '08': 'Rajasthan', '09': 'Uttar Pradesh', '10': 'Bihar', '11': 'Sikkim',
      '12': 'Arunachal Pradesh', '13': 'Nagaland', '14': 'Manipur',
      '15': 'Mizoram', '16': 'Tripura', '17': 'Meghalaya', '18': 'Assam',
      '19': 'West Bengal', '20': 'Jharkhand', '21': 'Odisha',
      '22': 'Chhattisgarh', '23': 'Madhya Pradesh', '24': 'Gujarat',
      '27': 'Maharashtra', '29': 'Karnataka', '30': 'Goa', '32': 'Kerala',
      '33': 'Tamil Nadu', '34': 'Puducherry',
      '35': 'Andaman and Nicobar Islands', '36': 'Telangana',
      '37': 'Andhra Pradesh',
    };
    
    return stateCodeMap[code];
  }

  void _determineInterState() {
    String? businessStateResolved;
    
    if (_businessGSTIN != null && _businessGSTIN!.isNotEmpty) {
      final businessCode = _extractStateCodeFromGSTIN(_businessGSTIN);
      businessStateResolved = _getStateFromCode(businessCode);
      debugPrint('🔍 Business state from GSTIN: $businessStateResolved (code: $businessCode)');
    }
    
    if (businessStateResolved == null || businessStateResolved.isEmpty) {
      businessStateResolved = _businessState;
      debugPrint('🔍 Business state from settings: $businessStateResolved');
    }

    String? supplierStateResolved;
    
    if (widget.supplierGSTIN != null && widget.supplierGSTIN!.isNotEmpty) {
      final supplierCode = _extractStateCodeFromGSTIN(widget.supplierGSTIN);
      supplierStateResolved = _getStateFromCode(supplierCode);
      debugPrint('🔍 Supplier state from GSTIN: $supplierStateResolved (code: $supplierCode)');
    }
    
    if (supplierStateResolved == null || supplierStateResolved.isEmpty) {
      supplierStateResolved = widget.supplierState;
      debugPrint('🔍 Supplier state from field: $supplierStateResolved');
    }

    if (businessStateResolved == null || supplierStateResolved == null) {
      if (mounted) {
        setState(() => _isInterState = false);
      }
      debugPrint('⚠️ Missing state info - defaulting to INTRA-STATE');
      _updateGSTSplit();
      return;
    }

    final businessTrimmed = businessStateResolved.trim().toLowerCase();
    final supplierTrimmed = supplierStateResolved.trim().toLowerCase();
    
    if (mounted) {
      setState(() {
        _isInterState = (businessTrimmed != supplierTrimmed);
      });
    }
    
    debugPrint('🔍 Final Comparison: "$supplierTrimmed" vs "$businessTrimmed"');
    debugPrint('🔍 Is Inter-State? $_isInterState');
    
    _updateGSTSplit();
  }

  void _updateGSTSplit() {
    if (mounted) {
      setState(() {
        if (_isInterState) {
          _cgst = 0.0;
          _sgst = 0.0;
          _igst = _selectedGSTRate;
        } else {
          _cgst = _selectedGSTRate / 2;
          _sgst = _selectedGSTRate / 2;
          _igst = 0.0;
        }
      });
    }
    
    debugPrint('📊 GST Split - CGST: $_cgst%, SGST: $_sgst%, IGST: $_igst%');
  }

  void _safePop([dynamic result]) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, result);
      }
    });
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Scan Barcode'),
            backgroundColor: appleAccent,
          ),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && mounted) {
                _safePop(barcodes.first.rawValue);
              }
            },
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      _barcodeController.text = result;
      _searchProductByBarcode(result);
    }
  }

  void _searchProductByBarcode(String barcode) {
    final product = widget.allProducts.firstWhere(
      (p) => p['barcode']?.toString() == barcode,
      orElse: () => {},
    );

    if (product.isNotEmpty) {
      _selectProduct(product);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Product found: ${product['name']}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _selectProduct(Map<String, dynamic> product) {
    setState(() {
      _selectedProductId = product['id'];
      _nameController.text = product['name'] ?? '';
      _skuController.text = product['sku'] ?? '';
      _barcodeController.text = product['barcode'] ?? '';
      _sellingPriceController.text = (product['sellingPrice'] ?? 0).toString();
      _purchasePriceController.text = (product['purchasePrice'] ?? product['costPrice'] ?? 0).toString();
      _mrpController.text = (product['mrp'] ?? 0).toString();
      _hsnController.text = product['hsnSac'] ?? '';
      _reorderLevelController.text = (product['reorderLevel'] ?? 0).toString();
      _descriptionController.text = product['description'] ?? '';
      _selectedUnit = product['unit'] ?? 'Pcs';
      _selectedCategory = product['category'] ?? 'Other';
      
      final gstRate = parseDouble(product['cgst'] ?? 0) * 2;
      _selectedGSTRate = gstRate > 0 ? gstRate : 18.0;
      _updateGSTSplit();
    });
  }

  void _showHSNLookup() {
    final Map<String, String> hsnCodes = {
      '0401': 'Milk and cream', '0701': 'Potatoes', '0702': 'Tomatoes',
      '0901': 'Coffee', '0902': 'Tea', '1006': 'Rice', '1701': 'Sugar',
      '1905': 'Bread, biscuits', '2523': 'Cement', '3004': 'Medicines',
      '4011': 'Tyres', '6109': 'T-shirts', '6402': 'Footwear',
      '8471': 'Computers', '8517': 'Mobile phones', '8703': 'Motor cars',
      '9403': 'Furniture',
    };

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: appleAccent.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.numbers, color: appleAccent),
                    const SizedBox(width: 12),
                    const Text('HSN Lookup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: hsnCodes.length,
                  itemBuilder: (context, index) {
                    final code = hsnCodes.keys.elementAt(index);
                    final description = hsnCodes[code]!;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: appleSubtle,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(code, style: const TextStyle(fontWeight: FontWeight.w700, color: appleAccent)),
                      ),
                      title: Text(description),
                      onTap: () {
                        setState(() => _hsnController.text = code);
                        Navigator.pop(dialogContext);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveItem() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final newItem = PurchaseLineItem(
      id: _selectedProductId,
      name: _nameController.text.trim(),
      quantity: double.parse(_quantityController.text),
      price: double.parse(_sellingPriceController.text),
      costPrice: double.tryParse(_purchasePriceController.text),
      cgst: _cgst,
      sgst: _sgst,
      igst: _igst,
      unit: _selectedUnit,
      hsnSac: _hsnController.text.trim().isEmpty ? null : _hsnController.text.trim(),
    );

    _safePop(newItem);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
              maxWidth: 600,
            ),
            decoration: BoxDecoration(
              color: appleBackground,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [appleAccent.withOpacity(0.1), appleBackground],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: appleAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_shopping_cart, color: appleAccent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.editingItem != null ? 'Edit Purchase Item' : 'Add Purchase Item',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: appleText,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: appleText),
                        onPressed: () => _safePop(),
                      ),
                    ],
                  ),
                ),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isInterState ? Colors.orange.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isInterState ? Colors.orange.shade200 : Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(_isInterState ? Icons.public : Icons.home_work, 
                        color: _isInterState ? Colors.orange : Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isInterState 
                              ? 'Inter-State (IGST $_selectedGSTRate%)'
                              : 'Intra-State (CGST+SGST $_selectedGSTRate%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isInterState ? Colors.orange.shade900 : Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Basic Information', Icons.info_outline_rounded),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _nameController,
                            decoration: _inputDecoration('Product Name *', 'Enter product name', Icons.shopping_bag_rounded),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _skuController,
                                  decoration: _inputDecoration('SKU/Code', 'Optional', Icons.qr_code_2_rounded),
                                  textCapitalization: TextCapitalization.characters,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _barcodeController,
                                  decoration: _inputDecoration('Barcode', 'Optional', Icons.barcode_reader),
                                ),
                              ),
                              IconButton.filled(
                                onPressed: _scanBarcode,
                                icon: const Icon(Icons.qr_code_scanner, size: 20),
                                style: IconButton.styleFrom(backgroundColor: appleAccent, foregroundColor: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedCategory,
                                  decoration: _inputDecoration('Category *', '', Icons.category_rounded),
                                  isExpanded: true,
                                  items: ProductCategories.all.map((cat) {
                                    return DropdownMenuItem(value: cat, child: Text(cat, overflow: TextOverflow.ellipsis, maxLines: 1));
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedCategory = val!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedUnit,
                                  decoration: _inputDecoration('Unit *', '', Icons.straighten_rounded),
                                  isExpanded: true,
                                  items: ProductUnits.all.map((unit) {
                                    return DropdownMenuItem(value: unit, child: Text(unit, overflow: TextOverflow.ellipsis, maxLines: 1));
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedUnit = val!),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          _buildSectionHeader('Purchase Details', Icons.shopping_cart_rounded),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _quantityController,
                            decoration: _inputDecoration('Purchase Quantity *', '1.0', Icons.format_list_numbered_rounded),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              final qty = double.tryParse(v);
                              if (qty == null || qty <= 0) return 'Must be > 0';
                              return null;
                            },
                          ),

                          const SizedBox(height: 24),
                          _buildSectionHeader('Pricing', Icons.currency_rupee_rounded),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _purchasePriceController,
                            decoration: _inputDecoration('Purchase Price *', 'Cost from supplier', Icons.account_balance_wallet_rounded).copyWith(
                              prefixText: '₹ ',
                              helperText: 'Excluding GST',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              final price = double.tryParse(v);
                              if (price == null || price <= 0) return 'Must be > 0';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _sellingPriceController,
                            decoration: _inputDecoration('Selling Price *', 'Your selling price', Icons.sell_rounded).copyWith(
                              prefixText: '₹ ',
                              helperText: 'Excluding GST',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              final price = double.tryParse(v);
                              if (price == null || price <= 0) return 'Must be > 0';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _mrpController,
                            decoration: _inputDecoration('MRP', 'Maximum Retail Price', Icons.local_offer_rounded).copyWith(prefixText: '₹ '),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                          ),

                          const SizedBox(height: 24),
                          _buildSectionHeader('Tax & Compliance', Icons.account_balance_rounded),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<double>(
                            initialValue: _selectedGSTRate,
                            decoration: _inputDecoration('GST Rate *', '', Icons.percent_rounded),
                            isExpanded: true,
                            items: GSTRates.all.map((rate) {
                              return DropdownMenuItem(
                                value: rate,
                                child: Text('${rate.toStringAsFixed(rate == rate.toInt() ? 0 : 2)}%'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedGSTRate = val;
                                  _updateGSTSplit();
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _hsnController,
                                  decoration: _inputDecoration('HSN/SAC', '8517', Icons.numbers_rounded),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(8),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _showHSNLookup,
                                icon: const Icon(Icons.search, size: 20),
                                style: IconButton.styleFrom(backgroundColor: appleAccent, foregroundColor: Colors.white),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: appleSubtle,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: appleDivider.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('GST Breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: appleText)),
                                const SizedBox(height: 12),
                                if (_isInterState)
                                  _buildGSTRow('IGST', _igst)
                                else ...[
                                  _buildGSTRow('CGST', _cgst),
                                  const SizedBox(height: 8),
                                  _buildGSTRow('SGST', _sgst),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                          _buildSectionHeader('Inventory', Icons.inventory_rounded),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _reorderLevelController,
                            decoration: _inputDecoration('Reorder Level', 'Low stock alert', Icons.warning_amber_rounded),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _descriptionController,
                            decoration: _inputDecoration('Description', 'Optional notes', Icons.description_rounded),
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: appleCard,
                    border: Border(top: BorderSide(color: appleDivider.withOpacity(0.3), width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => _safePop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveItem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  widget.editingItem != null ? 'Update' : 'Add Item',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3),
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

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: appleCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: appleAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: appleAccent),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: appleText, letterSpacing: -0.3)),
      ],
    );
  }

  Widget _buildGSTRow(String label, double rate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: appleSecondary)),
        Text(
          '${rate.toStringAsFixed(rate == rate.toInt() ? 0 : 2)}%',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: appleText),
        ),
      ],
    );
  }
}
