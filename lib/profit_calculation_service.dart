import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// A dedicated service for handling complex business logic calculations.
class ProfitCalculationService {
  
  // Calculates the net profit for a given date range.
  // Net Profit = (Total Sales) - (Total Purchases) - (Total Expenses)
  static Future<double> getNetProfit({required DateTime startDate, required DateTime endDate}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated.');
    }

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);

    try {
      // Fetch all necessary data concurrently for maximum performance.
      final results = await Future.wait([
        // 1. Get all 'Paid' invoices within the date range.
        userRef.collection('invoices')
            .where('status', isEqualTo: 'Paid')
            .where('createdAt', isGreaterThanOrEqualTo: startDate)
            .where('createdAt', isLessThanOrEqualTo: endDate)
            .get(),
        // 2. Get all purchases within the date range.
        userRef.collection('purchases')
            .where('createdAt', isGreaterThanOrEqualTo: startDate)
            .where('createdAt', isLessThanOrEqualTo: endDate)
            .get(),
        // 3. Get all expenses within the date range.
        userRef.collection('expenses')
            .where('date', isGreaterThanOrEqualTo: startDate)
            .where('date', isLessThanOrEqualTo: endDate)
            .get(),
      ]);

      // --- Calculate Totals ---

      // Calculate total sales from 'Paid' invoices.
      final salesDocs = (results[0] as QuerySnapshot).docs;
      final totalSales = salesDocs.fold<double>(0.0, (sum, doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return sum + ((data?['totalAmount'] as num?)?.toDouble() ?? 0.0);
      });

      // Calculate total purchases.
      final purchasesDocs = (results[1] as QuerySnapshot).docs;
      final totalPurchases = purchasesDocs.fold<double>(0.0, (sum, doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return sum + ((data?['totalCost'] as num?)?.toDouble() ?? 0.0);
      });

      // Calculate total expenses.
      final expensesDocs = (results[2] as QuerySnapshot).docs;
      final totalExpenses = expensesDocs.fold<double>(0.0, (sum, doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return sum + ((data?['amount'] as num?)?.toDouble() ?? 0.0);
      });

      // --- Calculate Net Profit ---
      final netProfit = totalSales - totalPurchases - totalExpenses;

      return netProfit;

    } catch (e) {
      print('Error calculating net profit: $e');
      // Return 0.0 in case of an error to avoid crashing the UI.
      return 0.0;
    }
  }
}

