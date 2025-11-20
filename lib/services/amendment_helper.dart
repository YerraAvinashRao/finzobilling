// lib/services/amendment_helper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AmendmentHelper {
  /// Check if GSTR-1 was filed for a period
  static Future<bool> isGSTR1Filed(DateTime invoiceDate) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final period = '${invoiceDate.year}-${invoiceDate.month.toString().padLeft(2, '0')}';
    
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('gst_filing_status')
        .doc(period)
        .get();

    return doc.data()?['gstr1Filed'] ?? false;
  }

  /// Create amendment with automatic GSTR-1A detection
  static Future<void> createAmendment({
    required String originalInvoiceId,
    required Map<String, dynamic> originalData,
    required Map<String, dynamic> amendedData,
    required String amendmentReason,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final invoiceDate = (amendedData['invoiceDate'] as Timestamp).toDate();
    
    // ✅ Check if GSTR-1 was already filed for this period
    final isFiledAlready = await isGSTR1Filed(invoiceDate);

    // Create amended invoice with GSTR-1A flag
    final amendedInvoiceData = {
      ...amendedData,
      'amendmentOf': originalInvoiceId,
      'amendmentReason': amendmentReason,
      'amendmentDate': Timestamp.now(),
      'isAmended': false,
      'needsGSTR1A': isFiledAlready, // ✅ Auto-detect!
      'amendedInDifferentMonth': _isDifferentMonth(originalData, amendedData),
    };

    // Save amended invoice
    final amendedRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('invoices')
        .add(amendedInvoiceData);

    // Mark original as amended
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('invoices')
        .doc(originalInvoiceId)
        .update({
      'isAmended': true,
      'amendedBy': amendedRef.id,
      'amendedOn': Timestamp.now(),
    });

    // Log amendment
    await _logAmendment(
      originalInvoiceId: originalInvoiceId,
      amendedInvoiceId: amendedRef.id,
      reason: amendmentReason,
      originalData: originalData,
      amendedData: amendedInvoiceData,
      needsGSTR1A: isFiledAlready,
    );
  }

  /// Check if amendment is in different month than original
  static bool _isDifferentMonth(Map<String, dynamic> original, Map<String, dynamic> amended) {
    final originalDate = (original['invoiceDate'] as Timestamp).toDate();
    final amendedDate = (amended['invoiceDate'] as Timestamp).toDate();
    
    return originalDate.year != amendedDate.year || 
           originalDate.month != amendedDate.month;
  }

  /// Log amendment for audit trail
  static Future<void> _logAmendment({
    required String originalInvoiceId,
    required String amendedInvoiceId,
    required String reason,
    required Map<String, dynamic> originalData,
    required Map<String, dynamic> amendedData,
    required bool needsGSTR1A,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('amendment_logs')
        .add({
      'originalInvoiceId': originalInvoiceId,
      'amendedInvoiceId': amendedInvoiceId,
      'amendmentReason': reason,
      'amendmentDate': Timestamp.now(),
      'needsGSTR1A': needsGSTR1A,
      'originalAmount': originalData['totalAmount'],
      'amendedAmount': amendedData['totalAmount'],
      'originalInvoiceNumber': originalData['invoiceNumber'],
      'amendedInvoiceNumber': amendedData['invoiceNumber'],
    });
  }

  /// Get amendment history for an invoice
  static Future<List<Map<String, dynamic>>> getAmendmentHistory(String invoiceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final logs = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('amendment_logs')
        .where('originalInvoiceId', isEqualTo: invoiceId)
        .orderBy('amendmentDate', descending: true)
        .get();

    return logs.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// Check if invoice can be amended
  static bool canAmend(Map<String, dynamic> invoice) {
    // Already amended?
    if (invoice['isAmended'] == true) return false;

    // Check if invoice is too old (more than 2 years)
    final invoiceDate = (invoice['invoiceDate'] as Timestamp).toDate();
    final twoYearsAgo = DateTime.now().subtract(const Duration(days: 730));
    if (invoiceDate.isBefore(twoYearsAgo)) return false;

    return true;
  }

  /// Mark GSTR-1 as filed for a period
  static Future<void> markGSTR1Filed(DateTime period) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final periodKey = '${period.year}-${period.month.toString().padLeft(2, '0')}';
    
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
  }
}
