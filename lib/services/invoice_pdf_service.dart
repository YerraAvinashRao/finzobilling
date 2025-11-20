import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' as material;
import '../models/invoice_settings.dart';

class InvoicePdfService {
  static final InvoicePdfService _instance = InvoicePdfService._internal();
  factory InvoicePdfService() => _instance;
  InvoicePdfService._internal();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  Future<pw.Document> generateInvoicePdf({
    required Map<String, dynamic> invoiceData,
    required Map<String, dynamic> businessData,
    required InvoiceSettings settings,
  }) async {
    final pdf = pw.Document();

    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    pw.MemoryImage? logoImage;
    if (settings.logoPath != null && settings.logoPath!.isNotEmpty) {
      try {
        final logoFile = File(settings.logoPath!);
        if (await logoFile.exists()) {
          final logoBytes = await logoFile.readAsBytes();
          logoImage = pw.MemoryImage(logoBytes);
        }
      } catch (e) {
        material.debugPrint('❌ Error loading logo: $e');
      }
    }

    pw.MemoryImage? signatureImage;
    if (settings.signaturePath != null && settings.signaturePath!.isNotEmpty) {
      try {
        final signFile = File(settings.signaturePath!);
        if (await signFile.exists()) {
          final signBytes = await signFile.readAsBytes();
          signatureImage = pw.MemoryImage(signBytes);
        }
      } catch (e) {
        material.debugPrint('❌ Error loading signature: $e');
      }
    }

    Uint8List? qrCodeBytes;
    if (settings.showQRCode && businessData['upiId'] != null && businessData['upiId'].toString().isNotEmpty) {
      try {
        final totalAmount = invoiceData['totalAmount'] as double?;
        final upiString = _generateUPIString(
          businessData['upiId'].toString(),
          businessData['name'] as String? ?? 'Business',
          totalAmount ?? 0.0,
        );
        qrCodeBytes = await _generateQRCode(upiString);
      } catch (e) {
        material.debugPrint('❌ Error generating QR code: $e');
      }
    }

    final primaryColor = _parseColor(settings.primaryColor);
    final secondaryColor = _parseColor(settings.secondaryColor);

    final isB2B = invoiceData['clientGstin'] != null && 
                  (invoiceData['clientGstin'] as String).isNotEmpty;
    final invoiceTitle = isB2B ? 'TAX INVOICE' : 'INVOICE';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return [
            _buildHeader(
              invoiceTitle: invoiceTitle,
              invoiceNumber: invoiceData['invoiceNumber'] as String? ?? '',
              invoiceDate: invoiceData['invoiceDate'],
              businessData: businessData,
              logoImage: logoImage,
              primaryColor: primaryColor,
              settings: settings,
            ),

            pw.SizedBox(height: 20),

            _buildPartiesSection(
              invoiceData: invoiceData,
              isB2B: isB2B,
              secondaryColor: secondaryColor,
            ),

            pw.SizedBox(height: 20),

            _buildItemsTable(
              lineItems: invoiceData['lineItems'] as List<dynamic>? ?? [],
              primaryColor: primaryColor,
            ),

            pw.SizedBox(height: 20),

            _buildTotalsSection(
              invoiceData: invoiceData,
              isInterState: invoiceData['isInterState'] as bool? ?? false,
              primaryColor: primaryColor,
            ),

            pw.SizedBox(height: 20),

            _buildFooterSection(
              settings: settings,
              businessData: businessData,  // ✅ ADD THIS LINE
              qrCodeBytes: qrCodeBytes,
              signatureImage: signatureImage,
              secondaryColor: secondaryColor,
            ),


            if (settings.showWatermark)
              _buildWatermark(settings.watermarkText),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader({
    required String invoiceTitle,
    required String invoiceNumber,
    required dynamic invoiceDate,
    required Map<String, dynamic> businessData,
    required pw.MemoryImage? logoImage,
    required PdfColor primaryColor,
    required InvoiceSettings settings,
  }) {
    final formattedDate = _formatDate(invoiceDate);

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: primaryColor, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoImage != null)
                  pw.Image(logoImage, width: 100, height: 60, fit: pw.BoxFit.contain),
                if (logoImage != null) pw.SizedBox(height: 10),
                pw.Text(
                  businessData['name'] as String? ?? 'Business Name',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.SizedBox(height: 5),
                if (businessData['address'] != null)
                  pw.Text(
                    businessData['address'] as String,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                if (businessData['city'] != null && businessData['state'] != null)
                  pw.Text(
                    '${businessData['city']}, ${businessData['state']} - ${businessData['pincode'] ?? ''}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                if (businessData['gstin'] != null)
                  pw.Text(
                    'GSTIN: ${businessData['gstin']}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                if (businessData['phone'] != null)
                  pw.Text(
                    'Phone: ${businessData['phone']}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
              ],
            ),
          ),

          pw.Expanded(
            flex: 1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                  ),
                  child: pw.Text(
                    invoiceTitle,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Invoice #',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
                pw.Text(
                  invoiceNumber,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Date',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
                pw.Text(
                  formattedDate,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPartiesSection({
    required Map<String, dynamic> invoiceData,
    required bool isB2B,
    required PdfColor secondaryColor,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              color: PdfColors.grey100,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BILL TO',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: secondaryColor,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  invoiceData['clientName'] as String? ?? 'Customer',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                if (invoiceData['clientAddress'] != null)
                  pw.Text(
                    invoiceData['clientAddress'] as String,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                if (invoiceData['clientState'] != null)
                  pw.Text(
                    'State: ${invoiceData['clientState']}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                if (isB2B && invoiceData['clientGstin'] != null)
                  pw.Text(
                    'GSTIN: ${invoiceData['clientGstin']}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                if (invoiceData['clientPhone'] != null)
                  pw.Text(
                    'Phone: ${invoiceData['clientPhone']}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
              ],
            ),
          ),
        ),

        pw.SizedBox(width: 15),

        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              color: PdfColors.grey100,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PLACE OF SUPPLY',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: secondaryColor,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  invoiceData['placeOfSupply'] as String? ?? invoiceData['clientState'] as String? ?? 'N/A',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                if (invoiceData['clientStateCode'] != null)
                  pw.Text(
                    'State Code: ${invoiceData['clientStateCode']}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildItemsTable({
    required List<dynamic> lineItems,
    required PdfColor primaryColor,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(60),
        3: const pw.FixedColumnWidth(40),
        4: const pw.FixedColumnWidth(60),
        5: const pw.FixedColumnWidth(50),
        6: const pw.FixedColumnWidth(70),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: primaryColor),
          children: [
            _tableCell('#', isHeader: true),
            _tableCell('Item Description', isHeader: true),
            _tableCell('HSN/SAC', isHeader: true),
            _tableCell('Qty', isHeader: true),
            _tableCell('Rate', isHeader: true),
            _tableCell('Tax %', isHeader: true),
            _tableCell('Amount', isHeader: true),
          ],
        ),

        ...lineItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value as Map<String, dynamic>;
          
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: index.isEven ? PdfColors.white : PdfColors.grey50,
            ),
            children: [
              _tableCell('${index + 1}'),
              _tableCell(item['productName'] as String? ?? '', align: pw.TextAlign.left),
              _tableCell(item['hsnSac'] as String? ?? ''),
              _tableCell('${item['quantity']}'),
              _tableCell(_currencyFormat.format(item['price'] ?? 0)),
              _tableCell('${((item['taxRate'] as double? ?? 0) * 100).toStringAsFixed(0)}%'),
              _tableCell(_currencyFormat.format(item['lineTotal'] ?? 0)),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _tableCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildTotalsSection({
    required Map<String, dynamic> invoiceData,
    required bool isInterState,
    required PdfColor primaryColor,
  }) {
    final taxableValue = invoiceData['taxableValue'] as double? ?? 0;
    final cgst = invoiceData['cgst'] as double? ?? 0;
    final sgst = invoiceData['sgst'] as double? ?? 0;
    final igst = invoiceData['igst'] as double? ?? 0;
    final totalAmount = invoiceData['totalAmount'] as double? ?? 0;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 250,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: primaryColor, width: 2),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            children: [
              _totalRow('Taxable Value', taxableValue),
              pw.SizedBox(height: 5),
              if (!isInterState) ...[
                _totalRow('CGST', cgst),
                _totalRow('SGST', sgst),
              ] else
                _totalRow('IGST', igst),
              pw.Divider(thickness: 2, color: primaryColor),
              _totalRow('GRAND TOTAL', totalAmount, isBold: true, color: primaryColor),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _totalRow(String label, double value, {bool isBold = false, PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: isBold ? 11 : 9,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
        pw.Text(
          _currencyFormat.format(value),
          style: pw.TextStyle(
            fontSize: isBold ? 12 : 10,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildFooterSection({
    required InvoiceSettings settings,
    required Map<String, dynamic> businessData,  // ✅ ADDED
    required Uint8List? qrCodeBytes,
    required pw.MemoryImage? signatureImage,
    required PdfColor secondaryColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PAYMENT DETAILS',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: secondaryColor,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  // ✅ READ FROM BUSINESS DATA
                  if (businessData['upiId'] != null && businessData['upiId'].toString().isNotEmpty)
                    pw.Text('UPI: ${businessData['upiId']}', style: const pw.TextStyle(fontSize: 8)),
                  if (businessData['bankName'] != null && businessData['bankName'].toString().isNotEmpty)
                    pw.Text('Bank: ${businessData['bankName']}', style: const pw.TextStyle(fontSize: 8)),
                  if (businessData['accountNumber'] != null && businessData['accountNumber'].toString().isNotEmpty)
                    pw.Text('A/C: ${businessData['accountNumber']}', style: const pw.TextStyle(fontSize: 8)),
                  if (businessData['ifsc'] != null && businessData['ifsc'].toString().isNotEmpty)
                    pw.Text('IFSC: ${businessData['ifsc']}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
            if (qrCodeBytes != null && qrCodeBytes.isNotEmpty)
              pw.Container(
                width: 80,
                height: 80,
                child: pw.Image(pw.MemoryImage(qrCodeBytes)),
              ),
          ],
        ),

        pw.SizedBox(height: 15),

        pw.Text(
          'TERMS & CONDITIONS',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: secondaryColor,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          settings.termsAndConditions,
          style: const pw.TextStyle(fontSize: 7),
        ),

        pw.SizedBox(height: 15),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (signatureImage != null)
                  pw.Container(
                    width: 100,
                    height: 40,
                    child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                  ),
                pw.Container(
                  width: 150,
                  height: 1,
                  color: PdfColors.black,
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Authorized Signatory',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                if (settings.signatoryName != null)
                  pw.Text(
                    settings.signatoryName!,
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildWatermark(String text) {
    return pw.Positioned(
      left: 150,
      top: 400,
      child: pw.Transform.rotate(
        angle: -0.5,
        child: pw.Opacity(
          opacity: 0.1,
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 80,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey,
            ),
          ),
        ),
      ),
    );
  }

  PdfColor _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      final r = int.parse(hex.substring(0, 2), radix: 16);
      final g = int.parse(hex.substring(2, 4), radix: 16);
      final b = int.parse(hex.substring(4, 6), radix: 16);
      return PdfColor.fromInt((r << 16) | (g << 8) | b);
    } catch (e) {
      return PdfColors.blue;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      DateTime dateTime;
      if (date is DateTime) {
        dateTime = date;
      } else {
        dateTime = (date as dynamic).toDate();
      }
      return DateFormat('dd-MMM-yyyy').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }

  String _generateUPIString(String upiId, String name, double amount) {
    return 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(name)}&am=${amount.toStringAsFixed(2)}&cu=INR';
  }

  Future<Uint8List> _generateQRCode(String data) async {
    try {
      final qrValidationResult = QrValidator.validate(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final painter = QrPainter.withQr(
          qr: qrCode,
          color: const material.Color(0xFF000000),
          emptyColor: const material.Color(0xFFFFFFFF),
          gapless: true,
        );

        final picData = await painter.toImageData(200, format: ui.ImageByteFormat.png);
        return picData!.buffer.asUint8List();
      }
      
      return Uint8List(0);
    } catch (e) {
      material.debugPrint('❌ Error generating QR: $e');
      return Uint8List(0);
    }
  }

  Future<File> savePdfToFile(pw.Document pdf, String fileName) async {
    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/$fileName.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> sharePdf(pw.Document pdf, String fileName) async {
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '$fileName.pdf',
    );
  }

  Future<void> printPdf(pw.Document pdf) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> previewPdf(pw.Document pdf, material.BuildContext context) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
