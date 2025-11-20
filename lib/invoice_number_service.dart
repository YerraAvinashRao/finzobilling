import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InvoiceNumberService {
  /// Generates the next invoice number in format: INV-YYYY-NNNN
  /// Example: INV-2025-0001, INV-2025-0002, etc.
  /// 
  /// Automatically resets counter on January 1st each year.
  static Future<String> generateNextInvoiceNumber() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final firestore = FirebaseFirestore.instance;
    final currentYear = DateTime.now().year;
    
    // Reference to the counter document for the current year
    final counterDocRef = firestore
        .collection('users')
        .doc(user.uid)
        .collection('counters')
        .doc('invoice_$currentYear');

    try {
      // Use a transaction to ensure atomicity
      final result = await firestore.runTransaction<String>((transaction) async {
        final snapshot = await transaction.get(counterDocRef);
        
        int nextNumber;
        
        if (!snapshot.exists) {
          // First invoice of the year
          nextNumber = 1;
          transaction.set(counterDocRef, {
            'lastNumber': 1,
            'year': currentYear,
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });
        } else {
          // Increment the counter
          final currentData = snapshot.data()!;
          final lastNumber = (currentData['lastNumber'] as int?) ?? 0;
          nextNumber = lastNumber + 1;
          
          transaction.update(counterDocRef, {
            'lastNumber': nextNumber,
            'updatedAt': Timestamp.now(),
          });
        }
        
        // Format: INV-2025-0001
        return 'INV-$currentYear-${nextNumber.toString().padLeft(4, '0')}';
      });
      
      return result;
    } catch (e) {
      throw Exception('Failed to generate invoice number: $e');
    }
  }

  /// Get the last generated invoice number for the current year
  static Future<String?> getLastInvoiceNumber() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final currentYear = DateTime.now().year;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('counters')
          .doc('invoice_$currentYear')
          .get();

      if (doc.exists) {
        final lastNumber = (doc.data()?['lastNumber'] as int?) ?? 0;
        return 'INV-$currentYear-${lastNumber.toString().padLeft(4, '0')}';
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if an invoice number already exists (for validation)
  static Future<bool> invoiceNumberExists(String invoiceNumber) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('invoices')
          .where('invoiceNumber', isEqualTo: invoiceNumber)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get total invoice count for current year
  static Future<int> getYearlyInvoiceCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final currentYear = DateTime.now().year;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('counters')
          .doc('invoice_$currentYear')
          .get();

      if (doc.exists) {
        return (doc.data()?['lastNumber'] as int?) ?? 0;
      }
      
      return 0;
    } catch (e) {
      return 0;
    }
  }
}
