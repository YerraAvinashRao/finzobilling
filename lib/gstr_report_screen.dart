import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'gstr_export_helper.dart';

// Premium colors
const Color appleBackground = Color(0xFFF2F2F7);
const Color appleCard = Color(0xFFFFFFFF);
const Color appleAccent = Color(0xFF007AFF);

class GSTRReportScreen extends StatefulWidget {
  const GSTRReportScreen({super.key});

  @override
  State<GSTRReportScreen> createState() => _GSTRReportScreenState();
}

class _GSTRReportScreenState extends State<GSTRReportScreen> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);

    try {
      final data = await GSTRExportHelper.generateGSTR2AData(
        fromDate: _fromDate,
        toDate: _toDate,
      );
      
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToCSV() async {
    setState(() => _isLoading = true);

    try {
      final csv = await GSTRExportHelper.exportToCSV(
        fromDate: _fromDate,
        toDate: _toDate,
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'GSTR2A_${DateFormat('yyyyMMdd').format(_fromDate)}_${DateFormat('yyyyMMdd').format(_toDate)}.csv';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(csv);

      if (mounted) {
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'GSTR-2A Report',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ CSV exported successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _generateReport();
    }
  }

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      backgroundColor: appleBackground,
      appBar: AppBar(
        title: const Text(
          'GSTR-2A Report',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: appleCard,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: appleAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(Icons.calendar_month_rounded, color: appleAccent),
              onPressed: _selectDateRange,
              tooltip: 'Select Date Range',
            ),
          ),
          if (_reportData != null)
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.green),
                onPressed: _exportToCSV,
                tooltip: 'Export CSV',
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Generating report...',
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
                      Icon(Icons.inbox_rounded, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No data available',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select a date range to generate report',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Period Header Card
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [appleAccent, appleAccent.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: appleAccent.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
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
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_today_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Report Period',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _reportData!['period'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.receipt_long_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_reportData!['totalRecords']} Purchase Records',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Taxable Value',
                              currency.format(double.parse(_reportData!['totalTaxableValue'])),
                              Colors.blue,
                              Icons.account_balance_wallet_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Total ITC',
                              currency.format(double.parse(_reportData!['totalITC'])),
                              Colors.green,
                              Icons.savings_rounded,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'CGST',
                              currency.format(double.parse(_reportData!['totalCGST'])),
                              Colors.orange,
                              Icons.trending_up_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'SGST',
                              currency.format(double.parse(_reportData!['totalSGST'])),
                              Colors.deepOrange,
                              Icons.trending_up_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'IGST',
                              currency.format(double.parse(_reportData!['totalIGST'])),
                              Colors.purple,
                              Icons.public_rounded,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Entries Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: appleAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.list_alt_rounded, color: appleAccent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Purchase Entries',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Entries List
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: (_reportData!['entries'] as List).length,
                        itemBuilder: (context, index) {
                          final entry = (_reportData!['entries'] as List)[index];
                          
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: appleAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.business_rounded, color: appleAccent, size: 24),
                              ),
                              title: Text(
                                entry['supplierName'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.receipt_rounded, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      entry['invoiceNumber'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      entry['invoiceDate'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: appleBackground,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildDetailRow('GSTIN', entry['supplierGstin'], Icons.badge_rounded),
                                      _buildDetailRow('Taxable Value', '₹${entry['taxableValue']}', Icons.attach_money_rounded),
                                      _buildDetailRow('CGST', '₹${entry['cgst']}', Icons.trending_up_rounded),
                                      _buildDetailRow('SGST', '₹${entry['sgst']}', Icons.trending_up_rounded),
                                      _buildDetailRow('IGST', '₹${entry['igst']}', Icons.public_rounded),
                                      _buildDetailRow('Total Tax', '₹${entry['totalTax']}', Icons.calculate_rounded, isHighlight: true),
                                      const Divider(height: 20),
                                      _buildDetailRow('Reverse Charge', entry['reverseCharge'], Icons.swap_horiz_rounded),
                                      _buildDetailRow('ITC Eligible', entry['itcEligible'], Icons.check_circle_rounded),
                                      _buildDetailRow('Place of Supply', entry['placeOfSupply'], Icons.location_on_rounded),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isHighlight ? Colors.green : Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
              color: isHighlight ? Colors.green : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
