import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' as material;
import '../models/payment.dart';

class ReceiptPdfService {
  static final ReceiptPdfService _instance = ReceiptPdfService._internal();
  factory ReceiptPdfService() => _instance;
  ReceiptPdfService._internal();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  Future<pw.Document> generateReceiptPdf({
    required Payment payment,
    required Map<String, dynamic> invoiceData,
    required Map<String, dynamic> businessData,
    required double totalPaid,
    required double outstanding,
  }) async {
    final pdf = pw.Document();
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildReceiptHeader(businessData),
              pw.SizedBox(height: 30),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text('PAYMENT RECEIPT',
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                ),
              ),
              pw.SizedBox(height: 30),
              _buildReceiptDetails(payment, invoiceData),
              pw.SizedBox(height: 30),
              _buildPaymentInfo(payment, totalPaid, outstanding, invoiceData),
              pw.Spacer(),
              _buildReceiptFooter(businessData, payment.id),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  pw.Widget _buildReceiptHeader(Map<String, dynamic> businessData) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(8), color: PdfColors.grey100),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(businessData['name'] as String? ?? 'Business Name',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.SizedBox(height: 8),
          if (businessData['address'] != null) pw.Text(businessData['address'] as String, style: const pw.TextStyle(fontSize: 10)),
          if (businessData['city'] != null && businessData['state'] != null)
            pw.Text('${businessData['city']}, ${businessData['state']} - ${businessData['pincode'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
          if (businessData['gstin'] != null) pw.Text('GSTIN: ${businessData['gstin']}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          if (businessData['phone'] != null) pw.Text('Phone: ${businessData['phone']}', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  pw.Widget _buildReceiptDetails(Payment payment, Map<String, dynamic> invoiceData) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(
        children: [
          _buildDetailRow('Receipt Date', DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())),
          pw.Divider(),
          _buildDetailRow('Payment Date', DateFormat('dd MMM yyyy').format(payment.paymentDate)),
          pw.Divider(),
          _buildDetailRow('Invoice Number', invoiceData['invoiceNumber'] as String? ?? 'N/A'),
          pw.Divider(),
          _buildDetailRow('Client Name', invoiceData['client']?['name'] ?? invoiceData['clientName'] ?? 'Unknown'),
          if (payment.reference != null && payment.reference!.isNotEmpty) ...[
            pw.Divider(),
            _buildDetailRow('Reference/Transaction ID', payment.reference!),
          ],
          if (payment.notes != null && payment.notes!.isNotEmpty) ...[
            pw.Divider(),
            _buildDetailRow('Notes', payment.notes!),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildPaymentInfo(Payment payment, double totalPaid, double outstanding, Map<String, dynamic> invoiceData) {
    final invoiceTotal = (invoiceData['totalAmount'] as num?)?.toDouble() ?? 0;
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(color: PdfColors.green50, border: pw.Border.all(color: PdfColors.green, width: 2), borderRadius: pw.BorderRadius.circular(12)),
      child: pw.Column(
        children: [
          pw.Text('PAYMENT DETAILS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
          pw.SizedBox(height: 16),
          _buildAmountRow('Payment Method', payment.method, isMethod: true),
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.green300),
          pw.SizedBox(height: 12),
          _buildAmountRow('Payment Amount', _currencyFormat.format(payment.amount), isBold: true, fontSize: 18, color: PdfColors.green900),
          pw.SizedBox(height: 16),
          pw.Container(height: 1, color: PdfColors.green300),
          pw.SizedBox(height: 16),
          _buildAmountRow('Invoice Total', _currencyFormat.format(invoiceTotal)),
          pw.SizedBox(height: 8),
          _buildAmountRow('Total Paid', _currencyFormat.format(totalPaid), color: PdfColors.green700),
          pw.SizedBox(height: 8),
          _buildAmountRow('Outstanding Balance', _currencyFormat.format(outstanding),
              isBold: true, color: outstanding > 0 ? PdfColors.orange700 : PdfColors.green700),
        ],
      ),
    );
  }

  pw.Widget _buildReceiptFooter(Map<String, dynamic> businessData, String paymentId) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 16),
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text('Thank you for your payment!', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
              pw.SizedBox(height: 8),
              pw.Text('This is a computer-generated receipt and does not require a signature.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              if (businessData['email'] != null) pw.Text('For queries: ${businessData['email']}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Center(
          child: pw.BarcodeWidget(data: 'RECEIPT-$paymentId-${DateTime.now().millisecondsSinceEpoch}', barcode: pw.Barcode.code128(), width: 200, height: 40),
        ),
      ],
    );
  }

  pw.Widget _buildDetailRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  pw.Widget _buildAmountRow(String label, String value, {bool isBold = false, bool isMethod = false, double fontSize = 12, PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold || isMethod ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
      ],
    );
  }

  Future<void> shareReceipt(pw.Document pdf, String fileName) async {
    await Printing.sharePdf(bytes: await pdf.save(), filename: '$fileName.pdf');
  }

  Future<void> printReceipt(pw.Document pdf) async {
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> previewReceipt(pw.Document pdf, material.BuildContext context) async {
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
