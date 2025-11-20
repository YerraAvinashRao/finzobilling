// lib/screens/gstr3b_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'gstr3b_generator.dart';

// Premium colors
const Color appleBackground = Color(0xFFF2F2F7);
const Color appleCard = Color(0xFFFFFFFF);
const Color appleAccent = Color(0xFF007AFF);

class GSTR3BScreen extends StatefulWidget {
  const GSTR3BScreen({super.key});

  @override
  State<GSTR3BScreen> createState() => _GSTR3BScreenState();
}

class _GSTR3BScreenState extends State<GSTR3BScreen> {
  DateTime _selectedMonth = DateTime.now();
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  // Keep ALL your existing methods EXACTLY as they are
  Future<void> _generateReport() async {
    setState(() => _isLoading = true);

    try {
      final data = await GSTR3BGenerator.generateGSTR3B(month: _selectedMonth);
      if (mounted) {
        setState(() {
          _reportData = data;
        });
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToCSV() async {
    if (_reportData == null) return;

    try {
      List<List<dynamic>> rows = [
        ['GSTR-3B MONTHLY RETURN'],
        ['Period: ${_reportData!['month']}'],
        ['Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'],
        [],
        ['SECTION 3.1: OUTWARD SUPPLIES (SALES)'],
        ['Taxable Value', _reportData!['outwardSupplies']['taxableValue']],
        ['CGST', _reportData!['outwardSupplies']['cgst']],
        ['SGST', _reportData!['outwardSupplies']['sgst']],
        ['IGST', _reportData!['outwardSupplies']['igst']],
        ['Total Tax', _reportData!['outwardSupplies']['totalTax']],
        [],
        ['SECTION 3.2: ITC AVAILABLE (PURCHASES)'],
        ['CGST', _reportData!['itcAvailable']['cgst']],
        ['SGST', _reportData!['itcAvailable']['sgst']],
        ['IGST', _reportData!['itcAvailable']['igst']],
        ['Total ITC', _reportData!['itcAvailable']['total']],
        [],
        ['SECTION 4: TAX PAYABLE'],
        ['CGST', _reportData!['taxPayable']['cgst']],
        ['SGST', _reportData!['taxPayable']['sgst']],
        ['IGST', _reportData!['taxPayable']['igst']],
        ['Total Tax Payable', _reportData!['taxPayable']['total']],
        [],
        ['STATUS'],
        ['Net Position', _reportData!['summary']['netTaxPosition']],
        ['Status', _reportData!['summary']['status']],
      ];

      String csv = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/gstr3b_${DateFormat('yyyyMMdd').format(_selectedMonth)}.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(file.path)], text: 'GSTR-3B Report');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ GSTR-3B exported successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting: $e');
    }
  }

  Future<void> _exportToJSON() async {
    if (_reportData == null) return;

    try {
      final gstin = 'YOUR_GSTIN_HERE';
      final jsonData = GSTR3BGenerator.exportAsJSON(_reportData!, gstin);
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/gstr3b_${DateFormat('yyyyMMdd').format(_selectedMonth)}.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path)], text: 'GSTR-3B JSON for GST Portal');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ JSON exported for GST Portal!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting JSON: $e');
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
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _generateReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      backgroundColor: appleBackground,
      appBar: AppBar(
        title: const Text(
          'GSTR-3B Report',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.red,
        elevation: 0,
        actions: [
          if (_reportData != null) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: PopupMenuButton(
                icon: const Icon(Icons.download_rounded),
                tooltip: 'Export',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'csv',
                    child: Row(
                      children: [
                        Icon(Icons.table_chart_rounded),
                        SizedBox(width: 8),
                        Text('Export CSV'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'json',
                    child: Row(
                      children: [
                        Icon(Icons.code_rounded),
                        SizedBox(width: 8),
                        Text('Export JSON (GST Portal)'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'csv') {
                    _exportToCSV();
                  } else if (value == 'json') {
                    _exportToJSON();
                  }
                },
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
                tooltip: 'About GSTR-3B',
              ),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Generating GSTR-3B...',
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
                      // Critical Alert Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red.shade400, Colors.red.shade600],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.warning_rounded, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '⚠️ CRITICAL DEADLINE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'File by 20th of next month!',
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
                      ),

                      const SizedBox(height: 16),

                      // Header Card
                      Container(
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
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: appleAccent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.account_balance_rounded, color: appleAccent, size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'GSTR-3B for ${_reportData!['month']}',
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Monthly Tax Payment Return',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoTile(
                                      'Invoices',
                                      '${_reportData!['summary']['totalInvoices']}',
                                      Icons.receipt_long_rounded,
                                      Colors.green,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildInfoTile(
                                      'Purchases',
                                      '${_reportData!['summary']['totalPurchases']}',
                                      Icons.shopping_cart_rounded,
                                      Colors.blue,
                                    ),
                                  ),
                                  if (_reportData!['summary']['totalCreditNotes'] > 0)
                                    Expanded(
                                      child: _buildInfoTile(
                                        'Credit Notes',
                                        '${_reportData!['summary']['totalCreditNotes']}',
                                        Icons.remove_circle_rounded,
                                        Colors.orange,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Tax Status Card
                      _buildTaxStatusCard(currency),

                      const SizedBox(height: 20),

                      // Section 3.1: Outward Supplies (Sales)
                      _buildSection(
                        'Section 3.1: Outward Supplies (Sales)',
                        _reportData!['outwardSupplies'],
                        currency,
                        Colors.green,
                        Icons.trending_up_rounded,
                      ),

                      const SizedBox(height: 16),

                      // Section 3.2: ITC Available (Purchases)
                      _buildSection(
                        'Section 3.2: ITC Available (Purchases)',
                        _reportData!['itcAvailable'],
                        currency,
                        Colors.blue,
                        Icons.credit_card_rounded,
                      ),

                      const SizedBox(height: 16),

                      // Section 4: Tax Payable
                      _buildSection(
                        'Section 4: Tax Payable',
                        _reportData!['taxPayable'],
                        currency,
                        Colors.orange,
                        Icons.payment_rounded,
                      ),

                      // ITC Refund (if applicable)
                      if (_reportData!['itcRefund']['total'] > 0) ...[
                        const SizedBox(height: 16),
                        _buildSection(
                          'ITC Refund Due',
                          _reportData!['itcRefund'],
                          currency,
                          Colors.purple,
                          Icons.account_balance_wallet_rounded,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Instructions
                      _buildInstructions(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTaxStatusCard(NumberFormat currency) {
    final summary = _reportData!['summary'];
    final netPosition = summary['netTaxPosition'] as double;
    final status = summary['status'] as String;
    
    final isPayable = status == 'TAX_PAYABLE';
    final color = isPayable ? Colors.red : Colors.green;
    final icon = isPayable ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final label = isPayable ? '💸 Tax Payable' : '💰 Refund Due';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPayable 
              ? [Colors.red.shade400, Colors.red.shade600]
              : [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currency.format(netPosition.abs()),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 24, color: color),
        ),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildSection(
    String title,
    Map<String, dynamic> data,
    NumberFormat currency,
    Color color,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (data['taxableValue'] != null)
                  _buildRow('Taxable Value', data['taxableValue'], currency),
                _buildRow('CGST', data['cgst'], currency),
                _buildRow('SGST', data['sgst'], currency),
                _buildRow('IGST', data['igst'], currency),
                if (data['cess'] != null && data['cess'] > 0)
                  _buildRow('Cess', data['cess'], currency),
                const Divider(height: 24),
                _buildRow(
                  'Total',
                  data['total'] ?? data['totalTax'],
                  currency,
                  isBold: true,
                  color: color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    dynamic value,
    NumberFormat currency, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 16 : 14,
              color: color ?? Colors.grey.shade700,
            ),
          ),
          Text(
            currency.format(value ?? 0),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 16 : 14,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
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
              const Text('Important Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                Text('• GSTR-3B must be filed by 20th of next month', style: TextStyle(fontSize: 13, height: 1.6)),
                Text('• Pay the tax due before filing', style: TextStyle(fontSize: 13, height: 1.6)),
                Text('• Late fee: ₹50/day (₹20/day if nil return)', style: TextStyle(fontSize: 13, height: 1.6)),
                Text('• Interest: 18% p.a. on tax due', style: TextStyle(fontSize: 13, height: 1.6)),
                Text('• File even if no transactions (NIL return)', style: TextStyle(fontSize: 13, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
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
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_rounded, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text('About GSTR-3B'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('GSTR-3B is a monthly summary return where you:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('• Declare outward supplies (sales)'),
              Text('• Claim Input Tax Credit (ITC)'),
              Text('• Calculate tax payable'),
              Text('• Pay the tax due'),
              SizedBox(height: 16),
              Text('This is the MOST IMPORTANT GST return!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              SizedBox(height: 12),
              Text('📅 Due Date: 20th of next month'),
              Text('💰 Late Fee: ₹50/day (CGST) + ₹50/day (SGST)'),
              Text('📈 Interest: 18% p.a. on delayed payment'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
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
