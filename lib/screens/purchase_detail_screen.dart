import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PurchaseDetailScreen extends StatefulWidget {
  final String purchaseId;

  const PurchaseDetailScreen({super.key, required this.purchaseId});

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  final _auth = FirebaseAuth.instance;
  String? _userId;
  bool _isUpdatingStock = false;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
  }

  Future<void> _updateStockFromPurchase(Map<String, dynamic> purchase) async {
    if (_userId == null) return;

    setState(() => _isUpdatingStock = true);

    try {
      final items = purchase['items'] as List<dynamic>? ?? [];

      for (var item in items) {
        final productId = item['productId'] as String?;
        final quantity = item['quantity'] as int? ?? 0;

        if (productId != null && quantity > 0) {
          final productRef = FirebaseFirestore.instance
              .collection('users')
              .doc(_userId)
              .collection('products')
              .doc(productId);

          final productDoc = await productRef.get();
          if (productDoc.exists) {
            final currentStock = (productDoc.data()?['currentStock'] ?? 
                                 productDoc.data()?['quantity'] ?? 0) as int;
            
            await productRef.update({
              'currentStock': currentStock + quantity,
              'quantity': currentStock + quantity,
              'updatedAt': Timestamp.now(),
            });
          }
        }
      }

      // Update purchase status
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('purchases')
          .doc(widget.purchaseId)
          .update({
        'status': 'received',
        'updatedAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating stock: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStock = false);
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
        title: const Text('Purchase Details'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('purchases')
            .doc(widget.purchaseId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Purchase not found'));
          }

          final purchase = snapshot.data!.data() as Map<String, dynamic>;
          final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
          final date = (purchase['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now();
          final status = purchase['status'] ?? 'pending';

          Color statusColor;
          String statusText;
          switch (status) {
            case 'received':
              statusColor = Colors.green;
              statusText = 'RECEIVED';
              break;
            case 'partial':
              statusColor = Colors.orange;
              statusText = 'PARTIAL';
              break;
            default:
              statusColor = Colors.blue;
              statusText = 'PENDING';
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor.withOpacity(0.1), Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        purchase['purchaseNumber'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('dd MMM yyyy').format(date),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Supplier: ${purchase['supplierName'] ?? 'Unknown'}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                // Items List
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...((purchase['items'] as List<dynamic>? ?? []).map((item) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(item['productName'] ?? 'Unknown'),
                            subtitle: Text('Qty: ${item['quantity']} × ${currency.format(item['purchasePrice'] ?? 0)}'),
                            trailing: Text(
                              currency.format(item['total'] ?? 0),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      }).toList()),

                      const SizedBox(height: 16),
                      const Divider(),

                      // Totals
                      _buildTotalRow('Subtotal', currency.format(purchase['subtotal'] ?? 0)),
                      _buildTotalRow('Tax', currency.format(purchase['taxAmount'] ?? 0)),
                      const Divider(),
                      _buildTotalRow(
                        'Total',
                        currency.format(purchase['totalAmount'] ?? 0),
                        isBold: true,
                      ),

                      if (purchase['notes'] != null && purchase['notes'].toString().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Notes',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(purchase['notes']),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Update Stock Button
                      if (status != 'received')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isUpdatingStock
                                ? null
                                : () => _updateStockFromPurchase(purchase),
                            icon: _isUpdatingStock
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.inventory),
                            label: Text(_isUpdatingStock ? 'Updating...' : 'Mark as Received & Update Stock'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 18 : 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 18 : 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
