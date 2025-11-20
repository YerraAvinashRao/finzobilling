import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CreateCreditNoteScreen extends StatefulWidget {
  final Map<String, dynamic>? originalInvoice;
  
  const CreateCreditNoteScreen({super.key, this.originalInvoice});

  @override
  State<CreateCreditNoteScreen> createState() => _CreateCreditNoteScreenState();
}

class _CreateCreditNoteScreenState extends State<CreateCreditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedInvoiceId;
  Map<String, dynamic>? _selectedInvoice;
  List<Map<String, dynamic>> _returnItems = [];
  String _returnReason = 'Defective Product';
  DateTime _creditNoteDate = DateTime.now();
  bool _isLoading = false;

  final List<String> _returnReasons = [
    'Defective Product',
    'Wrong Product Delivered',
    'Quality Issues',
    'Quantity Mismatch',
    'Price Correction',
    'Damaged Goods',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.originalInvoice != null) {
      _selectedInvoice = widget.originalInvoice;
      _selectedInvoiceId = widget.originalInvoice!['id'];
      _initializeReturnItems();
    }
  }

  void _initializeReturnItems() {
    if (_selectedInvoice == null) return;
    
    final items = (_selectedInvoice!['items'] ?? _selectedInvoice!['lineItems'] ?? []) as List<dynamic>;
    _returnItems = items.map((item) {
      return {
        'productName': item['productName'] ?? item['name'] ?? 'Unknown',
        'hsn': item['hsn'] ?? item['hsnCode'] ?? item['hsnSac'] ?? '',
        'originalQuantity': (item['quantity'] as num?)?.toDouble() ?? 0.0,
        'returnQuantity': 0.0,
        'rate': (item['rate'] as num?)?.toDouble() ?? (item['price'] as num?)?.toDouble() ?? 0.0,
        'taxRate': (item['taxRate'] as num?)?.toDouble() ?? (item['gstRate'] as num?)?.toDouble() ?? 0.0,
        'selected': false,
      };
    }).toList();
  }

  // ✅ FIXED: Invoice selection dialog
  Future<void> _showInvoiceSelectionDialog() async {
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
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Select Invoice',
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
                      .collection('invoices')
                      .where('status', isEqualTo: 'Paid')
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
                              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'No paid invoices found',
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Credit notes can only be created for paid invoices',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final invoices = snapshot.data!.docs;

                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: invoices.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final invoice = invoices[index].data() as Map<String, dynamic>;
                        final invoiceId = invoices[index].id;
                        final invoiceNumber = invoice['invoiceNumber'] ?? 'N/A';
                        final clientName = invoice['client']?['name'] ?? 
                                            invoice['clientName'] ?? 
                                            'Unknown Client';
                        final totalAmount = (invoice['totalAmount'] as num?)?.toDouble() ?? 0.0;
                        final invoiceDate = (invoice['invoiceDate'] as Timestamp?)?.toDate() ?? 
                                             (invoice['createdAt'] as Timestamp?)?.toDate() ?? 
                                             DateTime.now();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
                          ),
                          title: Text(
                            invoiceNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                clientName,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${DateFormat('dd MMM yyyy').format(invoiceDate)} • ₹${totalAmount.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            setState(() {
                              _selectedInvoiceId = invoiceId;
                              _selectedInvoice = {
                                'id': invoiceId,
                                ...invoice,
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

  Future<String> _generateCreditNoteNumber() async {
    final user = FirebaseAuth.instance.currentUser!;
    final year = DateTime.now().year.toString().substring(2);
    final month = DateTime.now().month.toString().padLeft(2, '0');
    
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('credit_notes')
        .where('createdAt', isGreaterThanOrEqualTo: DateTime(DateTime.now().year, DateTime.now().month, 1))
        .get();
    
    final count = snapshot.docs.length + 1;
    return 'CN/$year$month/${count.toString().padLeft(4, '0')}';
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

  Future<void> _saveCreditNote() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedInvoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an invoice first'),
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
      final creditNoteNumber = await _generateCreditNoteNumber();
      final returnAmount = _calculateReturnAmount();

      // Calculate tax breakup
      double cgst = 0, sgst = 0, igst = 0;
      double taxableAmount = 0;
      
      for (var item in selectedItems) {
        final qty = item['returnQuantity'];
        final rate = item['rate'];
        final taxRate = item['taxRate'];
        final amount = qty * rate;
        final tax = amount * taxRate / 100;
        
        taxableAmount += amount;
        cgst += tax / 2;
        sgst += tax / 2;
      }

      final creditNoteData = {
        'creditNoteNumber': creditNoteNumber,
        'creditNoteDate': Timestamp.fromDate(_creditNoteDate),
        'originalInvoiceNumber': _selectedInvoice!['invoiceNumber'],
        'originalInvoiceDate': _selectedInvoice!['invoiceDate'] ?? _selectedInvoice!['createdAt'],
        'originalInvoiceId': _selectedInvoiceId,
        'clientName': _selectedInvoice!['client']?['name'] ?? 
                       _selectedInvoice!['clientName'] ?? 
                       'Unknown',
        'clientGstin': _selectedInvoice!['client']?['gstin'] ?? 
                        _selectedInvoice!['clientGstin'] ?? '',
        'returnReason': _returnReason,
        'returnItems': selectedItems,
        'totalReturnAmount': returnAmount,
        'taxableValue': taxableAmount,
        'cgst': cgst,
        'sgst': sgst,
        'igst': igst,
        'status': 'issued',
        'itcToBeReversed': cgst + sgst + igst,
        'itcReversalRequired': true,
        'itcReversalStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.email,
        'financialYear': '${DateTime.now().year}-${DateTime.now().year + 1}',
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('credit_notes')
          .add(creditNoteData);

      // Update original invoice
      final currentTotal = (_selectedInvoice!['totalAmount'] as num?)?.toDouble() ?? 0.0;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('invoices')
          .doc(_selectedInvoiceId)
          .update({
        'hasCreditNote': true,
        'creditNoteAmount': FieldValue.increment(returnAmount),
        'netAmount': currentTotal - returnAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Credit Note created successfully!'),
            backgroundColor: Colors.green,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Credit Note'),
        elevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Invoice Selection
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.receipt_long, color: Theme.of(context).primaryColor),
                ),
                title: Text(
                  _selectedInvoice != null
                      ? 'Invoice: ${_selectedInvoice!['invoiceNumber']}'
                      : 'Select Original Invoice',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: _selectedInvoice != null
                    ? Text('Client: ${_selectedInvoice!['client']?['name'] ?? _selectedInvoice!['clientName'] ?? 'Unknown'}')
                    : const Text('Tap to select an invoice'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showInvoiceSelectionDialog,  // ✅ FIXED: Now calls the dialog
              ),
            ),

            const SizedBox(height: 16),

            // Credit Note Date
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Credit Note Date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_creditNoteDate)),
                trailing: const Icon(Icons.edit, size: 20),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _creditNoteDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _creditNoteDate = date);
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
                  Icon(Icons.inventory_2, color: Theme.of(context).primaryColor),
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
            ] else if (_selectedInvoice != null) ...[
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
                          'No items found in the selected invoice',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Total Return Amount
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Return Amount:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₹${_calculateReturnAmount().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Create Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveCreditNote,
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
              label: Text(_isLoading ? 'Creating Credit Note...' : 'Create Credit Note'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.red,
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
