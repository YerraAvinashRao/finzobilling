// lib/dashboard_metrics_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardMetricsScreen extends StatefulWidget {
  const DashboardMetricsScreen({super.key});

  @override
  State<DashboardMetricsScreen> createState() => _DashboardMetricsScreenState();
}

class _DashboardMetricsScreenState extends State<DashboardMetricsScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  String? _userId;
  String _selectedPeriod = 'Today';
  late TabController _tabController;

  // 🍎 APPLE iOS COLORS
  static const Color appleBackground = Color(0xFFFBFBFD);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleText = Color(0xFF1D1D1F);
  static const Color appleSecondary = Color(0xFF86868B);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleDivider = Color(0xFFD2D2D7);
  static const Color appleSubtle = Color(0xFFF5F5F7);

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================
  // DATE RANGE CALCULATIONS (PRESERVED)
  // ============================================

  Map<String, DateTime> _getDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Today':
        return {
          'start': DateTime(now.year, now.month, now.day),
          'end': DateTime(now.year, now.month, now.day, 23, 59, 59),
        };
      case 'Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return {
          'start': DateTime(weekStart.year, weekStart.month, weekStart.day),
          'end': now,
        };
      case 'Month':
        return {
          'start': DateTime(now.year, now.month, 1),
          'end': DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        };
      case 'Year':
        return {
          'start': DateTime(now.year, 1, 1),
          'end': DateTime(now.year, 12, 31, 23, 59, 59),
        };
      default:
        return {
          'start': DateTime(now.year, now.month, now.day),
          'end': now,
        };
    }
  }

  // [ALL YOUR EXISTING STREAM METHODS - KEEP AS IS]
  Stream<Map<String, double>> _getFinancialSummary() {
    // ... KEEP YOUR EXISTING CODE ...
    if (_userId == null) return Stream.value({});
    
    final range = _getDateRange();
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('invoices')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range['start']!))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(range['end']!))
        .snapshots()
        .asyncMap((invoiceSnapshot) async {
      double revenue = 0;
      double costOfGoodsSold = 0;
      double paid = 0;
      double outstanding = 0;
      double totalGst = 0;
      
      for (var doc in invoiceSnapshot.docs) {
        final data = doc.data();
        final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;
        final gst = (data['gst'] as num?)?.toDouble() ?? 0;
        final status = data['status'] as String?;
        
        revenue += total;
        totalGst += gst;
        
        if (status == 'Paid') {
          paid += total;
        } else if (status == 'Unpaid' || status == 'Partially Paid') {
          final payments = data['payments'] as List<dynamic>? ?? [];
          double paidAmount = 0;
          for (var payment in payments) {
            paidAmount += (payment['amount'] as num?)?.toDouble() ?? 0;
          }
          paid += paidAmount;
          outstanding += (total - paidAmount);
        }
        
        final lineItems = data['lineItems'] as List<dynamic>? ?? [];
        for (var item in lineItems) {
          final productId = item['productId'] as String?;
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          
          if (productId != null) {
            try {
              final productDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_userId)
                  .collection('products')
                  .doc(productId)
                  .get();
              
              if (productDoc.exists) {
                final productData = productDoc.data()!;
                final purchasePrice = (productData['purchasePrice'] as num?)?.toDouble();
                
                if (purchasePrice != null) {
                  costOfGoodsSold += (purchasePrice * quantity);
                }
              }
            } catch (e) {
              debugPrint('Error fetching product $productId: $e');
            }
          }
        }
      }
      
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(range['start']!))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(range['end']!))
          .get();
      
      double expenses = 0;
      for (var doc in expensesSnapshot.docs) {
        expenses += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
      }
      
      final grossProfit = revenue - costOfGoodsSold;
      final netProfit = grossProfit - expenses;
      
      return {
        'revenue': revenue,
        'expenses': expenses,
        'cogs': costOfGoodsSold,
        'grossProfit': grossProfit,
        'netProfit': netProfit,
        'paid': paid,
        'outstanding': outstanding,
        'gst': totalGst,
      };
    }).handleError((error) {
      debugPrint('Error loading financial summary: $error');
      return {
        'revenue': 0.0,
        'expenses': 0.0,
        'cogs': 0.0,
        'grossProfit': 0.0,
        'netProfit': 0.0,
        'paid': 0.0,
        'outstanding': 0.0,
        'gst': 0.0,
      };
    });
  }

  Stream<List<Map<String, dynamic>>> _getTopProducts() {
    if (_userId == null) return Stream.value([]);
    
    final range = _getDateRange();
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('invoices')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range['start']!))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(range['end']!))
        .snapshots()
        .asyncMap((snapshot) async {
      Map<String, Map<String, dynamic>> productSales = {};
      
      for (var doc in snapshot.docs) {
        final lineItems = doc.data()['lineItems'] as List<dynamic>? ?? [];
        for (var item in lineItems) {
          final productId = item['productId'] as String? ?? '';
          if (productId.isEmpty) continue;
          
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          final total = (item['total'] as num?)?.toDouble() ?? 0;
          
          String productName = item['name'] as String? ?? 'Unknown';
          
          try {
            final productDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(_userId)
                .collection('products')
                .doc(productId)
                .get();
            
            if (productDoc.exists) {
              productName = productDoc.data()?['name'] as String? ?? productName;
            }
          } catch (e) {
            debugPrint('Error fetching product name for $productId: $e');
          }
          
          if (productSales.containsKey(productId)) {
            productSales[productId]!['quantity'] += quantity;
            productSales[productId]!['revenue'] += total;
          } else {
            productSales[productId] = {
              'name': productName,
              'quantity': quantity,
              'revenue': total,
            };
          }
        }
      }
      
      final sorted = productSales.values.toList()
        ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      
      return sorted.take(5).toList();
    }).handleError((error) {
      debugPrint('Error loading top products: $error');
      return <Map<String, dynamic>>[];
    });
  }

  Stream<List<Map<String, dynamic>>> _getTopClients() {
    if (_userId == null) return Stream.value([]);
    
    final range = _getDateRange();
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('invoices')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range['start']!))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(range['end']!))
        .snapshots()
        .map((snapshot) {
      Map<String, Map<String, dynamic>> clientSales = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final clientName = data['client']?['name'] ?? data['clientName'] ?? 'Unknown';
        final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;
        
        if (clientSales.containsKey(clientName)) {
          clientSales[clientName]!['revenue'] += total;
          clientSales[clientName]!['invoices'] += 1;
        } else {
          clientSales[clientName] = {
            'name': clientName,
            'revenue': total,
            'invoices': 1,
          };
        }
      }
      
      final sorted = clientSales.values.toList()
        ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      
      return sorted.take(5).toList();
    }).handleError((error) {
      debugPrint('Error loading top clients: $error');
      return <Map<String, dynamic>>[];
    });
  }

  Stream<Map<String, int>> _getPaymentStatusBreakdown() {
    if (_userId == null) return Stream.value({});
    
    final range = _getDateRange();
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('invoices')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range['start']!))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(range['end']!))
        .snapshots()
        .map((snapshot) {
      int paid = 0;
      int unpaid = 0;
      int partial = 0;
      
      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'Paid') {
          paid++;
        } else if (status == 'Partially Paid') {
          partial++;
        } else {
          unpaid++;
        }
      }
      
      return {'Paid': paid, 'Unpaid': unpaid, 'Partial': partial};
    }).handleError((error) {
      debugPrint('Error loading payment status: $error');
      return {};
    });
  }

  Stream<Map<String, int>> _getAlerts() {
    if (_userId == null) return Stream.value({});
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('products')
        .snapshots()
        .asyncMap((productSnapshot) async {
      int lowStock = 0;
      int outOfStock = 0;
      
      for (var doc in productSnapshot.docs) {
        final data = doc.data();
        final quantity = ((data['currentStock'] ?? data['quantity'] ?? 0) as num).toInt();
        final reorderLevel = (data['reorderLevel'] as num?)?.toInt();
        
        if (quantity == 0) {
          outOfStock++;
        } else if (reorderLevel != null && quantity <= reorderLevel) {
          lowStock++;
        }
      }
      
      final now = DateTime.now();
      final overdueSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('invoices')
          .where('status', whereIn: ['Unpaid', 'Partially Paid'])
          .where('dueDate', isLessThan: Timestamp.fromDate(now))
          .get();
      
      return {
        'lowStock': lowStock,
        'outOfStock': outOfStock,
        'overdue': overdueSnapshot.size,
      };
    }).handleError((error) {
      debugPrint('Error loading alerts: $error');
      return {'lowStock': 0, 'outOfStock': 0, 'overdue': 0};
    });
  }

  // ============================================
  // 🍎 APPLE-STYLE UI WIDGETS
  // ============================================

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: appleSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ['Today', 'Week', 'Month', 'Year'].map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? appleCard : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? appleText : appleSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFinancialCard(
    String title,
    double value,
    IconData icon,
    Color color, {
    bool isNegative = false,
  }) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appleDivider.withOpacity(0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: appleSecondary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currencyFormat.format(value),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isNegative ? Colors.red : color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard() {
    return StreamBuilder<Map<String, int>>(
      stream: _getAlerts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.values.every((v) => v == 0)) {
          return const SizedBox.shrink();
        }

        final alerts = snapshot.data!;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade200, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Attention Required',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.orange.shade800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (alerts['lowStock']! > 0)
                _buildAlertItem(
                  '${alerts['lowStock']} products low on stock',
                  Icons.inventory_2,
                  Colors.orange,
                ),
              if (alerts['outOfStock']! > 0)
                _buildAlertItem(
                  '${alerts['outOfStock']} products out of stock',
                  Icons.production_quantity_limits,
                  Colors.red,
                ),
              if (alerts['overdue']! > 0)
                _buildAlertItem(
                  '${alerts['overdue']} overdue invoices',
                  Icons.event_busy,
                  Colors.red,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertItem(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: appleText,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentPieChart() {
    return StreamBuilder<Map<String, int>>(
      stream: _getPaymentStatusBreakdown(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: appleCard,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: appleDivider.withOpacity(0.3), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!;
        final total = data.values.fold<int>(0, (sum, v) => sum + v);

        if (total == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appleCard,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: appleDivider.withOpacity(0.3), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payment Status',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: appleText,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 50,
                          sections: [
                            if (data['Paid']! > 0)
                              PieChartSectionData(
                                value: data['Paid']!.toDouble(),
                                title:
                                    '${((data['Paid']! / total) * 100).toStringAsFixed(0)}%',
                                color: Colors.green,
                                radius: 45,
                                titleStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            if (data['Partial']! > 0)
                              PieChartSectionData(
                                value: data['Partial']!.toDouble(),
                                title:
                                    '${((data['Partial']! / total) * 100).toStringAsFixed(0)}%',
                                color: Colors.orange,
                                radius: 45,
                                titleStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            if (data['Unpaid']! > 0)
                              PieChartSectionData(
                                value: data['Unpaid']!.toDouble(),
                                title:
                                    '${((data['Unpaid']! / total) * 100).toStringAsFixed(0)}%',
                                color: Colors.red,
                                radius: 45,
                                titleStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendItem('Paid', data['Paid']!, Colors.green),
                          const SizedBox(height: 12),
                          _buildLegendItem(
                              'Partial', data['Partial']!, Colors.orange),
                          const SizedBox(height: 12),
                          _buildLegendItem('Unpaid', data['Unpaid']!, Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: appleSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 14,
                  color: appleText,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopProductsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getTopProducts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final products = snapshot.data!;
        final currencyFormat = NumberFormat.currency(
            locale: 'en_IN', symbol: '₹', decimalDigits: 0);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appleCard,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: appleDivider.withOpacity(0.3), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top 5 Products',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: appleText,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 16),
              ...products.asMap().entries.map((entry) {
                final index = entry.key;
                final product = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: index == 0
                              ? Colors.amber.shade100
                              : appleSubtle,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: index == 0
                                  ? Colors.amber.shade700
                                  : appleSecondary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: appleText,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${product['quantity']} units',
                              style: const TextStyle(
                                fontSize: 12,
                                color: appleSecondary,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currencyFormat.format(product['revenue']),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: appleAccent,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopClientsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getTopClients(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final clients = snapshot.data!;
        final currencyFormat = NumberFormat.currency(
            locale: 'en_IN', symbol: '₹', decimalDigits: 0);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appleCard,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: appleDivider.withOpacity(0.3), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top 5 Clients',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: appleText,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 16),
              ...clients.asMap().entries.map((entry) {
                final index = entry.key;
                final client = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: index == 0
                              ? Colors.amber.shade100
                              : appleSubtle,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: index == 0
                                  ? Colors.amber.shade700
                                  : appleSecondary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              client['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: appleText,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${client['invoices']} invoices',
                              style: const TextStyle(
                                fontSize: 12,
                                color: appleSecondary,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currencyFormat.format(client['revenue']),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: appleAccent,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Center(
          child: Text('Please log in to view dashboard',
              style: TextStyle(color: appleSecondary)));
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        await Future.delayed(const Duration(seconds: 1));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: appleAccent, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Business Overview',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: appleText,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildPeriodSelector(),
            _buildAlertCard(),
            const SizedBox(height: 12),

            StreamBuilder<Map<String, double>>(
              stream: _getFinancialSummary(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!;

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildFinancialCard(
                            'Revenue',
                            data['revenue'] ?? 0,
                            Icons.trending_up_rounded,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFinancialCard(
                            'Expenses',
                            data['expenses'] ?? 0,
                            Icons.trending_down_rounded,
                            Colors.red,
                            isNegative: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFinancialCard(
                            'Net Profit',
                            data['netProfit'] ?? 0,
                            Icons.account_balance_wallet_rounded,
                            appleAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFinancialCard(
                            'Outstanding',
                            data['outstanding'] ?? 0,
                            Icons.pending_actions_rounded,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),
            _buildPaymentPieChart(),
            const SizedBox(height: 12),
            _buildTopProductsList(),
            const SizedBox(height: 12),
            _buildTopClientsList(),
            const SizedBox(height: 80), // Extra space for bottom nav
          ],
        ),
      ),
    );
  }
}
