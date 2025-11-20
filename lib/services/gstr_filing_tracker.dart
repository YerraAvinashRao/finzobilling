import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GSTRFilingTracker {
  /// Mark that GSTR-1 has been filed for a period
  static Future<void> markGSTR1Filed(DateTime period) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('gst_filing_status')
        .doc(period.toIso8601String().substring(0, 7)) // "2025-09"
        .set({
      'gstr1Filed': true,
      'gstr1FiledOn': Timestamp.now(),
      'period': period,
    });
  }

  /// Check if GSTR-1 was filed for a period
  static Future<bool> isGSTR1Filed(DateTime period) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('gst_filing_status')
        .doc(period.toIso8601String().substring(0, 7))
        .get();

    return doc.data()?['gstr1Filed'] ?? false;
  }

  /// Auto-mark invoice for GSTR-1A if created after GSTR-1 filing
  static Future<void> checkAndMarkForGSTR1A(String invoiceId, DateTime invoiceDate) async {
    final period = DateTime(invoiceDate.year, invoiceDate.month);
    final isFiledAlready = await isGSTR1Filed(period);

    if (isFiledAlready) {
      // GSTR-1 already filed, this invoice needs GSTR-1A
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('invoices')
          .doc(invoiceId)
          .update({'needsGSTR1A': true});
    }
  }
}
