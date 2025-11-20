import 'dart:core';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

// Premium colors
const Color appleBackground = Color(0xFFF2F2F7);
const Color appleCard = Color(0xFFFFFFFF);
const Color appleAccent = Color(0xFF007AFF);

class GSTR1Screen extends StatefulWidget {
  const GSTR1Screen({super.key});

  @override
  State<GSTR1Screen> createState() => _GSTR1ScreenState();
}

class _GSTR1ScreenState extends State<GSTR1Screen> with SingleTickerProviderStateMixin {
  DateTime _selectedMonth = DateTime.now();
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;
  late TabController _tabController;

  @override
    void initState() {
      super.initState();
      _tabController = TabController(length: 4, vsync: this);
      
      // ✅ Smart default: Show previous month if we're in filing window (1-11)
      final now = DateTime.now();
      if (now.day <= 11) {
        // Between 1st-11th: Show PREVIOUS month (the one to file)
        _selectedMonth = DateTime(now.year, now.month - 1);
      } else {
        // After 11th: Show current month (current sales data)
        _selectedMonth = DateTime(now.year, now.month);
      }
      
      _generateReport();
    }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

      final invoicesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('invoices')
          .where('invoiceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('invoiceDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .where('status', whereIn: ['Paid', 'Unpaid', 'Partially Paid'])
          .orderBy('invoiceDate', descending: true)
          .get();

      // Filter out amended invoices
      final validInvoices = invoicesSnapshot.docs.where((doc) {
        final data = doc.data();
        final isAmended = data['isAmended'] as bool? ?? false;
        return !isAmended;
      }).toList();

      debugPrint('📊 GSTR-1: Found ${invoicesSnapshot.docs.length} invoices (${validInvoices.length} valid after excluding amended)');

      // Get Credit Notes
      final creditNotesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('credit_notes')
          .where('creditNoteDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('creditNoteDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      // Categorize invoices
      List<Map<String, dynamic>> b2bInvoices = [];
      List<Map<String, dynamic>> b2cLargeInvoices = [];
      List<Map<String, dynamic>> b2cSmallInvoices = [];
      List<Map<String, dynamic>> creditNotesList = [];

      double totalB2B = 0;
      double totalB2CLarge = 0;
      double totalB2CSmall = 0;
      double totalCGST = 0;
      double totalSGST = 0;
      double totalIGST = 0;
      
      double totalCreditNoteAmount = 0;
      double creditNoteCGST = 0;
      double creditNoteSGST = 0;
      double creditNoteIGST = 0;

      // ✅ CORRECTED: Process Invoices
      for (var doc in validInvoices) {
        final data = doc.data();
        
        // ✅ Get client GSTIN (stored at root level)
        final clientGstin = data['clientGstin'] ?? '';
        
        // ✅ Get amounts (stored at root level)
        double totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
        double invoiceTaxableValue = (data['taxableValue'] as num?)?.toDouble() ?? 0;
        double invoiceCGST = (data['cgst'] as num?)?.toDouble() ?? 0;
        double invoiceSGST = (data['sgst'] as num?)?.toDouble() ?? 0;
        double invoiceIGST = (data['igst'] as num?)?.toDouble() ?? 0;

        // ✅ If amounts are missing, calculate from lineItems
        if (totalAmount == 0 || invoiceTaxableValue == 0) {
          final lineItems = data['lineItems'] as List<dynamic>? ?? [];
          invoiceTaxableValue = 0;
          
          for (var item in lineItems) {
            final lineTotal = (item['lineTotal'] as num?)?.toDouble() ?? 0;
            invoiceTaxableValue += lineTotal;
          }
          
          totalAmount = invoiceTaxableValue + invoiceCGST + invoiceSGST + invoiceIGST;
        }

        debugPrint('📊 Invoice ${data['invoiceNumber']}: GSTIN=$clientGstin, Taxable=₹$invoiceTaxableValue, CGST=₹$invoiceCGST, SGST=₹$invoiceSGST, IGST=₹$invoiceIGST, Total=₹$totalAmount');

        final invoiceData = {
          'invoiceNumber': data['invoiceNumber'] ?? '',
          'invoiceDate': (data['invoiceDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'clientName': data['clientName'] ?? 'Unknown',
          'clientGstin': clientGstin,
          'clientState': data['placeOfSupply'] ?? '',
          'taxableValue': invoiceTaxableValue,
          'cgst': invoiceCGST,
          'sgst': invoiceSGST,
          'igst': invoiceIGST,
          'totalAmount': totalAmount,
          'invoiceType': invoiceIGST > 0 ? 'Inter-State' : 'Intra-State',
        };

        totalCGST += invoiceCGST;
        totalSGST += invoiceSGST;
        totalIGST += invoiceIGST;

        // ✅ Categorize based on GSTIN and amount
        if (clientGstin.isNotEmpty && clientGstin.length == 15) {
          b2bInvoices.add(invoiceData);
          totalB2B += totalAmount;
        } else if (totalAmount > 250000) {
          b2cLargeInvoices.add(invoiceData);
          totalB2CLarge += totalAmount;
        } else {
          b2cSmallInvoices.add(invoiceData);
          totalB2CSmall += totalAmount;
        }
      }

      // Process Credit Notes
      for (var doc in creditNotesSnapshot.docs) {
        final data = doc.data();
        final cgst = (data['cgst'] as num?)?.toDouble() ?? 0;
        final sgst = (data['sgst'] as num?)?.toDouble() ?? 0;
        final igst = (data['igst'] as num?)?.toDouble() ?? 0;
        final totalReturn = (data['totalReturnAmount'] as num?)?.toDouble() ?? 0;

        creditNotesList.add({
          'creditNoteNumber': data['creditNoteNumber'] ?? '',
          'creditNoteDate': (data['creditNoteDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'originalInvoiceNumber': data['originalInvoiceNumber'] ?? '',
          'clientName': data['clientName'] ?? 'Unknown',
          'clientGstin': data['clientGstin'] ?? '',
          'totalAmount': totalReturn,
          'cgst': cgst,
          'sgst': sgst,
          'igst': igst,
          'taxableValue': totalReturn - cgst - sgst - igst,
        });

        totalCreditNoteAmount += totalReturn;
        creditNoteCGST += cgst;
        creditNoteSGST += sgst;
        creditNoteIGST += igst;
      }

      // Calculate Net Values
      final netRevenue = (totalB2B + totalB2CLarge + totalB2CSmall) - totalCreditNoteAmount;
      final netCGST = totalCGST - creditNoteCGST;
      final netSGST = totalSGST - creditNoteSGST;
      final netIGST = totalIGST - creditNoteIGST;
      final netTax = netCGST + netSGST + netIGST;

      debugPrint('📊 GSTR-1 Summary: B2B=₹$totalB2B (${b2bInvoices.length}), B2C Large=₹$totalB2CLarge (${b2cLargeInvoices.length}), B2C Small=₹$totalB2CSmall (${b2cSmallInvoices.length})');

      if (mounted) {
        setState(() {
          _reportData = {
            'month': DateFormat('MMM yyyy').format(_selectedMonth),
            'b2b': {
              'invoices': b2bInvoices,
              'count': b2bInvoices.length,
              'total': totalB2B,
            },
            'b2cLarge': {
              'invoices': b2cLargeInvoices,
              'count': b2cLargeInvoices.length,
              'total': totalB2CLarge,
            },
            'b2cSmall': {
              'invoices': b2cSmallInvoices,
              'count': b2cSmallInvoices.length,
              'total': totalB2CSmall,
            },
            'creditNotes': {
              'invoices': creditNotesList,
              'count': creditNotesList.length,
              'total': totalCreditNoteAmount,
            },
            'summary': {
              'totalInvoices': validInvoices.length,
              'totalRevenue': totalB2B + totalB2CLarge + totalB2CSmall,
              'totalCGST': totalCGST,
              'totalSGST': totalSGST,
              'totalIGST': totalIGST,
              'totalTax': totalCGST + totalSGST + totalIGST,
              'creditNoteAmount': totalCreditNoteAmount,
              'creditNoteCGST': creditNoteCGST,
              'creditNoteSGST': creditNoteSGST,
              'creditNoteIGST': creditNoteIGST,
              'netRevenue': netRevenue,
              'netCGST': netCGST,
              'netSGST': netSGST,
              'netIGST': netIGST,
              'netTax': netTax,
            },
          };
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error generating GSTR-1: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _exportToCSV() async {
    if (_reportData == null) return;

    try {
      List<List<dynamic>> rows = [
        ['GSTR-1 REPORT'],
        ['Period: ${_reportData!['month']}'],
        ['Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'],
        [],
        ['SUMMARY'],
        ['Total Invoices', _reportData!['summary']['totalInvoices']],
        ['Gross Revenue', _reportData!['summary']['totalRevenue'].toStringAsFixed(2)],
        ['Credit Notes', _reportData!['summary']['creditNoteAmount'].toStringAsFixed(2)],
        ['Net Revenue', _reportData!['summary']['netRevenue'].toStringAsFixed(2)],
        [],
        ['TAX SUMMARY'],
        ['CGST', _reportData!['summary']['totalCGST'].toStringAsFixed(2)],
        ['SGST', _reportData!['summary']['totalSGST'].toStringAsFixed(2)],
        ['IGST', _reportData!['summary']['totalIGST'].toStringAsFixed(2)],
        ['Total Tax', _reportData!['summary']['totalTax'].toStringAsFixed(2)],
        [],
        ['B2B INVOICES'],
        ['Invoice No', 'Date', 'Client', 'GSTIN', 'Taxable Value', 'CGST', 'SGST', 'IGST', 'Total'],
      ];

      for (var inv in _reportData!['b2b']['invoices']) {
        rows.add([
          inv['invoiceNumber'],
          DateFormat('dd/MM/yyyy').format(inv['invoiceDate']),
          inv['clientName'],
          inv['clientGstin'],
          inv['taxableValue'].toStringAsFixed(2),
          inv['cgst'].toStringAsFixed(2),
          inv['sgst'].toStringAsFixed(2),
          inv['igst'].toStringAsFixed(2),
          inv['totalAmount'].toStringAsFixed(2),
        ]);
      }

      String csv = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/gstr1_${DateFormat('yyyyMMdd').format(_selectedMonth)}.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(file.path)], text: 'GSTR-1 Report');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ GSTR-1 exported successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting: $e');
    }
  }

  

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
      _generateReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: appleBackground,
      appBar: AppBar(
        title: const Text(
          'GSTR-1 Report',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          if (_reportData != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.download_rounded),
                onPressed: _exportToCSV,
                tooltip: 'Export CSV',
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.calendar_month_rounded),
              onPressed: _selectMonth,
              tooltip: 'Select Month',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: _showInfoDialog,
              tooltip: 'About GSTR-1',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    'Generating GSTR-1...',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : _reportData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No data available',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _generateReport,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header Card
                      _buildHeaderCard(currency),
                      const SizedBox(height: 16),

                      // ✅ FILING STATUS BANNER - START
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
                            .collection('gst_filing_status')
                            .doc('${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || _reportData == null) {
                            return const SizedBox.shrink();
                          }
                          
                          final isAlreadyFiled = (snapshot.data?.data() as Map<String, dynamic>?)?['gstr1Filed'] ?? false;
                          
                          if (_reportData!['summary']['totalInvoices'] == 0) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isAlreadyFiled 
                                        ? [Colors.green.shade400, Colors.green.shade600]
                                        : [Colors.orange.shade400, Colors.orange.shade600],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isAlreadyFiled ? Colors.green : Colors.orange).withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isAlreadyFiled 
                                            ? Icons.check_circle_rounded 
                                            : Icons.error_outline_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isAlreadyFiled 
                                                ? '✅ GSTR-1 Filed for ${_reportData!['month']}'
                                                : '📋 Have you filed GSTR-1 for ${_reportData!['month']}?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isAlreadyFiled
                                                ? 'Any amendments will require GSTR-1A'
                                                : 'Mark as filed to enable amendment tracking',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isAlreadyFiled)
                                      SizedBox(
                                        width: 100, // ✅ Fixed width
                                        child: ElevatedButton(
                                          onPressed: _markGSTR1Filed,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.orange.shade700,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text(
                                            'Mark Filed',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                      ),
                      // ✅ FILING STATUS BANNER - END

                      // Category Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildCategoryCard(
                              'B2B',
                              _reportData!['b2b']['count'].toString(),
                              currency.format(_reportData!['b2b']['total']),
                              Colors.blue,
                              Icons.business_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCategoryCard(
                              'B2C Large',
                              _reportData!['b2cLarge']['count'].toString(),
                              currency.format(_reportData!['b2cLarge']['total']),
                              Colors.orange,
                              Icons.shopping_bag_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCategoryCard(
                              'B2C Small',
                              _reportData!['b2cSmall']['count'].toString(),
                              currency.format(_reportData!['b2cSmall']['total']),
                              Colors.purple,
                              Icons.shopping_cart_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCategoryCard(
                              'Credit Notes',
                              _reportData!['creditNotes']['count'].toString(),
                              currency.format(_reportData!['creditNotes']['total']),
                              Colors.red,
                              Icons.remove_circle_rounded,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Tax Summary Card
                      _buildTaxSummaryCard(currency),

                      const SizedBox(height: 20),

                      // Pie Chart
                      if (_reportData!['summary']['totalInvoices'] > 0)
                        _buildCategoryPieChart(),

                      const SizedBox(height: 20),

                      // Tabs
                      Container(
                        decoration: BoxDecoration(
                          color: appleCard,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                labelColor: Colors.green.shade700,
                                unselectedLabelColor: Colors.grey.shade600,
                                indicatorColor: Colors.green,
                                indicatorWeight: 3,
                                isScrollable: true,
                                tabs: const [
                                  Tab(text: 'B2B'),
                                  Tab(text: 'B2C Large'),
                                  Tab(text: 'B2C Small'),
                                  Tab(text: 'Credit Notes'),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 400,
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildInvoiceList(_reportData!['b2b']['invoices'], currency),
                                  _buildInvoiceList(_reportData!['b2cLarge']['invoices'], currency),
                                  _buildInvoiceList(_reportData!['b2cSmall']['invoices'], currency),
                                  _buildCreditNotesList(_reportData!['creditNotes']['invoices'], currency),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Instructions
                      _buildInstructions(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard(NumberFormat currency) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green, Colors.green.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GSTR-1 for ${_reportData!['month']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Outward Supplies (Sales)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.white30),
            Row(
              children: [
                Expanded(
                  child: _buildHeaderTile(
                    'Gross Revenue',
                    currency.format(_reportData!['summary']['totalRevenue']),
                    Icons.currency_rupee_rounded,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white30),
                Expanded(
                  child: _buildHeaderTile(
                    'Credit Notes',
                    currency.format(_reportData!['summary']['creditNoteAmount']),
                    Icons.remove_circle_outline_rounded,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Colors.white30),
            Row(
              children: [
                Expanded(
                  child: _buildHeaderTile(
                    'Net Revenue',
                    currency.format(_reportData!['summary']['netRevenue']),
                    Icons.check_circle_rounded,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white30),
                Expanded(
                  child: _buildHeaderTile(
                    'Net Tax',
                    currency.format(_reportData!['summary']['netTax']),
                    Icons.account_balance_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTile(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String title, String count, String amount, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            count,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTaxSummaryCard(NumberFormat currency) {
    return Container(
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calculate_rounded, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Tax Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appleBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildTaxRow('CGST', _reportData!['summary']['totalCGST'], currency, Colors.blue),
                _buildTaxRow('SGST', _reportData!['summary']['totalSGST'], currency, Colors.orange),
                _buildTaxRow('IGST', _reportData!['summary']['totalIGST'], currency, Colors.purple),
                const Divider(height: 20),
                _buildTaxRow('Total Tax', _reportData!['summary']['totalTax'], currency, Colors.green, isBold: true),
                if (_reportData!['summary']['creditNoteAmount'] > 0) ...[
                  const Divider(height: 20),
                  _buildTaxRow('Less: Credit Notes', -_reportData!['summary']['creditNoteAmount'], currency, Colors.red),
                  const Divider(height: 20),
                  _buildTaxRow('Net Tax Payable', _reportData!['summary']['netTax'], currency, Colors.green.shade800, isBold: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxRow(String label, double value, NumberFormat currency, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                  fontSize: isBold ? 16 : 14,
                ),
              ),
            ],
          ),
          Text(
            currency.format(value),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 16 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPieChart() {
    final b2bTotal = _reportData!['b2b']['total'] as double;
    final b2cLargeTotal = _reportData!['b2cLarge']['total'] as double;
    final b2cSmallTotal = _reportData!['b2cSmall']['total'] as double;
    final total = b2bTotal + b2cLargeTotal + b2cSmallTotal;

    if (total == 0) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pie_chart_rounded, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Revenue Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        if (b2bTotal > 0)
                          PieChartSectionData(
                            value: b2bTotal,
                            title: '${((b2bTotal / total) * 100).toStringAsFixed(0)}%',
                            color: Colors.blue,
                            radius: 50,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (b2cLargeTotal > 0)
                          PieChartSectionData(
                            value: b2cLargeTotal,
                            title: '${((b2cLargeTotal / total) * 100).toStringAsFixed(0)}%',
                            color: Colors.orange,
                            radius: 50,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (b2cSmallTotal > 0)
                          PieChartSectionData(
                            value: b2cSmallTotal,
                            title: '${((b2cSmallTotal / total) * 100).toStringAsFixed(0)}%',
                            color: Colors.purple,
                            radius: 50,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem('B2B', Colors.blue),
                      const SizedBox(height: 12),
                      _buildLegendItem('B2C Large', Colors.orange),
                      const SizedBox(height: 12),
                      _buildLegendItem('B2C Small', Colors.purple),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildInvoiceList(List<dynamic> invoices, NumberFormat currency) {
    if (invoices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_rounded, size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('No invoices in this category', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            title: Text(invoice['invoiceNumber'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(invoice['clientName']),
                Text(DateFormat('dd/MM/yyyy').format(invoice['invoiceDate']), style: const TextStyle(fontSize: 11)),
                if (invoice['clientGstin'].isNotEmpty)
                  Text('GSTIN: ${invoice['clientGstin']}', style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: invoice['invoiceType'] == 'Inter-State' ? Colors.purple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    invoice['invoiceType'],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: invoice['invoiceType'] == 'Inter-State' ? Colors.purple : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(currency.format(invoice['totalAmount']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text('Tax: ${currency.format(invoice['cgst'] + invoice['sgst'] + invoice['igst'])}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreditNotesList(List<dynamic> creditNotes, NumberFormat currency) {
    if (creditNotes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_rounded, size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('No credit notes in this period', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: creditNotes.length,
      itemBuilder: (context, index) {
        final cn = creditNotes[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.remove_circle_rounded, color: Colors.red, size: 24),
            ),
            title: Text(cn['creditNoteNumber'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(cn['clientName']),
                Text('Against: ${cn['originalInvoiceNumber']}', style: const TextStyle(fontSize: 11)),
                Text(DateFormat('dd/MM/yyyy').format(cn['creditNoteDate']), style: const TextStyle(fontSize: 11)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(currency.format(cn['totalAmount']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
                const SizedBox(height: 2),
                Text('Tax: ${currency.format(cn['cgst'] + cn['sgst'] + cn['igst'])}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructions() {
    return Container(
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 2),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.info_outline_rounded, color: Colors.amber.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('GSTR-1 Guidelines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appleBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• B2B: Business invoices with GSTIN', style: TextStyle(fontSize: 13, height: 1.6)),
                Text('• B2C Large: Invoice value > ₹2.5 Lakh', style: TextStyle(fontSize: 13, height: 1.6)),
                Text('• B2C Small: Invoice value ≤ ₹2.5 Lakh', style: TextStyle(fontSize: 13, height: 1.6)),
                Text('• Credit Notes: Deducted from gross revenue', style: TextStyle(fontSize: 13, height: 1.6)),
                Text('• File by 11th of next month', style: TextStyle(fontSize: 13, height: 1.6)),
                Text('• Late fee: ₹200/day (₹50 if NIL return)', style: TextStyle(fontSize: 13, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkIfGSTR1Filed() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final periodKey = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('gst_filing_status')
          .doc(periodKey)
          .get();

      return doc.data()?['gstr1Filed'] ?? false;
    } catch (e) {
      debugPrint('Error checking GSTR-1 status: $e');
      return false;
    }
  }

  // ✅✅✅ ADD THIS ENTIRE METHOD HERE ✅✅✅
  Future<void> _markGSTR1Filed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Mark GSTR-1 as Filed?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will mark GSTR-1 for ${DateFormat('MMM yyyy').format(_selectedMonth)} as filed.\n',
              style: const TextStyle(fontSize: 14),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.purple, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Any amendments after this will require GSTR-1A filing',
                      style: TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final periodKey = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('gst_filing_status')
            .doc(periodKey)
            .set({
          'gstr1Filed': true,
          'gstr1FiledOn': Timestamp.now(),
          'period': periodKey,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Text('✅ GSTR-1 marked as filed'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.trending_up_rounded, color: Colors.green),
            ),
            const SizedBox(width: 12),
            const Text('About GSTR-1'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('GSTR-1 is a return for outward supplies (sales):', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('• Details of all sales invoices'),
              Text('• B2B, B2C large, and B2C small'),
              Text('• Credit/debit notes (9B)'),
              Text('• Exports'),
              SizedBox(height: 16),
              Text('📅 Due Date: 11th of next month', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('💰 Late Fee: ₹200/day (₹50 if NIL)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.green.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('GOT IT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
