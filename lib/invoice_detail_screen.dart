import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finzobilling/models/payment.dart';
import 'package:finzobilling/widgets/record_payment_dialog.dart';
import 'package:finzobilling/services/audit_service.dart';
import 'package:finzobilling/services/analytics_service.dart';
import 'package:finzobilling/services/receipt_pdf_service.dart';
import 'screens/amend_invoice_screen.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  bool _isLoading = false;

  // 🍎 Apple iOS Premium Colors
  static const Color appleBackground = Color(0xFFFBFBFD);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleText = Color(0xFF1D1D1F);
  static const Color appleSecondary = Color(0xFF86868B);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleDivider = Color(0xFFD2D2D7);
  static const Color appleSubtle = Color(0xFFF5F5F7);

  DocumentReference<Map<String, dynamic>> _getInvoiceRef() {
    final user = FirebaseAuth.instance.currentUser!;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('invoices')
        .doc(widget.invoiceId);
  }

  CollectionReference<Map<String, dynamic>> _getPaymentsRef() {
    final user = FirebaseAuth.instance.currentUser!;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('invoices')
        .doc(widget.invoiceId)
        .collection('payments');
  }

  Widget _buildAmendmentInfo(Map<String, dynamic> data) {
    final isAmended = data['isAmended'] as bool? ?? false;
    final isAmendment = data['isAmendment'] as bool? ?? false;

    if (!isAmended && !isAmendment) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade50,
            Colors.orange.shade100.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Amendment Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: appleText,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            
            Divider(height: 24, color: Colors.orange.shade300),
            
            if (isAmended) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'This invoice has been AMENDED',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: appleText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (data['amendmentDate'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Amended: ${DateFormat('dd/MM/yyyy HH:mm').format((data['amendmentDate'] as Timestamp).toDate())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: appleSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'This original invoice should NOT be used. A corrected version has been created.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (isAmendment) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'This is an AMENDED invoice',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: appleText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (data['originalInvoiceNumber'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Original: ${data['originalInvoiceNumber']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: appleSecondary,
                        ),
                      ),
                    ],
                    if (data['amendmentReason'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${data['amendmentReason']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: appleSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'This is the corrected version that should be used.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generateReceipt(Payment payment, Map<String, dynamic> invoiceData) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: appleCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: appleAccent),
                SizedBox(height: 16),
                Text(
                  'Generating Receipt...',
                  style: TextStyle(
                    color: appleText,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final user = FirebaseAuth.instance.currentUser!;
      final businessDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('business_details')
          .get();

      final businessData = businessDoc.data() ?? {};
      final totalPaid = await _getTotalPaid();
      final totalAmount = (invoiceData['totalAmount'] as num?)?.toDouble() ?? 0;
      final outstanding = totalAmount - totalPaid;

      final receiptService = ReceiptPdfService();
      final pdf = await receiptService.generateReceiptPdf(
        payment: payment,
        invoiceData: invoiceData,
        businessData: businessData,
        totalPaid: totalPaid,
        outstanding: outstanding,
      );

      if (mounted) Navigator.pop(context);

      if (mounted) {
        final action = await _showActionDialog(
          'Payment Receipt',
          'Receipt for ${_currency.format(payment.amount)}',
        );

        if (action == 'preview') {
          await receiptService.previewReceipt(pdf, context);
        } else if (action == 'share') {
          await receiptService.shareReceipt(pdf, 'Receipt_${payment.id}');
        } else if (action == 'print') {
          await receiptService.printReceipt(pdf);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  Future<void> _recordPayment(Map<String, dynamic> invoiceData) async {
    final totalAmount = (invoiceData['totalAmount'] as num?)?.toDouble() ?? 0;
    final paidAmount = await _getTotalPaid();
    final outstanding = totalAmount - paidAmount;

    if (outstanding <= 0) {
      _showSnackBar('Invoice is fully paid!');
      return;
    }

    final paymentData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RecordPaymentDialog(
        outstandingAmount: outstanding,
        invoiceNumber: invoiceData['invoiceNumber'] as String? ?? 'N/A',
      ),
    );

    if (paymentData == null) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      
      final paymentRef = _getPaymentsRef().doc();
      await paymentRef.set({
        'invoiceId': widget.invoiceId,
        'amount': paymentData['amount'],
        'method': paymentData['method'],
        'paymentDate': Timestamp.fromDate(paymentData['paymentDate']),
        'reference': paymentData['reference'],
        'notes': paymentData['notes'],
        'createdBy': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final newPaidAmount = paidAmount + (paymentData['amount'] as double);
      final newOutstanding = totalAmount - newPaidAmount;

      String newStatus = 'Unpaid';
      if (newOutstanding <= 0) {
        newStatus = 'Paid';
      } else if (newPaidAmount > 0) {
        newStatus = 'Partially Paid';
      }

      await _getInvoiceRef().update({
        'status': newStatus,
        'paidAmount': newPaidAmount,
        'outstandingAmount': newOutstanding,
        'lastPaymentDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await AuditService().logAction(
        entityType: 'payment',
        entityId: paymentRef.id,
        action: 'RECORD_PAYMENT',
        afterData: {
          'invoiceId': widget.invoiceId,
          'invoiceNumber': invoiceData['invoiceNumber'],
          'amount': paymentData['amount'],
          'method': paymentData['method'],
          'newStatus': newStatus,
        },
        reason: 'Payment recorded by user',
      );

      await AnalyticsService().logPaymentRecorded(
        amount: paymentData['amount'] as double,
        invoiceId: widget.invoiceId,
        method: paymentData['method'] as String,
      );

      if (mounted) {
        _showSnackBar('Payment of ${_currency.format(paymentData['amount'])} recorded!');
      }
    } catch (e) {
      await AnalyticsService().recordError(
        e,
        StackTrace.current,
        reason: 'Payment recording failed',
      );

      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<double> _getTotalPaid() async {
    try {
      final paymentsSnapshot = await _getPaymentsRef().get();
      double total = 0;
      for (var doc in paymentsSnapshot.docs) {
        final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0;
        total += amount;
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _deletePayment(String paymentId, double amount) async {
    final confirm = await _showConfirmDialog(
      'Delete Payment?',
      'Remove payment of ${_currency.format(amount)}?',
    );

    if (confirm != true) return;

    try {
      await _getPaymentsRef().doc(paymentId).delete();

      final invoiceDoc = await _getInvoiceRef().get();
      final invoiceData = invoiceDoc.data()!;
      final totalAmount = (invoiceData['totalAmount'] as num?)?.toDouble() ?? 0;
      final newPaidAmount = await _getTotalPaid();
      final newOutstanding = totalAmount - newPaidAmount;

      String newStatus = 'Unpaid';
      if (newOutstanding <= 0) {
        newStatus = 'Paid';
      } else if (newPaidAmount > 0) {
        newStatus = 'Partially Paid';
      }

      await _getInvoiceRef().update({
        'status': newStatus,
        'paidAmount': newPaidAmount,
        'outstandingAmount': newOutstanding,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSnackBar('Payment deleted');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  Future<String?> _showActionDialog(String title, String content) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: appleText,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: TextStyle(
                  fontSize: 14,
                  color: appleSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildDialogButton('Preview', Icons.visibility_outlined, () => Navigator.pop(context, 'preview')),
              const SizedBox(height: 8),
              _buildDialogButton('Share', Icons.share_outlined, () => Navigator.pop(context, 'share')),
              const SizedBox(height: 8),
              _buildDialogButton('Print', Icons.print_outlined, () => Navigator.pop(context, 'print')),
              const SizedBox(height: 8),
              _buildDialogButton('Cancel', Icons.close_rounded, () => Navigator.pop(context), isCancel: true),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: appleText,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: TextStyle(
                  fontSize: 14,
                  color: appleSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildDialogButton('Cancel', Icons.close_rounded, () => Navigator.pop(context, false), isCancel: true),
              const SizedBox(height: 8),
              _buildDialogButton('Delete', Icons.delete_outline, () => Navigator.pop(context, true), isDestructive: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogButton(String label, IconData icon, VoidCallback onPressed, {bool isCancel = false, bool isDestructive = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive 
              ? Colors.red 
              : (isCancel ? appleSubtle : appleAccent),
          foregroundColor: isCancel ? appleText : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appleBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: appleCard.withOpacity(0.8),
                border: Border(
                  bottom: BorderSide(
                    color: appleDivider.withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: appleText, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  'Invoice Details',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: appleText,
                    letterSpacing: -0.5,
                  ),
                ),
                actions: [
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: appleAccent,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _getInvoiceRef().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: appleSecondary),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}', style: TextStyle(color: appleSecondary)),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: appleAccent));
          }

          final invoiceDoc = snapshot.data!;
          if (!invoiceDoc.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_rounded, size: 48, color: appleSecondary),
                  const SizedBox(height: 16),
                  Text('Invoice not found', style: TextStyle(color: appleSecondary)),
                ],
              ),
            );
          }

          final data = invoiceDoc.data()!;
          final invoiceNumber = data['invoiceNumber'] as String? ?? 'N/A';
          final clientName = data['client']?['name'] ?? data['clientName'] ?? 'Unknown';
          final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
          final status = data['status'] ?? 'Unpaid';
          final createdAt = data['createdAt'] as Timestamp?;
          final lineItems = data['lineItems'] as List<dynamic>? ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              Container(
                decoration: BoxDecoration(
                  color: appleCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: appleDivider.withOpacity(0.3), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Invoice #$invoiceNumber',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: appleText,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  clientName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: appleSecondary,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _StatusBadge(status: status),
                        ],
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: appleSubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Date: ${DateFormat('dd MMM yyyy').format(createdAt.toDate())}',
                            style: TextStyle(
                              fontSize: 13,
                              color: appleSecondary,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Amendment Info Card
              _buildAmendmentInfo(data),

              // Payment Summary Card
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _getPaymentsRef().snapshots(),
                builder: (context, paymentSnapshot) {
                  double paidAmount = 0;
                  if (paymentSnapshot.hasData) {
                    for (var doc in paymentSnapshot.data!.docs) {
                      paidAmount += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
                    }
                  }

                  final outstanding = totalAmount - paidAmount;

                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: outstanding > 0 
                            ? [Colors.orange.shade50, Colors.orange.shade100.withOpacity(0.3)]
                            : [Colors.green.shade50, Colors.green.shade100.withOpacity(0.3)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: outstanding > 0 
                            ? Colors.orange.shade200 
                            : Colors.green.shade200,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildAmountRow('Total Amount', totalAmount),
                          Divider(height: 24, color: appleDivider.withOpacity(0.5)),
                          _buildAmountRow('Paid Amount', paidAmount, color: Colors.green),
                          Divider(height: 24, color: appleDivider.withOpacity(0.5)),
                          _buildAmountRow(
                            'Outstanding',
                            outstanding,
                            isBold: true,
                            color: outstanding > 0 ? Colors.orange.shade700 : Colors.green.shade700,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _recordPayment(data),
                      icon: const Icon(Icons.payment_rounded, size: 20),
                      label: const Text('Record Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  if (data['isAmended'] != true && data['status'] != 'Void') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AmendInvoiceScreen(
                                invoiceId: widget.invoiceId,
                                originalInvoice: data,
                              ),
                            ),
                          );
                          if (result == true && mounted) {
                            // Refresh via StreamBuilder
                          }
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 20),
                        label: const Text('Amend'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),

              // Section Header
              const Text(
                'Payment History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: appleText,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Payment History
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _getPaymentsRef().orderBy('paymentDate', descending: true).snapshots(),
                builder: (context, paymentSnapshot) {
                  if (!paymentSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: appleAccent));
                  }

                  final payments = paymentSnapshot.data!.docs;

                  if (payments.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: appleCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: appleDivider.withOpacity(0.3)),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 48, color: appleSecondary),
                            const SizedBox(height: 12),
                            Text(
                              'No payments recorded yet',
                              style: TextStyle(color: appleSecondary, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final invoiceData = data;

                  return Column(
                    children: payments.map((paymentDoc) {
                      final payment = Payment.fromFirestore(paymentDoc.id, paymentDoc.data());
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: appleCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: appleDivider.withOpacity(0.3), width: 0.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.green.shade600,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currency.format(payment.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: appleText,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${payment.method} • ${DateFormat('dd MMM yyyy').format(payment.paymentDate)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: appleSecondary,
                                        letterSpacing: -0.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (payment.reference != null && payment.reference!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Ref: ${payment.reference}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: appleSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.receipt_rounded, color: appleAccent, size: 20),
                                onPressed: () => _generateReceipt(payment, invoiceData),
                                tooltip: 'Receipt',
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                padding: EdgeInsets.zero,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => _deletePayment(payment.id, payment.amount),
                                tooltip: 'Delete',
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Line Items Section
              const Text(
                'Items',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: appleText,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              ...lineItems.map((item) {
                final productName = item['productName'] as String? ?? 'Unknown';
                final quantity = item['quantity'] as num? ?? 0;
                final price = (item['price'] as num?)?.toDouble() ?? 0;
                final lineTotal = (item['lineTotal'] as num?)?.toDouble() ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: appleCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: appleDivider.withOpacity(0.3), width: 0.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: appleText,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Qty: $quantity × ${_currency.format(price)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: appleSecondary,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _currency.format(lineTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: appleText,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            color: color ?? appleText,
            letterSpacing: isBold ? -0.3 : -0.2,
          ),
        ),
        Text(
          _currency.format(amount),
          style: TextStyle(
            fontSize: isBold ? 18 : 16,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color ?? appleText,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  Color _getColor() {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Partially Paid':
        return Colors.blue;
      case 'Unpaid':
        return Colors.orange;
      case 'Overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
