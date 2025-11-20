import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

// Premium colors
const Color appleBackground = Color(0xFFF2F2F7);
const Color appleCard = Color(0xFFFFFFFF);
const Color appleAccent = Color(0xFF007AFF);

class GSTDashboardScreen extends StatefulWidget {
  const GSTDashboardScreen({super.key});

  @override
  State<GSTDashboardScreen> createState() => _GSTDashboardScreenState();
}

class _GSTDashboardScreenState extends State<GSTDashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = false;
  String _period = 'This Month';

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // Keep ALL your existing methods EXACTLY as they are
  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final dateRange = _getDateRange();
      final startDate = dateRange['start']!;
      final endDate = dateRange['end']!;

      final invoicesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('invoices')
          .where('invoiceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('invoiceDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .where('status', whereIn: ['Paid', 'Unpaid', 'Partially Paid'])
          .get();

      final purchasesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('purchases')
          .where('invoiceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('invoiceDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double salesTaxableValue = 0;
      double salesCGST = 0;
      double salesSGST = 0;
      double salesIGST = 0;

      for (var doc in invoicesSnapshot.docs) {
        final data = doc.data();
        salesTaxableValue += (data['taxableValue'] as num?)?.toDouble() ?? 0;
        salesCGST += (data['cgst'] as num?)?.toDouble() ?? 0;
        salesSGST += (data['sgst'] as num?)?.toDouble() ?? 0;
        salesIGST += (data['igst'] as num?)?.toDouble() ?? 0;
      }

      double purchaseTaxableValue = 0;
      double purchaseCGST = 0;
      double purchaseSGST = 0;
      double purchaseIGST = 0;

      for (var doc in purchasesSnapshot.docs) {
        final data = doc.data();
        final lineItems = (data['lineItems'] as List?) ?? [];
        
        for (var item in lineItems) {
          final taxableValue = (item['totalCostValue'] as num?)?.toDouble() ?? 0;
          final cgstRate = (item['cgst'] as num?)?.toDouble() ?? 0;
          final sgstRate = (item['sgst'] as num?)?.toDouble() ?? 0;
          final igstRate = (item['igst'] as num?)?.toDouble() ?? 0;

          purchaseTaxableValue += taxableValue;
          purchaseCGST += taxableValue * (cgstRate / 100);
          purchaseSGST += taxableValue * (sgstRate / 100);
          purchaseIGST += taxableValue * (igstRate / 100);
        }
      }

      final netCGST = salesCGST - purchaseCGST;
      final netSGST = salesSGST - purchaseSGST;
      final netIGST = salesIGST - purchaseIGST;
      final totalTaxLiability = netCGST + netSGST + netIGST;

      if (mounted) {
        setState(() {
          _dashboardData = {
            'sales': {
              'taxableValue': salesTaxableValue,
              'cgst': salesCGST,
              'sgst': salesSGST,
              'igst': salesIGST,
              'total': salesCGST + salesSGST + salesIGST,
            },
            'purchases': {
              'taxableValue': purchaseTaxableValue,
              'cgst': purchaseCGST,
              'sgst': purchaseSGST,
              'igst': purchaseIGST,
              'total': purchaseCGST + purchaseSGST + purchaseIGST,
            },
            'netLiability': {
              'cgst': netCGST,
              'sgst': netSGST,
              'igst': netIGST,
              'total': totalTaxLiability,
            },
            'counts': {
              'invoices': invoicesSnapshot.docs.length,
              'purchases': purchasesSnapshot.docs.length,
            },
          };
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, DateTime> _getDateRange() {
    final now = DateTime.now();
    switch (_period) {
      case 'This Month':
        return {
          'start': DateTime(now.year, now.month, 1),
          'end': DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        };
      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1);
        return {
          'start': DateTime(lastMonth.year, lastMonth.month, 1),
          'end': DateTime(lastMonth.year, lastMonth.month + 1, 0, 23, 59, 59),
        };
      case 'This Quarter':
        final quarter = ((now.month - 1) ~/ 3);
        final startMonth = (quarter * 3) + 1;
        return {
          'start': DateTime(now.year, startMonth, 1),
          'end': DateTime(now.year, startMonth + 3, 0, 23, 59, 59),
        };
      case 'This Year':
        return {
          'start': DateTime(now.year, 1, 1),
          'end': DateTime(now.year, 12, 31, 23, 59, 59),
        };
      default:
        return {
          'start': DateTime(now.year, now.month, 1),
          'end': now,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: appleBackground,
      appBar: AppBar(
        title: const Text(
          'GST Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: appleCard,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: appleAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: PopupMenuButton<String>(
              initialValue: _period,
              icon: Icon(Icons.filter_list_rounded, color: appleAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                setState(() => _period = value);
                _loadDashboard();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'This Month', child: Text('This Month')),
                const PopupMenuItem(value: 'Last Month', child: Text('Last Month')),
                const PopupMenuItem(value: 'This Quarter', child: Text('This Quarter')),
                const PopupMenuItem(value: 'This Year', child: Text('This Year')),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading dashboard...',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : _dashboardData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.insights_rounded, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No data available',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Period Header
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.indigo, Colors.indigo.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.calendar_today_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'GST Overview',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _period,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Key Metrics
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              'Invoices',
                              '${_dashboardData!['counts']['invoices']}',
                              Icons.receipt_long_rounded,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              'Purchases',
                              '${_dashboardData!['counts']['purchases']}',
                              Icons.shopping_cart_rounded,
                              Colors.blue,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Net Tax Liability Card
                      _buildTaxLiabilityCard(currency),

                      const SizedBox(height: 20),

                      // Sales vs Purchase Chart
                      _buildComparisonChart(currency),

                      const SizedBox(height: 20),

                      // Sales GST Breakdown
                      _buildGSTBreakdownCard(
                        'Output GST (Sales)',
                        _dashboardData!['sales'],
                        currency,
                        Colors.green,
                      ),

                      const SizedBox(height: 16),

                      // Purchase ITC Breakdown
                      _buildGSTBreakdownCard(
                        'Input Tax Credit (Purchases)',
                        _dashboardData!['purchases'],
                        currency,
                        Colors.blue,
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxLiabilityCard(NumberFormat currency) {
    final total = _dashboardData!['netLiability']['total'] as double;
    final isPayable = total > 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPayable 
              ? [Colors.red.shade400, Colors.red.shade600]
              : [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isPayable ? Colors.red : Colors.green).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isPayable ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPayable ? '💸 Tax Payable' : '💰 ITC Refund',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currency.format(total.abs()),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonChart(NumberFormat currency) {
    final salesTotal = _dashboardData!['sales']['total'] as double;
    final purchaseTotal = _dashboardData!['purchases']['total'] as double;
    final maxValue = [salesTotal, purchaseTotal].reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: appleAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.bar_chart_rounded, color: appleAccent, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'GST Comparison',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        switch (value.toInt()) {
                          case 0:
                            return const Text('Output GST', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600));
                          case 1:
                            return const Text('Input ITC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600));
                          default:
                            return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: salesTotal,
                        gradient: LinearGradient(
                          colors: [Colors.green.shade400, Colors.green.shade600],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 50,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: purchaseTotal,
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade600],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 50,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Output GST',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(salesTotal),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Input ITC',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(purchaseTotal),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGSTBreakdownCard(
    String title,
    Map<String, dynamic> data,
    NumberFormat currency,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  color == Colors.green ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appleBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildRow('Taxable Value', data['taxableValue'], currency),
                _buildRow('CGST', data['cgst'], currency),
                _buildRow('SGST', data['sgst'], currency),
                _buildRow('IGST', data['igst'], currency),
                const Divider(height: 20),
                _buildRow('Total', data['total'], currency, isBold: true, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, double value, NumberFormat currency, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 16 : 14,
              color: color ?? Colors.grey.shade700,
            ),
          ),
          Text(
            currency.format(value),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 16 : 14,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
