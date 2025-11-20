import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'new_purchase_screen.dart';
import 'screens/purchase_detail_screen.dart';

class PurchasesListScreen extends StatefulWidget {
  const PurchasesListScreen({super.key});

  @override
  State<PurchasesListScreen> createState() => _PurchasesListScreenState();
}

class _PurchasesListScreenState extends State<PurchasesListScreen> {
  final _auth = FirebaseAuth.instance;
  String? _userId;
  String _filterStatus = 'all'; // all, pending, received, partial

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
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
        title: const Text('Purchase Orders'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filterStatus = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'pending', child: Text('Pending')),
              const PopupMenuItem(value: 'received', child: Text('Received')),
              const PopupMenuItem(value: 'partial', child: Text('Partial')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_userId)
                .collection('purchases')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              double totalPurchases = 0;
              int pendingCount = 0;
              int receivedCount = 0;

              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                // ✅ FIXED: Check both totalAmount and totalCost
                totalPurchases += (data['totalAmount'] as num?)?.toDouble() ?? 
                                   (data['totalCost'] as num?)?.toDouble() ?? 0;
                
                final status = data['status'] ?? 'pending';
                if (status == 'pending') {
                  pendingCount++;
                } else if (status == 'received') {
                  receivedCount++;
                }
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade50, Colors.white],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total',
                        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
                            .format(totalPurchases),
                        Icons.shopping_cart,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Pending',
                        '$pendingCount',
                        Icons.pending,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Received',
                        '$receivedCount',
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  _buildFilterChip('Pending', 'pending'),
                  _buildFilterChip('Received', 'received'),
                  _buildFilterChip('Partial', 'partial'),
                ],
              ),
            ),
          ),

          // ✅ FIXED: Purchases List with correct field names
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _filterStatus == 'all'
                  ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(_userId)
                      .collection('purchases')
                      .orderBy('createdAt', descending: true)  // ✅ FIXED: was purchaseDate
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('users')
                      .doc(_userId)
                      .collection('purchases')
                      .where('status', isEqualTo: _filterStatus)
                      .orderBy('createdAt', descending: true)  // ✅ FIXED: was purchaseDate
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: Colors.red.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No purchases yet',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to create a purchase order',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final purchase = doc.data() as Map<String, dynamic>;
                    return _buildPurchaseCard(doc.id, purchase);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewPurchaseScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Purchase'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _filterStatus = value);
        },
        backgroundColor: Colors.grey.shade100,
        selectedColor: Colors.purple.shade100,
        checkmarkColor: Colors.purple.shade700,
      ),
    );
  }

  // ✅ FIXED: Purchase card with correct field names
  Widget _buildPurchaseCard(String purchaseId, Map<String, dynamic> purchase) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    
    // ✅ FIXED: Handle both invoiceDate and createdAt
    final date = (purchase['invoiceDate'] as Timestamp?)?.toDate() ?? 
                  (purchase['createdAt'] as Timestamp?)?.toDate() ?? 
                  DateTime.now();
    
    final status = purchase['status'] ?? 'pending';
    
    // ✅ FIXED: Handle both totalAmount and totalCost
    final totalAmount = (purchase['totalAmount'] as num?)?.toDouble() ?? 
                         (purchase['totalCost'] as num?)?.toDouble() ?? 
                         0;

    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (status) {
      case 'received':
        statusColor = Colors.green;
        statusText = 'Received';
        statusIcon = Icons.check_circle;
        break;
      case 'partial':
        statusColor = Colors.orange;
        statusText = 'Partial';
        statusIcon = Icons.hourglass_empty;
        break;
      default:
        statusColor = Colors.blue;
        statusText = 'Pending';
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PurchaseDetailScreen(purchaseId: purchaseId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, color: statusColor, size: 28),
              ),
              const SizedBox(width: 16),

              // Purchase Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // ✅ FIXED: Show invoiceNumber instead of purchaseNumber
                      purchase['invoiceNumber'] ?? purchase['purchaseNumber'] ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      purchase['supplierName'] ?? 'Unknown Supplier',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              // Amount & Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currency.format(totalAmount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
