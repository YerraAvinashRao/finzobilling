import 'package:finzobilling/screens/gst_reports_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Premium colors
const Color appleBackground = Color(0xFFF2F2F7);
const Color appleCard = Color(0xFFFFFFFF);
const Color appleAccent = Color(0xFF007AFF);

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _auth = FirebaseAuth.instance;
  String? _userId;
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  // Keep ALL your existing report generation methods EXACTLY as they are
  Future<void> _generateSalesReport() async {
    if (_userId == null) return;

    setState(() => _isGenerating = true);

    try {
      final startTimestamp = Timestamp.fromDate(_startDate);
      final endTimestamp = Timestamp.fromDate(_endDate.add(const Duration(days: 1)));

      final invoicesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('invoices')
          .where('invoiceDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('invoiceDate', isLessThan: endTimestamp)
          .orderBy('invoiceDate', descending: true)
          .get();

      if (invoicesSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No invoices found in this date range')),
          );
        }
        return;
      }

      List<List<dynamic>> rows = [
        ['Invoice Number', 'Date', 'Client', 'Total Amount', 'Tax', 'Status'],
      ];

      double totalSales = 0;
      double totalTax = 0;

      for (var doc in invoicesSnapshot.docs) {
        final data = doc.data();
        final invoiceNumber = data['invoiceNumber'] ?? '';
        final date = (data['invoiceDate'] as Timestamp?)?.toDate();
        final clientName = data['clientName'] ?? '';
        final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
        final tax = (data['totalTax'] as num?)?.toDouble() ?? 0;
        final status = data['status'] ?? '';

        rows.add([
          invoiceNumber,
          date != null ? DateFormat('dd/MM/yyyy').format(date) : '',
          clientName,
          totalAmount.toStringAsFixed(2),
          tax.toStringAsFixed(2),
          status,
        ]);

        if (status != 'Void') {
          totalSales += totalAmount;
          totalTax += tax;
        }
      }

      rows.add(['', '', 'TOTAL', totalSales.toStringAsFixed(2), totalTax.toStringAsFixed(2), '']);

      String csv = const ListToCsvConverter().convert(rows);
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/sales_report_${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}.csv',
      );
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Sales Report from ${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sales report generated: ${invoicesSnapshot.docs.length} invoices'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generating sales report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateInventoryReport() async {
    if (_userId == null) return;

    setState(() => _isGenerating = true);

    try {
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('products')
          .orderBy('name')
          .get();

      if (productsSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No products found')),
          );
        }
        return;
      }

      List<List<dynamic>> rows = [
        ['Product Name', 'HSN/SAC', 'Quantity', 'Unit', 'Cost Price', 'Selling Price', 'Stock Value'],
      ];

      double totalStockValue = 0;

      for (var doc in productsSnapshot.docs) {
        final data = doc.data();
        final name = data['name'] ?? '';
        final hsnSac = data['hsnCode'] ?? '';
        final quantity = (data['currentStock'] ?? data['quantity'] ?? 0) as num;
        final unit = data['unit'] ?? 'pcs';
        final costPrice = (data['costPrice'] ?? data['purchasePrice'] ?? 0).toDouble();
        final sellingPrice = (data['price'] ?? data['sellingPrice'] ?? 0).toDouble();
        final stockValue = quantity * costPrice;

        rows.add([
          name,
          hsnSac,
          quantity.toString(),
          unit,
          costPrice.toStringAsFixed(2),
          sellingPrice.toStringAsFixed(2),
          stockValue.toStringAsFixed(2),
        ]);

        totalStockValue += stockValue;
      }

      rows.add(['', '', '', '', '', 'TOTAL', totalStockValue.toStringAsFixed(2)]);

      String csv = const ListToCsvConverter().convert(rows);
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/inventory_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Inventory Report as of ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Inventory report generated: ${productsSnapshot.docs.length} products'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generating inventory report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateCreditNotesReport() async {
    if (_userId == null) return;

    setState(() => _isGenerating = true);

    try {
      final startTimestamp = Timestamp.fromDate(_startDate);
      final endTimestamp = Timestamp.fromDate(_endDate.add(const Duration(days: 1)));

      final creditNotesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('credit_notes')
          .where('creditNoteDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('creditNoteDate', isLessThan: endTimestamp)
          .orderBy('creditNoteDate', descending: true)
          .get();

      if (creditNotesSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No credit notes found in this date range')),
          );
        }
        return;
      }

      List<List<dynamic>> rows = [
        [
          'Credit Note No',
          'Date',
          'Invoice No',
          'Client',
          'Reason',
          'Taxable Value',
          'CGST',
          'SGST',
          'IGST',
          'Total Amount',
          'ITC Reversal Status'
        ],
      ];

      double totalAmount = 0;
      double totalCGST = 0;
      double totalSGST = 0;
      double totalIGST = 0;
      double totalITCToReverse = 0;

      for (var doc in creditNotesSnapshot.docs) {
        final data = doc.data();
        final creditNoteNumber = data['creditNoteNumber'] ?? '';
        final date = (data['creditNoteDate'] as Timestamp?)?.toDate();
        final invoiceNumber = data['originalInvoiceNumber'] ?? '';
        final clientName = data['clientName'] ?? '';
        final reason = data['returnReason'] ?? '';
        
        final amount = (data['totalReturnAmount'] as num?)?.toDouble() ?? 0;
        final cgst = (data['cgst'] as num?)?.toDouble() ?? 0;
        final sgst = (data['sgst'] as num?)?.toDouble() ?? 0;
        final igst = (data['igst'] as num?)?.toDouble() ?? 0;
        final taxableValue = amount - cgst - sgst - igst;
        final itcStatus = data['itcReversalStatus'] ?? 'pending';

        rows.add([
          creditNoteNumber,
          date != null ? DateFormat('dd/MM/yyyy').format(date) : '',
          invoiceNumber,
          clientName,
          reason,
          taxableValue.toStringAsFixed(2),
          cgst.toStringAsFixed(2),
          sgst.toStringAsFixed(2),
          igst.toStringAsFixed(2),
          amount.toStringAsFixed(2),
          itcStatus.toUpperCase(),
        ]);

        totalAmount += amount;
        totalCGST += cgst;
        totalSGST += sgst;
        totalIGST += igst;
        totalITCToReverse += (cgst + sgst + igst);
      }

      rows.add([
        '',
        '',
        '',
        '',
        'TOTAL',
        (totalAmount - totalCGST - totalSGST - totalIGST).toStringAsFixed(2),
        totalCGST.toStringAsFixed(2),
        totalSGST.toStringAsFixed(2),
        totalIGST.toStringAsFixed(2),
        totalAmount.toStringAsFixed(2),
        'ITC: ${totalITCToReverse.toStringAsFixed(2)}',
      ]);

      String csv = const ListToCsvConverter().convert(rows);
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/credit_notes_report_${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}.csv',
      );
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Credit Notes Report from ${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Credit Notes report generated: ${creditNotesSnapshot.docs.length} credit notes\nTotal ITC to Reverse: ₹${totalITCToReverse.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generating credit notes report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateDebitNotesReport() async {
    if (_userId == null) return;

    setState(() => _isGenerating = true);

    try {
      final startTimestamp = Timestamp.fromDate(_startDate);
      final endTimestamp = Timestamp.fromDate(_endDate.add(const Duration(days: 1)));

      final debitNotesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('debit_notes')
          .where('debitNoteDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('debitNoteDate', isLessThan: endTimestamp)
          .orderBy('debitNoteDate', descending: true)
          .get();

      if (debitNotesSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No debit notes found in this date range')),
          );
        }
        return;
      }

      List<List<dynamic>> rows = [
        [
          'Debit Note No',
          'Date',
          'Purchase No',
          'Supplier',
          'Reason',
          'Taxable Value',
          'CGST',
          'SGST',
          'IGST',
          'Total Amount',
          'ITC Reversal Status'
        ],
      ];

      double totalAmount = 0;
      double totalCGST = 0;
      double totalSGST = 0;
      double totalIGST = 0;
      double totalITCToReverse = 0;

      for (var doc in debitNotesSnapshot.docs) {
        final data = doc.data();
        final debitNoteNumber = data['debitNoteNumber'] ?? '';
        final date = (data['debitNoteDate'] as Timestamp?)?.toDate();
        final purchaseNumber = data['originalPurchaseNumber'] ?? '';
        final supplierName = data['supplierName'] ?? '';
        final reason = data['returnReason'] ?? '';
        
        final amount = (data['totalReturnAmount'] as num?)?.toDouble() ?? 0;
        final cgst = (data['cgst'] as num?)?.toDouble() ?? 0;
        final sgst = (data['sgst'] as num?)?.toDouble() ?? 0;
        final igst = (data['igst'] as num?)?.toDouble() ?? 0;
        final taxableValue = (data['taxableValue'] as num?)?.toDouble() ?? (amount - cgst - sgst - igst);
        final itcStatus = data['itcReversalStatus'] ?? 'pending';

        rows.add([
          debitNoteNumber,
          date != null ? DateFormat('dd/MM/yyyy').format(date) : '',
          purchaseNumber,
          supplierName,
          reason,
          taxableValue.toStringAsFixed(2),
          cgst.toStringAsFixed(2),
          sgst.toStringAsFixed(2),
          igst.toStringAsFixed(2),
          amount.toStringAsFixed(2),
          itcStatus.toUpperCase(),
        ]);

        totalAmount += amount;
        totalCGST += cgst;
        totalSGST += sgst;
        totalIGST += igst;
        totalITCToReverse += (cgst + sgst + igst);
      }

      rows.add([
        '',
        '',
        '',
        '',
        'TOTAL',
        (totalAmount - totalCGST - totalSGST - totalIGST).toStringAsFixed(2),
        totalCGST.toStringAsFixed(2),
        totalSGST.toStringAsFixed(2),
        totalIGST.toStringAsFixed(2),
        totalAmount.toStringAsFixed(2),
        'ITC: ${totalITCToReverse.toStringAsFixed(2)}',
      ]);

      String csv = const ListToCsvConverter().convert(rows);
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/debit_notes_report_${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}.csv',
      );
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Debit Notes Report from ${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Debit Notes report generated: ${debitNotesSnapshot.docs.length} debit notes\nTotal ITC to Reverse: ₹${totalITCToReverse.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generating debit notes report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        backgroundColor: appleBackground,
        body: const Center(child: Text('Please log in to view reports')),
      );
    }

    return Scaffold(
      backgroundColor: appleBackground,
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: appleCard,
        elevation: 0,
        actions: [
          if (_isGenerating)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date range selector
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: appleAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.date_range_rounded, color: appleAccent),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Date Range',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: appleBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FROM',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('dd MMM yyyy').format(_startDate),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward, color: Colors.grey.shade400),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TO',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('dd MMM yyyy').format(_endDate),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _selectDateRange,
                      icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                      label: const Text('Change Date Range'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appleAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // GST Reports Section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance_rounded, color: Colors.indigo, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'GST Compliance Reports',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildReportCard(
              icon: Icons.account_balance_rounded,
              title: 'GST Reports Hub',
              description: 'Complete GST compliance - GSTR-1, 3B, HSN & more',
              color: Colors.indigo,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GSTReportsHubScreen()),
                );
              },
              isPremium: true,
            ),

            const SizedBox(height: 24),

            // Other Reports
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: appleAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.bar_chart_rounded, color: appleAccent, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Business Reports',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildReportCard(
              icon: Icons.receipt_long_rounded,
              title: 'Sales Report',
              description: 'Detailed sales report with invoice details',
              color: Colors.blue,
              onTap: _isGenerating ? null : _generateSalesReport,
            ),
            const SizedBox(height: 12),

            _buildReportCard(
              icon: Icons.inventory_2_rounded,
              title: 'Inventory Report',
              description: 'Current stock levels and valuation',
              color: Colors.orange,
              onTap: _isGenerating ? null : _generateInventoryReport,
            ),
            const SizedBox(height: 12),

            _buildReportCard(
              icon: Icons.assignment_return_rounded,
              title: 'Credit Notes Report',
              description: 'Sales returns & ITC reversal tracking',
              color: Colors.red,
              onTap: _isGenerating ? null : _generateCreditNotesReport,
              isPremium: true,
            ),
            const SizedBox(height: 12),

            _buildReportCard(
              icon: Icons.assignment_return_outlined,
              title: 'Debit Notes Report',
              description: 'Purchase returns & ITC reversal tracking',
              color: Colors.deepOrange,
              onTap: _isGenerating ? null : _generateDebitNotesReport,
              isPremium: true,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback? onTap,
    bool isPremium = false,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPremium ? BorderSide(color: color.withOpacity(0.3), width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isPremium
                ? LinearGradient(
                    colors: [color.withOpacity(0.05), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(  // ← Changed from no wrapper to Flexible
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            maxLines: 1,  // ← Add this
                            overflow: TextOverflow.ellipsis,  // ← Add this
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(width: 6),  // ← Reduced from 8 to 6
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),  // ← Reduced from 8 to 6
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                fontSize: 9,  // ← Reduced from 10 to 9
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
