import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CreateDebitNoteScreen extends StatefulWidget {
  final Map<String, dynamic>? originalPurchase;
  
  const CreateDebitNoteScreen({super.key, this.originalPurchase});

  @override
  State<CreateDebitNoteScreen> createState() => _CreateDebitNoteScreenState();
}

class _CreateDebitNoteScreenState extends State<CreateDebitNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedPurchaseId;
  Map<String, dynamic>? _selectedPurchase;
  List<Map<String, dynamic>> _returnItems = [];
  String _returnReason = 'Defective Product';
  DateTime _debitNoteDate = DateTime.now();
  bool _isLoading = false;

  final List<String> _returnReasons = [
    'Defective Product',
    'Wrong Product Received',
    'Quality Issues',
    'Quantity Mismatch',
    'Price Correction',
    'Damaged During Transit',
    'Expired Product',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.originalPurchase != null) {
      _selectedPurchase = widget.originalPurchase;
      _selectedPurchaseId = widget.originalPurchase!['id'];
      _initializeReturnItems();
    }
  }

  void _initializeReturnItems() {
    if (_selectedPurchase == null) return;
    
    final items = (_selectedPurchase!['items'] ?? _selectedPurchase!['lineItems'] ?? []) as List<dynamic>;
    _returnItems = items.map((item) {
      return {
        'productName': item['productName'] ?? item['name'] ?? 'Unknown',
        'hsn': item['hsn'] ?? item['hsnCode'] ?? item['hsnSac'] ?? '',
        'originalQuantity': (item['quantity'] as num?)?.toDouble() ?? 0.0,
        'returnQuantity': 0.0,
        'rate': (item['rate'] as num?)?.toDouble() ?? (item['price'] as num?)?.toDouble() ?? (item['costPrice'] as num?)?.toDouble() ?? 0.0,
        'taxRate': (item['taxRate'] as num?)?.toDouble() ?? (item['gstRate'] as num?)?.toDouble() ?? ((item['cgst'] as num?)?.toDouble() ?? 0.0) * 2 ?? 0.0,
        'cgst': (item['cgst'] as num?)?.toDouble() ?? 0.0,
        'sgst': (item['sgst'] as num?)?.toDouble() ?? 0.0,
        'igst': (item['igst'] as num?)?.toDouble() ?? 0.0,
        'selected': false,
      };
    }).toList();
  }

  // ✅ FIXED: Purchase selection dialog
  Future<void> _showPurchaseSelectionDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_cart, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Select Purchase',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('purchases')
                      .orderBy('createdAt', descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Error: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'No purchases found',
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create a purchase order first',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final purchases = snapshot.data!.docs;

                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: purchases.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final purchase = purchases[index].data() as Map<String, dynamic>;
                        final purchaseId = purchases[index].id;
                        final purchaseNumber = purchase['invoiceNumber'] ?? purchase['purchaseNumber'] ?? 'N/A';
                        final supplierName = purchase['supplierName'] ?? purchase['vendorName'] ?? 'Unknown Supplier';
                        final totalAmount = (purchase['totalAmount'] as num?)?.toDouble() ?? 
                                             (purchase['totalCost'] as num?)?.toDouble() ?? 0.0;
                        final purchaseDate = (purchase['invoiceDate'] as Timestamp?)?.toDate() ?? 
                                              (purchase['purchaseDate'] as Timestamp?)?.toDate() ?? 
                                              (purchase['createdAt'] as Timestamp?)?.toDate() ?? 
                                              DateTime.now();
                        
                        // ✅ CHECK ITC ELIGIBILITY
                        final itcEligible = purchase['itcEligible'] ?? purchase['itcEligibility'] ?? true;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: itcEligible ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              itcEligible ? Icons.check_circle : Icons.cancel,
                              color: itcEligible ? Colors.green : Colors.grey,
                              size: 24,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  purchaseNumber,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              if (itcEligible)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'ITC',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                supplierName,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${DateFormat('dd MMM yyyy').format(purchaseDate)} • ₹${totalAmount.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            setState(() {
                              _selectedPurchaseId = purchaseId;
                              _selectedPurchase = {
                                'id': purchaseId,
                                ...purchase,
                              };
                              _initializeReturnItems();
                            });
                            Navigator.pop(context);
                          },
                        );
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

  Future<String> _generateDebitNoteNumber() async {
    final user = FirebaseAuth.instance.currentUser!;
    final year = DateTime.now().year.toString().substring(2);
    final month = DateTime.now().month.toString().padLeft(2, '0');
    
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('debit_notes')
        .where('createdAt', isGreaterThanOrEqualTo: DateTime(DateTime.now().year, DateTime.now().month, 1))
        .get();
    
    final count = snapshot.docs.length + 1;
    return 'DN/$year$month/${count.toString().padLeft(4, '0')}';
  }

  double _calculateReturnAmount() {
    double total = 0;
    for (var item in _returnItems) {
      if (item['selected'] == true) {
        final qty = item['returnQuantity'] ?? 0.0;
        final rate = item['rate'] ?? 0.0;
        final taxRate = item['taxRate'] ?? 0.0;
        
        final amount = qty * rate;
        final tax = amount * taxRate / 100;
        total += amount + tax;
      }
    }
    return total;
  }

  // ✅ CALCULATE ITC TO BE REVERSED (ONLY FOR ITC ELIGIBLE PURCHASES)
  Map<String, double> _calculateITCReversal() {
    final itcEligible = _selectedPurchase?['itcEligible'] ?? _selectedPurchase?['itcEligibility'] ?? true;
    
    if (!itcEligible) {
      return {'cgst': 0, 'sgst': 0, 'igst': 0, 'total': 0};
    }

    double cgst = 0, sgst = 0, igst = 0;
    
    for (var item in _returnItems) {
      if (item['selected'] == true) {
        final qty = item['returnQuantity'] ?? 0.0;
        final rate = item['rate'] ?? 0.0;
        final taxRate = item['taxRate'] ?? 0.0;
        
        final amount = qty * rate;
        final tax = amount * taxRate / 100;
        
        // Check if IGST or CGST+SGST
        if ((item['igst'] ?? 0.0) > 0) {
          igst += tax;
        } else {
          cgst += tax / 2;
          sgst += tax / 2;
        }
      }
    }
    
    return {
      'cgst': cgst,
      'sgst': sgst,
      'igst': igst,
      'total': cgst + sgst + igst,
    };
  }

  Future<void> _saveDebitNote() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedPurchase == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a purchase invoice first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedItems = _returnItems.where((item) => item['selected'] == true).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item to return'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate return quantities
    bool hasInvalidQty = false;
    for (var item in selectedItems) {
      if ((item['returnQuantity'] ?? 0.0) <= 0) {
        hasInvalidQty = true;
        break;
      }
    }

    if (hasInvalidQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid return quantities for selected items'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final debitNoteNumber = await _generateDebitNoteNumber();
      final returnAmount = _calculateReturnAmount();
      final itcReversal = _calculateITCReversal();
      
      // ✅ CHECK ITC ELIGIBILITY
      final itcEligible = _selectedPurchase!['itcEligible'] ?? _selectedPurchase!['itcEligibility'] ?? true;

      // Calculate tax breakup
      double taxableAmount = 0;
      
      for (var item in selectedItems) {
        final qty = item['returnQuantity'];
        final rate = item['rate'];
        final amount = qty * rate;
        taxableAmount += amount;
      }

      final debitNoteData = {
        'debitNoteNumber': debitNoteNumber,
        'debitNoteDate': Timestamp.fromDate(_debitNoteDate),
        'originalPurchaseNumber': _selectedPurchase!['purchaseNumber'] ?? _selectedPurchase!['invoiceNumber'],
        'originalPurchaseDate': _selectedPurchase!['purchaseDate'] ?? _selectedPurchase!['invoiceDate'] ?? _selectedPurchase!['createdAt'],
        'originalPurchaseId': _selectedPurchaseId,
        'supplierName': _selectedPurchase!['supplierName'] ?? _selectedPurchase!['vendorName'] ?? 'Unknown',
        'supplierGstin': _selectedPurchase!['supplierGstin'] ?? _selectedPurchase!['vendorGstin'] ?? '',
        'supplierState': _selectedPurchase!['supplierState'] ?? '',
        'returnReason': _returnReason,
        'returnItems': selectedItems,
        'totalReturnAmount': returnAmount,
        'taxableValue': taxableAmount,
        'cgst': itcReversal['cgst'],
        'sgst': itcReversal['sgst'],
        'igst': itcReversal['igst'],
        'status': 'issued',
        
        // ✅ GST-COMPLIANT ITC REVERSAL
        'itcEligible': itcEligible,
        'itcToBeReversed': itcEligible ? itcReversal['total'] : 0.0,
        'itcReversalRequired': itcEligible,
        'itcReversalStatus': itcEligible ? 'pending' : 'not_applicable',
        'itcReversalDate': null,
        'itcReversalRemark': itcEligible ? 'ITC reversal required as per Rule 42 of CGST Rules' : 'No ITC was claimed on original purchase',
        
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.email,
        'financialYear': '${DateTime.now().year}-${DateTime.now().year + 1}',
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('debit_notes')
          .add(debitNoteData);

      // Update original purchase
      final currentTotal = (_selectedPurchase!['totalAmount'] as num?)?.toDouble() ?? 
                            (_selectedPurchase!['totalCost'] as num?)?.toDouble() ?? 0.0;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('purchases')
          .doc(_selectedPurchaseId)
          .update({
        'hasDebitNote': true,
        'debitNoteAmount': FieldValue.increment(returnAmount),
        'netAmount': currentTotal - returnAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        final message = itcEligible
            ? '✅ Debit Note created!\n⚠️ ITC to Reverse: ₹${itcReversal['total']!.toStringAsFixed(2)}'
            : '✅ Debit Note created!\nℹ️ No ITC reversal required (Purchase was not ITC eligible)';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itcEligible = _selectedPurchase?['itcEligible'] ?? _selectedPurchase?['itcEligibility'] ?? true;
    final itcReversal = _calculateITCReversal();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Debit Note'),
        backgroundColor: Colors.orange,
        elevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Debit Note - Purchase Return',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Issued when you return goods to supplier. ITC will be reversed ONLY if purchase was ITC eligible.',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // Purchase Selection
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shopping_cart, color: Colors.orange),
                ),
                title: Text(
                  _selectedPurchase != null
                      ? 'Purchase: ${_selectedPurchase!['purchaseNumber'] ?? _selectedPurchase!['invoiceNumber']}'
                      : 'Select Original Purchase',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: _selectedPurchase != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Supplier: ${_selectedPurchase!['supplierName'] ?? _selectedPurchase!['vendorName'] ?? 'Unknown'}'),
                          if (_selectedPurchase != null)
                            Text(
                              itcEligible ? '✅ ITC Eligible' : '❌ ITC Not Eligible',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: itcEligible ? Colors.green : Colors.grey,
                              ),
                            ),
                        ],
                      )
                    : const Text('Tap to select a purchase'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showPurchaseSelectionDialog,  // ✅ FIXED!
              ),
            ),

            const SizedBox(height: 16),

            // Debit Note Date
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Debit Note Date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_debitNoteDate)),
                trailing: const Icon(Icons.edit, size: 20),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _debitNoteDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _debitNoteDate = date);
                  }
                },
              ),
            ),

            const SizedBox(height: 16),

            // Return Reason
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Return Reason',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _returnReason,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _returnReasons.map((reason) {
                        return DropdownMenuItem(
                          value: reason,
                          child: Text(reason),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _returnReason = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Return Items
            if (_returnItems.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.inventory_2, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text(
                    'Select Items to Return',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._returnItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: item['selected'] ?? false,
                              onChanged: (value) {
                                setState(() {
                                  _returnItems[index]['selected'] = value ?? false;
                                  if (!(value ?? false)) {
                                    _returnItems[index]['returnQuantity'] = 0.0;
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['productName'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'HSN: ${item['hsn']} | Rate: ₹${item['rate']} | Tax: ${item['taxRate']}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (item['selected'] == true) ...[
                          const Divider(height: 20),
                          Row(
                            children: [
                              const SizedBox(width: 48),
                              Expanded(
                                child: Text(
                                  'Original Qty: ${item['originalQuantity']}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Return Qty',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Required';
                                    final qty = double.tryParse(value);
                                    if (qty == null || qty <= 0) return 'Invalid';
                                    if (qty > item['originalQuantity']) return 'Exceeds';
                                    return null;
                                  },
                                  onChanged: (value) {
                                    final qty = double.tryParse(value) ?? 0;
                                    setState(() {
                                      _returnItems[index]['returnQuantity'] = qty;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ] else if (_selectedPurchase != null) ...[
              Card(
                elevation: 2,
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No items found in the selected purchase',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Total Return Amount & ITC Reversal
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Return Amount:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${_calculateReturnAmount().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  if (itcEligible && itcReversal['total']! > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning, size: 18, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'ITC to be Reversed',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (itcReversal['cgst']! > 0)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('CGST:', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                                Text('₹${itcReversal['cgst']!.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                              ],
                            ),
                          if (itcReversal['sgst']! > 0)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('SGST:', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                                Text('₹${itcReversal['sgst']!.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                              ],
                            ),
                          if (itcReversal['igst']! > 0)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('IGST:', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                                Text('₹${itcReversal['igst']!.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                              ],
                            ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                              Text(
                                '₹${itcReversal['total']!.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No ITC reversal required (Purchase was not ITC eligible)',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Create Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveDebitNote,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_isLoading ? 'Creating Debit Note...' : 'Create Debit Note'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
