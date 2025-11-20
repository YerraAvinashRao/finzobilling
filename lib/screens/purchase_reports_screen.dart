import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PurchaseReportsScreen extends StatefulWidget {
  const PurchaseReportsScreen({super.key});

  @override
  State<PurchaseReportsScreen> createState() => _PurchaseReportsScreenState();
}

class _PurchaseReportsScreenState extends State<PurchaseReportsScreen> {
  final _auth = FirebaseAuth.instance;
  String? _userId;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
  }

  Future<Map<String, dynamic>> _getPurchaseStats() async {
    if (_userId == null) return {};

    try {
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

      final purchasesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('purchases')
          .where('purchaseDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('purchaseDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      double totalPurchases = 0;
      int receivedCount = 0;
      int pendingCount = 0;
      Map<String, double> supplierPurchases = {};

      for (var doc in purchasesSnapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
        final status = data['status'] ?? 'pending';
        final supplier = data['supplierName'] ?? 'Unknown';

        totalPurchases += amount;

        if (status == 'received') {
          receivedCount++;
        } else if (status == 'pending') {
          pendingCount++;
        }

        supplierPurchases[supplier] = (supplierPurchases[supplier] ?? 0) + amount;
      }

      return {
        'totalPurchases': totalPurchases,
        'purchaseCount': purchasesSnapshot.docs.length,
        'receivedCount': receivedCount,
        'pendingCount': pendingCount,
        'supplierPurchases': supplierPurchases,
      };
    } catch (e) {
      debugPrint('Error getting purchase stats: $e');
      return {};
    }
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectMonth,
            tooltip: 'Select Month',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getPurchaseStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          }

          final stats = snapshot.data!;
          final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Month Header
                Card(
                  color: Colors.purple.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.assessment, color: Colors.purple.shade700, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Purchase Report',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                DateFormat('MMMM yyyy').format(_selectedMonth),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Purchases',
                        currency.format(stats['totalPurchases'] ?? 0),
                        Icons.shopping_cart,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Orders',
                        '${stats['purchaseCount'] ?? 0}',
                        Icons.receipt_long,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Received',
                        '${stats['receivedCount'] ?? 0}',
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Pending',
                        '${stats['pendingCount'] ?? 0}',
                        Icons.pending,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Top Suppliers - FIXED SECTION
                if ((stats['supplierPurchases'] as Map<String, double>?)?.isNotEmpty ?? false) ...[
                  const Text(
                    'Top Suppliers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: _buildTopSuppliersList(
                          stats['supplierPurchases'] as Map<String, double>,
                          currency,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅ FIXED: Separate method to build top suppliers list
  List<Widget> _buildTopSuppliersList(Map<String, double> supplierPurchases, NumberFormat currency) {
    final sortedEntries = supplierPurchases.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topFive = sortedEntries.take(5).toList();

    return topFive.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              currency.format(entry.value),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
