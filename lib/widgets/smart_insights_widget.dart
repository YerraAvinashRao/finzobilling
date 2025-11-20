import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// A single, reusable card for displaying an insight.
class InsightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget content;
  final bool isLoading;

  const InsightCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.content,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              content,
          ],
        ),
      ),
    );
  }
}

// The main widget that fetches and displays all insights.
class SmartInsightsWidget extends StatefulWidget {
  const SmartInsightsWidget({super.key});

  @override
  State<SmartInsightsWidget> createState() => _SmartInsightsWidgetState();
}

class _SmartInsightsWidgetState extends State<SmartInsightsWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  // --- Data Fetching Methods with Error Handling ---

  Future<List<DocumentSnapshot>> _fetchLowStockProducts() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('products')
          .where('stock', isLessThanOrEqualTo: 5) // Set your low stock threshold here
          .limit(5)
          .get();
      return snapshot.docs;
    } catch (e) {
      // In a real app, you might log this error to a service like Sentry
      print("Error fetching low stock products: $e");
      return []; // Return an empty list on error to prevent crashing
    }
  }

  Future<Map<String, double>> _fetchTopPerformingProducts() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('invoices')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final productSales = <String, double>{};

      for (var doc in snapshot.docs) {
        final items = List<Map<String, dynamic>>.from(doc.data()['items']);
        for (var item in items) {
          final productName = item['productName'] as String;
          final total = (item['price'] as num).toDouble() * (item['quantity'] as num).toDouble();
          productSales[productName] = (productSales[productName] ?? 0) + total;
        }
      }

      // Sort products by sales and take the top 5
      final sortedEntries = productSales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return Map.fromEntries(sortedEntries.take(5));

    } catch (e) {
      print("Error fetching top products: $e");
      return {};
    }
  }

  // --- UI Builder Methods ---

  Widget _buildLowStockContent(AsyncSnapshot<List<DocumentSnapshot>> snapshot) {
    if (snapshot.hasError) {
      return const Text('Could not load low stock items.', style: TextStyle(color: Colors.red));
    }
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return const Text('All products are well-stocked!', style: TextStyle(color: Colors.green));
    }
    final products = snapshot.data!;
    return Column(
      children: products.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.inventory_2_outlined),
          title: Text(data['productName'] ?? 'Unnamed Product'),
          trailing: Text(
            'Stock: ${data['stock']}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopProductsContent(AsyncSnapshot<Map<String, double>> snapshot) {
     if (snapshot.hasError) {
      return const Text('Could not load top products.', style: TextStyle(color: Colors.red));
    }
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return const Text('No sales data available for the last 30 days.');
    }
    final products = snapshot.data!;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Column(
      children: products.entries.map((entry) {
         return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.star_border),
          title: Text(entry.key),
          trailing: Text(
            currencyFormat.format(entry.value),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Smart Insights",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // Low Stock Insight Card
        FutureBuilder<List<DocumentSnapshot>>(
          future: _fetchLowStockProducts(),
          builder: (context, snapshot) {
            return InsightCard(
              title: 'Low Stock Alert',
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.orange,
              isLoading: snapshot.connectionState == ConnectionState.waiting,
              content: _buildLowStockContent(snapshot),
            );
          },
        ),

        // Top Performing Products Card
        FutureBuilder<Map<String, double>>(
          future: _fetchTopPerformingProducts(),
          builder: (context, snapshot) {
            return InsightCard(
              title: 'Top Products (Last 30 Days)',
              icon: Icons.trending_up_rounded,
              iconColor: Colors.teal,
              isLoading: snapshot.connectionState == ConnectionState.waiting,
              content: _buildTopProductsContent(snapshot),
            );
          },
        ),
        // We can add the "Top Customers" card here next
      ],
    );
  }
}