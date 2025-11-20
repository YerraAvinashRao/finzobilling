// Premium GSTR-1A Screen with Apple-style UI
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../services/gstr1a_generator.dart';

// Premium colors
const Color appleBackground = Color(0xFFF2F2F7);
const Color appleCard = Color(0xFFFFFFFF);
const Color appleAccent = Color(0xFF007AFF);

class GSTR1AScreen extends StatefulWidget {
  const GSTR1AScreen({super.key});

  @override
  State<GSTR1AScreen> createState() => _GSTR1AScreenState();
}

class _GSTR1AScreenState extends State<GSTR1AScreen> {
  DateTime _selectedMonth = DateTime.now();
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);

    try {
      final data = await GSTR1AGenerator.generateGSTR1A(month: _selectedMonth);
      if (mounted) {
        setState(() => _reportData = data);
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

  Future<void> _exportToJSON() async {
    if (_reportData == null) return;

    try {
      final jsonData = GSTR1AGenerator.exportAsJSON(_reportData!);
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/gstr1a_${DateFormat('yyyyMMdd').format(_selectedMonth)}.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path)], text: 'GSTR-1A JSON for GST Portal');

      // Clear flags after export
      await GSTR1AGenerator.clearGSTR1AFlags(_selectedMonth);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ GSTR-1A JSON exported! Upload to GST Portal'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
        _generateReport(); // Refresh
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
          'GSTR-1A Amendments',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.purple,
        elevation: 0,
        actions: [
          if (_reportData != null && _reportData!['summary']['totalAmendments'] > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.download_rounded),
                onPressed: _exportToJSON,
                tooltip: 'Export JSON',
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 12),
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
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.purple),
                  const SizedBox(height: 16),
                  Text(
                    'Loading amendments...',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : _reportData == null
              ? const Center(child: Text('No data available'))
              : _reportData!['summary']['totalAmendments'] == 0
                  ? _buildNoAmendmentsView()
                  : _buildAmendmentsView(currency),
    );
  }

  Widget _buildNoAmendmentsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 80,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Amendments Needed!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'All invoices for ${DateFormat('MMM yyyy').format(_selectedMonth)} are already in GSTR-1.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'GSTR-1A is only needed if you add/edit invoices after filing GSTR-1',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
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

  Widget _buildAmendmentsView(NumberFormat currency) {
    return RefreshIndicator(
      onRefresh: _generateReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Alert Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.purple.shade600],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
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
                  child: const Icon(Icons.error_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠️ ACTION REQUIRED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'File GSTR-1A before GSTR-3B deadline!',
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit_document, color: Colors.purple, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GSTR-1A for ${_reportData!['period']}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Amendments to filed GSTR-1',
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
                      child: _buildSummaryTile(
                        'Amendments',
                        '${_reportData!['summary']['totalAmendments']}',
                        Icons.edit_note_rounded,
                        Colors.purple,
                      ),
                    ),
                    Expanded(
                      child: _buildSummaryTile(
                        'Total Value',
                        currency.format(_reportData!['summary']['totalValue']),
                        Icons.currency_rupee_rounded,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Tax Summary
          _buildTaxSummaryCard(currency),

          const SizedBox(height: 20),

          // Category Cards
          if (_reportData!['b2b']['count'] > 0)
            _buildCategorySection(
              'B2B Amendments',
              _reportData!['b2b']['amendments'],
              currency,
              Colors.blue,
              Icons.business_rounded,
            ),

          if (_reportData!['b2cLarge']['count'] > 0) ...[
            const SizedBox(height: 16),
            _buildCategorySection(
              'B2C Large Amendments',
              _reportData!['b2cLarge']['amendments'],
              currency,
              Colors.orange,
              Icons.shopping_bag_rounded,
            ),
          ],

          if (_reportData!['b2cSmall']['count'] > 0) ...[
            const SizedBox(height: 16),
            _buildCategorySection(
              'B2C Small Amendments',
              _reportData!['b2cSmall']['amendments'],
              currency,
              Colors.purple,
              Icons.shopping_cart_rounded,
            ),
          ],

          const SizedBox(height: 20),

          // Instructions
          _buildInstructions(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSummaryTile(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTaxSummaryCard(NumberFormat currency) {
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

  Widget _buildCategorySection(
    String title,
    List<dynamic> amendments,
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${amendments.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: amendments.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              final amendment = amendments[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: amendment['amendmentType'] == 'AMENDED' 
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    amendment['amendmentType'] == 'AMENDED' 
                        ? Icons.edit_rounded
                        : Icons.add_rounded,
                    color: amendment['amendmentType'] == 'AMENDED' 
                        ? Colors.orange
                        : Colors.green,
                    size: 20,
                  ),
                ),
                title: Text(
                  amendment['invoiceNumber'],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(amendment['clientName']),
                    Text(
                      DateFormat('dd/MM/yyyy').format(amendment['invoiceDate']),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                trailing: Text(
                  currency.format(amendment['totalAmount']),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color,
                  ),
                ),
              );
            },
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
              const Text('How to File GSTR-1A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                Text('1. Export JSON using the download button above', style: TextStyle(fontSize: 13, height: 1.6)),
                Text('2. Login to GST Portal (gst.gov.in)', style: TextStyle(fontSize: 13, height: 1.6)),
                Text('3. Go to Returns > GSTR-1A', style: TextStyle(fontSize: 13, height: 1.6)),
                Text('4. Upload the JSON file', style: TextStyle(fontSize: 13, height: 1.6)),
                Text('5. Submit before filing GSTR-3B!', style: TextStyle(fontSize: 13, height: 1.6, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
