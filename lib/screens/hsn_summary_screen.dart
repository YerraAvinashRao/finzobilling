import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class HSNSummaryReportScreen extends StatefulWidget {
  const HSNSummaryReportScreen({super.key});

  @override
  State<HSNSummaryReportScreen> createState() => _HSNSummaryReportScreenState();
}

class _HSNSummaryReportScreenState extends State<HSNSummaryReportScreen> {
  DateTime startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime endDate = DateTime.now();
  bool isLoading = false;
  List<Map<String, dynamic>> hsnData = [];
  String? userId;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _generateReport();
    }
  }

  // ✅ GENERATE HSN SUMMARY - GSTR-1 TABLE 12 FORMAT
  Future<void> _generateReport() async {
    if (userId == null) return;

    setState(() {
      isLoading = true;
      hsnData = [];
    });

    try {
      final startTimestamp = Timestamp.fromDate(startDate);
      final endTimestamp = Timestamp.fromDate(endDate.add(const Duration(days: 1)));

      // ✅ Fetch all invoices in date range
      final invoicesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('invoices')
          .where('invoiceDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('invoiceDate', isLessThan: endTimestamp)
          .where('status', whereIn: ['Paid', 'Unpaid', 'Partially Paid'])
          .get();

      // ✅ NEW: Filter out amended invoices (use corrected ones only)
      final validInvoices = invoicesSnapshot.docs.where((doc) {
        final data = doc.data();
        final isAmended = data['isAmended'] as bool? ?? false;
        return !isAmended; // Exclude amended originals
      }).toList();

      debugPrint('📊 HSN Summary: Found ${invoicesSnapshot.docs.length} invoices (${validInvoices.length} valid after excluding amended)');

      // ✅ Group by HSN Code
      Map<String, Map<String, dynamic>> hsnGroups = {};

      // ✅ UPDATED: Use validInvoices instead of invoicesSnapshot.docs
      for (var doc in validInvoices) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];

        for (var item in items) {
          final hsnCode = (item['hsnSac'] ?? item['hsnCode'] ?? 'UNCLASSIFIED').toString().trim();

          final productName = (item['productName'] ?? item['name'] ?? 'Unknown Product').toString();
          final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
          final rate = (item['price'] ?? item['rate'] as num?)?.toDouble() ?? 0.0;
          final taxRate = (item['taxRate'] ?? item['gstRate'] as num?)?.toDouble() ?? 0.0;

          final amount = quantity * rate;
          final taxAmount = amount * (taxRate / 100);

          // Determine if inter-state or intra-state
          final igstValue = (data['igst'] as num?)?.toDouble() ?? 0;
          final isInterState = igstValue > 0;

          if (!hsnGroups.containsKey(hsnCode)) {
            hsnGroups[hsnCode] = {
              'hsnCode': hsnCode,
              'description': productName,
              'uqc': item['unit'] ?? 'PCS',
              'totalQuantity': 0.0,
              'totalValue': 0.0,
              'taxableValue': 0.0,
              'cgst': 0.0,
              'sgst': 0.0,
              'igst': 0.0,
              'totalTax': 0.0,
              'taxRate': taxRate,
            };
          }

          hsnGroups[hsnCode]!['totalQuantity'] = 
              (hsnGroups[hsnCode]!['totalQuantity'] as double) + quantity;
          hsnGroups[hsnCode]!['taxableValue'] = 
              (hsnGroups[hsnCode]!['taxableValue'] as double) + amount;

          if (isInterState) {
            hsnGroups[hsnCode]!['igst'] = 
                (hsnGroups[hsnCode]!['igst'] as double) + taxAmount;
          } else {
            hsnGroups[hsnCode]!['cgst'] = 
                (hsnGroups[hsnCode]!['cgst'] as double) + (taxAmount / 2);
            hsnGroups[hsnCode]!['sgst'] = 
                (hsnGroups[hsnCode]!['sgst'] as double) + (taxAmount / 2);
          }
          
          hsnGroups[hsnCode]!['totalTax'] = 
              (hsnGroups[hsnCode]!['totalTax'] as double) + taxAmount;
          hsnGroups[hsnCode]!['totalValue'] = 
              (hsnGroups[hsnCode]!['taxableValue'] as double) + 
              (hsnGroups[hsnCode]!['totalTax'] as double);
        }
      }

      setState(() {
        hsnData = hsnGroups.values.toList();
        hsnData.sort((a, b) => (a['hsnCode'] as String).compareTo(b['hsnCode'] as String));
      });
    } catch (e) {
      debugPrint('Error generating HSN summary: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ✅ EXPORT TO CSV
  Future<void> _exportToCSV() async {
    try {
      List<List<dynamic>> rows = [
        ['HSN SUMMARY REPORT - GSTR-1 TABLE 12'],
        ['Period: ${DateFormat('dd/MM/yyyy').format(startDate)} to ${DateFormat('dd/MM/yyyy').format(endDate)}'],
        ['Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'],
        [],
        [
          'HSN Code',
          'Description',
          'UQC',
          'Total Quantity',
          'Taxable Value',
          'CGST',
          'SGST',
          'IGST',
          'Total Tax',
          'Total Value'
        ],
      ];

      double totalTaxableValue = 0;
      double totalCGST = 0;
      double totalSGST = 0;
      double totalIGST = 0;
      double totalTax = 0;
      double grandTotal = 0;

      for (var hsn in hsnData) {
        rows.add([
          hsn['hsnCode'],
          hsn['description'],
          hsn['uqc'],
          hsn['totalQuantity'].toStringAsFixed(2),
          hsn['taxableValue'].toStringAsFixed(2),
          hsn['cgst'].toStringAsFixed(2),
          hsn['sgst'].toStringAsFixed(2),
          hsn['igst'].toStringAsFixed(2),
          hsn['totalTax'].toStringAsFixed(2),
          hsn['totalValue'].toStringAsFixed(2),
        ]);

        totalTaxableValue += hsn['taxableValue'] as double;
        totalCGST += hsn['cgst'] as double;
        totalSGST += hsn['sgst'] as double;
        totalIGST += hsn['igst'] as double;
        totalTax += hsn['totalTax'] as double;
        grandTotal += hsn['totalValue'] as double;
      }

      rows.add([]);
      rows.add([
        'TOTAL',
        '',
        '',
        '',
        totalTaxableValue.toStringAsFixed(2),
        totalCGST.toStringAsFixed(2),
        totalSGST.toStringAsFixed(2),
        totalIGST.toStringAsFixed(2),
        totalTax.toStringAsFixed(2),
        grandTotal.toStringAsFixed(2),
      ]);

      String csv = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/hsn_summary_${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}.csv',
      );
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'HSN Summary Report',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ HSN Summary exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting CSV: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ✅ EXPORT TO PDF
  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('HSN SUMMARY REPORT', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Text('GSTR-1 TABLE 12 - HSN-WISE SUMMARY OF OUTWARD SUPPLIES'),
                  pw.Text('Period: ${DateFormat('dd/MM/yyyy').format(startDate)} to ${DateFormat('dd/MM/yyyy').format(endDate)}'),
                  pw.Divider(),
                ],
              ),
            ),
            pw.TableHelper.fromTextArray(
              headers: ['HSN', 'Description', 'UQC', 'Qty', 'Taxable Value', 'CGST', 'SGST', 'IGST', 'Total Tax', 'Total Value'],
              data: hsnData.map((hsn) => [
                hsn['hsnCode'],
                hsn['description'],
                hsn['uqc'],
                hsn['totalQuantity'].toStringAsFixed(2),
                hsn['taxableValue'].toStringAsFixed(2),
                hsn['cgst'].toStringAsFixed(2),
                hsn['sgst'].toStringAsFixed(2),
                hsn['igst'].toStringAsFixed(2),
                hsn['totalTax'].toStringAsFixed(2),
                hsn['totalValue'].toStringAsFixed(2),
              ]).toList(),
              cellAlignment: pw.Alignment.centerRight,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
              },
            ),
          ],
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/hsn_summary_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'HSN Summary Report');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ PDF exported successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ✅ DATE RANGE SELECTOR
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      _generateReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    
    // Calculate totals
    double totalTaxableValue = hsnData.fold(0, (sum, hsn) => sum + (hsn['taxableValue'] as double));
    double totalCGST = hsnData.fold(0, (sum, hsn) => sum + (hsn['cgst'] as double));
    double totalSGST = hsnData.fold(0, (sum, hsn) => sum + (hsn['sgst'] as double));
    double totalIGST = hsnData.fold(0, (sum, hsn) => sum + (hsn['igst'] as double));
    double totalTax = hsnData.fold(0, (sum, hsn) => sum + (hsn['totalTax'] as double));
    double grandTotal = hsnData.fold(0, (sum, hsn) => sum + (hsn['totalValue'] as double));

    return Scaffold(
      appBar: AppBar(
        title: const Text('HSN Summary Report'),
        actions: [
          if (hsnData.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.table_chart),
              tooltip: 'Export CSV',
              onPressed: _exportToCSV,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export PDF',
              onPressed: _exportToPDF,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Date Range Selector
          Card(
            margin: const EdgeInsets.all(16),
            child: ListTile(
              leading: const Icon(Icons.date_range),
              title: Text(
                '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Tap to change period'),
              trailing: const Icon(Icons.edit),
              onTap: _selectDateRange,
            ),
          ),

          // Summary Cards
          if (hsnData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total HSN Codes',
                      hsnData.length.toString(),
                      Icons.qr_code,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Value',
                      currency.format(grandTotal),
                      Icons.currency_rupee,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // HSN Data Table
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : hsnData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No data for selected period',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                              border: TableBorder.all(color: Colors.grey.shade300),
                              columns: const [
                                DataColumn(label: Text('HSN\nCode', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('UQC', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                DataColumn(label: Text('Taxable\nValue', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                DataColumn(label: Text('CGST', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                DataColumn(label: Text('SGST', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                DataColumn(label: Text('IGST', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                DataColumn(label: Text('Total\nTax', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                DataColumn(label: Text('Total\nValue', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                              ],
                              rows: [
                                ...hsnData.map((hsn) => DataRow(
                                  cells: [
                                    DataCell(Text(hsn['hsnCode'])),
                                    DataCell(Text(hsn['description'])),
                                    DataCell(Text(hsn['uqc'])),
                                    DataCell(Text(hsn['totalQuantity'].toStringAsFixed(2))),
                                    DataCell(Text(currency.format(hsn['taxableValue']))),
                                    DataCell(Text(currency.format(hsn['cgst']))),
                                    DataCell(Text(currency.format(hsn['sgst']))),
                                    DataCell(Text(currency.format(hsn['igst']))),
                                    DataCell(Text(currency.format(hsn['totalTax']))),
                                    DataCell(Text(currency.format(hsn['totalValue']), style: const TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                )),
                                // Total Row
                                DataRow(
                                  color: WidgetStateProperty.all(Colors.grey.shade200),
                                  cells: [
                                    const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    DataCell(Text(currency.format(totalTaxableValue), style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(currency.format(totalCGST), style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(currency.format(totalSGST), style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(currency.format(totalIGST), style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(currency.format(totalTax), style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(currency.format(grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
