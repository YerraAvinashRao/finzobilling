import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart'; // ✅ ADD THIS LINE

class PdfInvoiceApi {
  static pw.Font? get robotoRegular => pw.Font.helvetica();

  /// Generate and save invoice PDF
  static Future<File?> generateAndSaveInvoice({
    required String invoiceNumber,
    required Map<String, dynamic>? supplier,
    required Map<String, dynamic>? customer,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required Timestamp timestamp,
    required double taxableValue,
    required double totalTax,
    required DateTime createdAt,
  }) async {
    try {
      print('📄 Starting PDF generation for invoice: $invoiceNumber');

      // ✅ STEP 1: Request proper permissions based on Android version
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        
        print('📱 Android SDK: $sdkInt');
        
        if (sdkInt >= 30) {
          // Android 11+ (API 30+): Use MANAGE_EXTERNAL_STORAGE
          final status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            print('❌ MANAGE_EXTERNAL_STORAGE permission denied');
            
            // Fallback: Try to open app settings
            await openAppSettings();
            return null;
          }
          print('✅ MANAGE_EXTERNAL_STORAGE permission granted');
        } else {
          // Android 10 and below: Use WRITE_EXTERNAL_STORAGE
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            print('❌ Storage permission denied');
            return null;
          }
          print('✅ Storage permission granted');
        }
      }

      // ✅ STEP 2: Generate PDF content
      final pdf = pw.Document();
      final date = DateFormat('dd-MM-yyyy').format(timestamp.toDate());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(
            base: robotoRegular,
            bold: pw.Font.helveticaBold(),
            italic: pw.Font.helveticaOblique(),
          ),
          build: (context) => [
            _buildHeader(invoiceNumber, supplier, customer, date),
            pw.SizedBox(height: 20),
            _buildInvoiceTable(items),
            pw.SizedBox(height: 10),
            _buildTaxBreakdown(taxableValue, totalTax, items),
            pw.Divider(thickness: 2),
            _buildTotal(totalAmount),
            pw.SizedBox(height: 30),
            _buildFooter(supplier),
          ],
        ),
      );

      final bytes = await pdf.save();
      print('✅ PDF bytes generated: ${bytes.length} bytes');

      // ✅ STEP 3: Determine save location
      Directory? directory;
      String fileName = 'Invoice_${invoiceNumber.replaceAll('/', '_')}.pdf';

      if (Platform.isAndroid) {
        // Try multiple paths in order of preference
        final possiblePaths = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Documents',
          '/storage/emulated/0/Documents/FinzoBilling',
        ];

        for (String path in possiblePaths) {
          final dir = Directory(path);
          if (await dir.exists()) {
            directory = dir;
            print('✅ Using directory: $path');
            break;
          } else {
            print('⚠️ Directory not found: $path');
            // Try to create Documents/FinzoBilling
            if (path.contains('FinzoBilling')) {
              try {
                directory = await dir.create(recursive: true);
                print('✅ Created directory: $path');
                break;
              } catch (e) {
                print('❌ Could not create directory: $e');
              }
            }
          }
        }

        // Fallback to app-specific directory (always works)
        if (directory == null) {
          directory = await getExternalStorageDirectory();
          print('⚠️ Using app-specific directory: ${directory?.path}');
        }
      } else {
        // iOS: Use app documents directory
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        print('❌ Could not find valid directory');
        return null;
      }

      // ✅ STEP 4: Save file
      final file = File('${directory.path}/$fileName');
      print('📝 Saving to: ${file.path}');

      await file.writeAsBytes(bytes, flush: true);
      
      // Verify file was created
      if (await file.exists()) {
        print('✅ PDF saved successfully!');
        print('📍 Location: ${file.path}');
        print('📏 Size: ${await file.length()} bytes');
        return file;
      } else {
        print('❌ File was not created');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Error generating invoice: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Build header section
  static pw.Widget _buildHeader(
    String invoiceNumber,
    Map<String, dynamic>? supplier,
    Map<String, dynamic>? customer,
    String date,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Title
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'TAX INVOICE',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue700,
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Invoice #: $invoiceNumber',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 15),
        pw.Divider(thickness: 2, color: PdfColors.blue700),
        pw.SizedBox(height: 15),

        // Supplier and Customer in two columns
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Supplier (From)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'FROM',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    supplier?['name'] ?? supplier?['businessName'] ?? 'Business Name',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  if (supplier?['address'] != null)
                    pw.Text(
                      supplier!['address'],
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  if (supplier?['city'] != null && supplier?['state'] != null)
                    pw.Text(
                      '${supplier!['city']}, ${supplier['state']}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  if (supplier?['gstin'] != null)
                    pw.Text(
                      'GSTIN: ${supplier!['gstin']}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  if (supplier?['phone'] != null)
                    pw.Text(
                      'Phone: ${supplier!['phone']}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                ],
              ),
            ),

            pw.SizedBox(width: 20),

            // Customer (To)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'BILL TO',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    customer?['name'] ?? customer?['clientName'] ?? 'Customer Name',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  if (customer?['address'] != null && customer!['address'].toString().isNotEmpty)
                    pw.Text(
                      customer['address'],
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  if (customer?['city'] != null && customer?['state'] != null)
                    pw.Text(
                      '${customer!['city']}, ${customer['state']}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  if (customer?['gstin'] != null && customer!['gstin'].toString().isNotEmpty)
                    pw.Text(
                      'GSTIN: ${customer['gstin']}',
                      style: const pw.TextStyle(fontSize: 9),
                    )
                  else
                    pw.Text(
                      'Customer Type: B2C',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey600,
                      ),
                    ),
                  if (customer?['phone'] != null && customer!['phone'].toString().isNotEmpty)
                    pw.Text(
                      'Phone: ${customer['phone']}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 15),
        pw.Divider(thickness: 1),
      ],
    );
  }

  /// Build invoice table
  static pw.Widget _buildInvoiceTable(List<Map<String, dynamic>> items) {
    return pw.Table.fromTextArray(
      headers: ['#', 'Item', 'HSN/SAC', 'Qty', 'Rate', 'Tax%', 'Amount'],
      data: List.generate(items.length, (index) {
        final item = items[index];
        final qty = item['quantity'] ?? 0;
        final rate = item['price'] ?? item['rate'] ?? 0;
        final taxRate = ((item['taxRate'] ?? 0) * 100).toStringAsFixed(1);
        final amount = item['taxableAmount'] ?? (qty * rate);

        return [
          '${index + 1}',
          item['productName'] ?? 'N/A',
          item['hsnSac'] ?? '',
          '$qty',
          '₹${rate.toStringAsFixed(2)}',
          '$taxRate%',
          '₹${amount.toStringAsFixed(2)}',
        ];
      }),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(
        color: PdfColors.blue700,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      border: pw.TableBorder.all(color: PdfColors.grey400),
      cellPadding: const pw.EdgeInsets.all(4),
      columnWidths: {
        0: const pw.FixedColumnWidth(25),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(40),
        4: const pw.FixedColumnWidth(60),
        5: const pw.FixedColumnWidth(40),
        6: const pw.FixedColumnWidth(70),
      },
    );
  }

  /// Build tax breakdown
  static pw.Widget _buildTaxBreakdown(
    double taxableValue,
    double totalTax,
    List<Map<String, dynamic>> items,
  ) {
    // Calculate totals
    double totalCGST = 0;
    double totalSGST = 0;
    double totalIGST = 0;

    for (var item in items) {
      totalCGST += (item['cgst'] as num?)?.toDouble() ?? 0;
      totalSGST += (item['sgst'] as num?)?.toDouble() ?? 0;
      totalIGST += (item['igst'] as num?)?.toDouble() ?? 0;
    }

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 250,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Column(
          children: [
            _buildSummaryRow('Taxable Value', taxableValue),
            if (totalCGST > 0) ...[
              pw.SizedBox(height: 4),
              _buildSummaryRow('CGST', totalCGST, color: PdfColors.blue),
              pw.SizedBox(height: 4),
              _buildSummaryRow('SGST', totalSGST, color: PdfColors.blue),
            ],
            if (totalIGST > 0) ...[
              pw.SizedBox(height: 4),
              _buildSummaryRow('IGST', totalIGST, color: PdfColors.blue),
            ],
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, double value, {PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            color: color,
          ),
        ),
        pw.Text(
          '₹${value.toStringAsFixed(2)}',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Build total section
  static pw.Widget _buildTotal(double totalAmount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.green50,
            border: pw.Border.all(color: PdfColors.green700, width: 2),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'GRAND TOTAL',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '₹${totalAmount.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 20,
                  color: PdfColors.green900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build footer section
  static pw.Widget _buildFooter(Map<String, dynamic>? supplier) {
    final upiId = supplier?['upiId'] ?? '';
    final businessName = supplier?['name'] ?? supplier?['businessName'] ?? '';
    final terms = supplier?['terms'] ?? 'Thank you for your business!';
    
    final upiLink = upiId.isNotEmpty
        ? 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&cu=INR'
        : null;

    return pw.Column(
      children: [
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 10),

        if (upiLink != null)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Payment Options',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('UPI ID: $upiId', style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 2),
                  if (supplier?['bankName'] != null)
                    pw.Text('Bank: ${supplier!['bankName']}', style: const pw.TextStyle(fontSize: 9)),
                  if (supplier?['accountNumber'] != null)
                    pw.Text('A/C: ${supplier!['accountNumber']}', style: const pw.TextStyle(fontSize: 9)),
                  if (supplier?['ifsc'] != null)
                    pw.Text('IFSC: ${supplier!['ifsc']}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text(
                    'Scan to Pay',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: upiLink,
                    width: 70,
                    height: 70,
                  ),
                ],
              ),
            ],
          ),

        pw.SizedBox(height: 15),

        // Terms & Conditions
        if (terms.isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Terms & Conditions',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  terms,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),

        pw.SizedBox(height: 10),
        
        // Footer note
        pw.Center(
          child: pw.Text(
            'This is a computer-generated invoice and does not require a signature',
            style: pw.TextStyle(
              fontSize: 8,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey600,
            ),
          ),
        ),
      ],
    );
  }

  /// Share invoice PDF
  static Future<void> shareInvoice(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Invoice from FinzoBilling',
        text: 'Please find the attached invoice',
      );
    } catch (e) {
      print('❌ Error sharing invoice: $e');
    }
  }

  /// Print invoice PDF
  static Future<void> printInvoice(File file) async {
    try {
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(
        onLayout: (_) => bytes,
      );
    } catch (e) {
      print('❌ Error printing invoice: $e');
    }
  }

  /// Share PDF with custom text
  static Future<void> sharePdf(File pdfFile, {required String text}) async {
    try {
      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text: text,
      );
    } catch (e) {
      print('❌ Error sharing PDF: $e');
    }
  }
}
