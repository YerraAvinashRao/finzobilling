import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:finzobilling/models/product_model.dart';
import 'package:finzobilling/widgets/add_edit_product_dialog.dart';
import 'package:finzobilling/services/audit_service.dart';

class StockTransaction {
  final DateTime date;
  final String type;
  final int quantityChange;
  final String description;
  final String? reference;
  final double? gstAmount;
  final String? adjustmentReason;

  StockTransaction({
    required this.date,
    required this.type,
    required this.quantityChange,
    required this.description,
    this.reference,
    this.gstAmount,
    this.adjustmentReason,
  });
}

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _detailsFuture;
  late TabController _tabController;

  final List<String> _tabNames = ['All', 'Sales', 'Purchases', 'Adjustments'];

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
    _detailsFuture = _fetchProductDetails();
    _tabController = TabController(length: _tabNames.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>>? _getUserDocRef() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  Future<Map<String, dynamic>> _fetchProductDetails() async {
    final userDocRef = _getUserDocRef();
    if (userDocRef == null) throw Exception("User not logged in");

    final productSnapshot = await userDocRef.collection('products').doc(widget.productId).get();
    if (!productSnapshot.exists) throw Exception("Product not found");

    final productData = productSnapshot.data()!;
    final List<StockTransaction> transactions = [];

    // Fetch invoices and purchases in parallel
    final results = await Future.wait([
      userDocRef.collection('invoices').where('productIds', arrayContains: widget.productId).get(),
      userDocRef.collection('purchases').where('productIds', arrayContains: widget.productId).get(),
    ]);

    final salesSnapshot = results[0];
    final purchasesSnapshot = results[1];

    // Purchases - FIXED VERSION
    for (var doc in purchasesSnapshot.docs) {
      final data = doc.data();
      final invoiceNum = data['invoiceNumber'] ?? '';
      final lineItems = (data['lineItems'] as List<dynamic>? ?? []);
      
      for (var item in lineItems) {
        final itemProductId = item['productId']?.toString() ?? '';
        
        if (itemProductId == widget.productId || 
            itemProductId == widget.productId.toString()) {
          
          transactions.add(StockTransaction(
            date: (data['createdAt'] as Timestamp).toDate(),
            type: 'Purchases',
            quantityChange: (item['quantity'] as num).toInt(),
            description: 'From: ${data['supplierName'] ?? 'N/A'}',
            reference: invoiceNum,
            gstAmount: (item['totalTaxAmount'] as num?)?.toDouble(),
          ));
          
          break;
        }
      }
    }

    // Sales - FIXED VERSION
    for (var doc in salesSnapshot.docs) {
      final data = doc.data();
      final invoiceNum = data['invoiceNumber'] ?? '';
      final lineItems = (data['lineItems'] as List<dynamic>? ?? []);
      
      for (var item in lineItems) {
        final itemProductId = item['productId']?.toString() ?? '';
        
        if (itemProductId == widget.productId || 
            itemProductId == widget.productId.toString()) {
          
          transactions.add(StockTransaction(
            date: (data['createdAt'] as Timestamp).toDate(),
            type: 'Sales',
            quantityChange: -((item['quantity'] as num).toInt()),
            description: 'To: ${data['client']?['name'] ?? data['clientName'] ?? 'N/A'}',
            reference: invoiceNum,
            gstAmount: (item['totalTaxAmount'] as num?)?.toDouble(),
          ));
          
          break;
        }
      }
    }

    // Adjustments
    final adjustments = (productData['adjustments'] as List<dynamic>?) ?? [];
    for (var adj in adjustments) {
      transactions.add(StockTransaction(
        date: (adj['date'] as Timestamp).toDate(),
        type: 'Adjustments',
        quantityChange: (adj['change'] as num).toInt(),
        description: 'Adjusted by: ${adj['adjustedBy'] ?? 'N/A'}',
        adjustmentReason: adj['reason'] as String?,
      ));
    }

    transactions.sort((a, b) => b.date.compareTo(a.date));
    return {'productData': productData, 'transactions': transactions};
  }

  List<StockTransaction> _filterTransactions(List<StockTransaction> transactions, String filter) {
    if (filter == 'All') return transactions;
    return transactions.where((t) => t.type == filter).toList();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
    Future<void> _showStockAdjustmentDialog(ProductModel product) async {
    final reasonController = TextEditingController();
    final quantityController = TextEditingController();
    String adjustmentType = 'add';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Adjust Stock',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: appleText,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
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
                              'Current Stock:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: appleText,
                              ),
                            ),
                            Text(
                              '${product.currentStock} ${product.unit}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: appleText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),

                      // Adjustment Type
                      const Text(
                        'Adjustment Type',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: appleText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildAdjustmentTypeButton(
                              'Add Stock',
                              Icons.add_circle_outline,
                              Colors.green,
                              adjustmentType == 'add',
                              () {
                                setDialogState(() => adjustmentType = 'add');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAdjustmentTypeButton(
                              'Remove Stock',
                              Icons.remove_circle_outline,
                              Colors.red,
                              adjustmentType == 'remove',
                              () {
                                setDialogState(() => adjustmentType = 'remove');
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Quantity
                      TextField(
                        controller: quantityController,
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          hintText: 'Enter quantity',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixText: product.unit,
                          prefixIcon: Icon(
                            adjustmentType == 'add' ? Icons.add : Icons.remove,
                            color: adjustmentType == 'add' ? Colors.green : Colors.red,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 16),

                      // Reason
                      TextField(
                        controller: reasonController,
                        decoration: InputDecoration(
                          labelText: 'Reason *',
                          hintText: 'e.g., Damaged, Found, Returned',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 2,
                      ),

                      const SizedBox(height: 12),

                      // Quick Reason Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          'Damaged',
                          'Lost',
                          'Found',
                          'Returned',
                          'Expired',
                          'Quality Issue',
                        ].map((reason) {
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => reasonController.text = reason,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: appleSubtle,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: appleDivider),
                                ),
                                child: Text(
                                  reason,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: appleText,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: appleSubtle,
                                foregroundColor: appleText,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (quantityController.text.isEmpty || reasonController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please fill all fields')),
                                  );
                                  return;
                                }

                                final qty = int.tryParse(quantityController.text);
                                if (qty == null || qty <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Invalid quantity')),
                                  );
                                  return;
                                }

                                Navigator.pop(context, {
                                  'quantity': adjustmentType == 'add' ? qty : -qty,
                                  'reason': reasonController.text.trim(),
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: adjustmentType == 'add' ? Colors.green : Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Adjust Stock',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
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
            );
          },
        );
      },
    );

    if (result == null) return;

    // Process adjustment
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final productRef = _getUserDocRef()!.collection('products').doc(widget.productId);

      final adjustment = {
        'change': result['quantity'],
        'reason': result['reason'],
        'date': Timestamp.now(),
        'adjustedBy': user.email,
      };

      await productRef.update({
        'currentStock': FieldValue.increment(result['quantity']),
        'adjustments': FieldValue.arrayUnion([adjustment]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await AuditService().logAction(
        entityType: 'product',
        entityId: widget.productId,
        action: 'STOCK_ADJUSTMENT',
        afterData: adjustment,
        reason: result['reason'],
      );

      if (mounted) {
        _showSnackBar('Stock adjusted: ${result['quantity'] > 0 ? '+' : ''}${result['quantity']} ${product.unit}');
        setState(() => _detailsFuture = _fetchProductDetails());
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  Widget _buildAdjustmentTypeButton(
    String label,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : appleSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : appleDivider,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? color : appleSecondary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : appleText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportLedgerPDF(ProductModel product, List<StockTransaction> transactions) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Stock Ledger Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Product: ${product.name}', style: const pw.TextStyle(fontSize: 16)),
            pw.Text('SKU: ${product.sku ?? 'N/A'}', style: const pw.TextStyle(fontSize: 12)),
            pw.Text('Category: ${product.category}', style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 12),
            
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFEEEEEE),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Current Stock:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('${product.currentStock} ${product.unit}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            
            pw.SizedBox(height: 8),
            
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFE3F2FD),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Stock Value:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(currencyFormat.format(product.stockValue), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 12),
            
            pw.Text('Transaction History', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: ['Date', 'Type', 'Change', 'Reference', 'Description'],
              data: transactions.map((t) => [
                DateFormat('dd/MM/yy').format(t.date),
                t.type,
                '${t.quantityChange > 0 ? '+' : ''}${t.quantityChange}',
                t.reference ?? t.adjustmentReason ?? '-',
                t.description,
              ]).toList(),
            ),
          ],
        ),
      ),
    );
    
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Stock_Ledger_${product.name}.pdf');
  }
    @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return FutureBuilder<Map<String, dynamic>>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: appleBackground,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('Product Details'),
            ),
            body: const Center(
              child: CircularProgressIndicator(color: appleAccent),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: appleBackground,
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: appleSecondary),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}', style: TextStyle(color: appleSecondary)),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: appleBackground,
            appBar: AppBar(title: const Text('Product Details')),
            body: const Center(child: Text('No data found.')),
          );
        }

        final details = snapshot.data!;
        final productData = details['productData'] as Map<String, dynamic>;
        final product = ProductModel.fromFirestore(widget.productId, productData);
        final transactions = details['transactions'] as List<StockTransaction>;

        return Scaffold(
          backgroundColor: appleBackground,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: appleCard.withOpacity(0.8),
                    border: Border(
                      bottom: BorderSide(
                        color: appleDivider.withOpacity(0.3),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, color: appleText, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                        color: appleText,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: appleAccent, size: 22),
                        tooltip: 'Edit Product',
                        onPressed: () async {
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (context) => AddEditProductDialog(product: product),
                          );
                          if (result == true && mounted) {
                            setState(() {
                              _detailsFuture = _fetchProductDetails();
                            });
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Export PDF',
                        onPressed: () => _exportLedgerPDF(product, transactions),
                        icon: const Icon(Icons.picture_as_pdf_outlined, color: appleAccent, size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _detailsFuture = _fetchProductDetails();
              });
              await _detailsFuture;
            },
            color: appleAccent,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Product Info Card
                Container(
                  decoration: BoxDecoration(
                    color: appleCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: appleDivider.withOpacity(0.3), width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: appleAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.inventory_2_rounded,
                                size: 32,
                                color: appleAccent,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: appleText,
                                      letterSpacing: -0.5,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: appleAccent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          product.category,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: appleAccent,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                      if (!product.isActive) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Inactive',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        Divider(height: 32, color: appleDivider.withOpacity(0.5)),

                        // Stock Info
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoTile(
                                'Current Stock',
                                '${product.currentStock} ${product.unit}',
                                product.isLowStock ? Icons.warning_rounded : Icons.inventory_rounded,
                                product.isLowStock ? Colors.red : Colors.green,
                              ),
                            ),
                            Container(width: 1, height: 50, color: appleDivider.withOpacity(0.3)),
                            Expanded(
                              child: _buildInfoTile(
                                'Stock Value',
                                currencyFormat.format(product.stockValue),
                                Icons.attach_money_rounded,
                                appleAccent,
                              ),
                            ),
                          ],
                        ),

                        if (product.isLowStock) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Low Stock Alert! Reorder level: ${product.reorderLevel} ${product.unit}',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        Divider(height: 32, color: appleDivider.withOpacity(0.5)),

                        // Pricing Info
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailRow('Selling Price', currencyFormat.format(product.sellingPrice)),
                            ),
                            Expanded(
                              child: _buildDetailRow(
                                'Purchase Price',
                                product.purchasePrice != null ? currencyFormat.format(product.purchasePrice!) : 'N/A',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailRow('GST Rate', '${product.gstRate.toStringAsFixed(product.gstRate % 1 == 0 ? 0 : 1)}%'),
                            ),
                            Expanded(
                              child: _buildDetailRow('HSN Code', product.hsnCode ?? 'N/A'),
                            ),
                          ],
                        ),

                        if (product.profitMargin != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade50,
                                  Colors.green.shade100.withOpacity(0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Profit Margin',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: appleText,
                                  ),
                                ),
                                Text(
                                  '${product.profitMargin!.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                    color: Colors.green.shade700,
                                    letterSpacing: -0.5,
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

                const SizedBox(height: 16),

                // Stock Adjustment Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showStockAdjustmentDialog(product),
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    label: const Text('Adjust Stock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Transaction History Header
                const Text(
                  'Stock Ledger',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: appleText,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Tabs
                Container(
                  decoration: BoxDecoration(
                    color: appleCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: appleDivider.withOpacity(0.3)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: appleAccent,
                    unselectedLabelColor: appleSecondary,
                    indicatorColor: appleAccent,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    tabs: _tabNames.map((t) => Tab(text: t)).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Tab Content
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: TabBarView(
                    controller: _tabController,
                    children: _tabNames.map((filter) {
                      final filtered = _filterTransactions(transactions, filter);

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: appleSubtle,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Icon(
                                  Icons.receipt_long_rounded,
                                  size: 40,
                                  color: appleSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No $filter transactions',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: appleText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Transactions will appear here',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: appleSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, index) {
                          final t = filtered[index];
                          final isPositive = t.quantityChange >= 0;

                          return Container(
                            decoration: BoxDecoration(
                              color: appleCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: appleDivider.withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isPositive ? Icons.add_rounded : Icons.remove_rounded,
                                      color: isPositive ? Colors.green : Colors.red,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${t.type}: ${isPositive ? '+' : ''}${t.quantityChange} ${product.unit}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          t.description,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: appleText,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (t.reference != null || t.adjustmentReason != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            t.reference != null ? 'Ref: ${t.reference}' : 'Reason: ${t.adjustmentReason}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: t.adjustmentReason != null 
                                                  ? Colors.orange.shade700 
                                                  : appleSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('dd MMM\nyyyy').format(t.date),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: appleSecondary,
                                      height: 1.3,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: appleSecondary,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: appleSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: appleText,
            letterSpacing: -0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
