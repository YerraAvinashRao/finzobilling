import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class PnLStatementScreen extends StatefulWidget {
  const PnLStatementScreen({super.key});

  @override
  State<PnLStatementScreen> createState() => _PnLStatementScreenState();
}

class _PnLStatementScreenState extends State<PnLStatementScreen> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = false;
  Map<String, dynamic>? _pnlData;

  @override
  void initState() {
    super.initState();
    _generatePnL();
  }

  Future<void> _generatePnL() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

      // Get Revenue (from invoices)
      final invoicesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('invoices')
          .where('invoiceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('invoiceDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .where('status', whereIn: ['Paid', 'Unpaid', 'Partially Paid'])
          .get();

      double revenue = 0;
      for (var doc in invoicesSnapshot.docs) {
        revenue += (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
      }

      // Get Expenses
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      double expenses = 0;
      Map<String, double> expensesByCategory = {};

      for (var doc in expensesSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        final category = data['category'] as String? ?? 'Other';
        
        expenses += amount;
        expensesByCategory[category] = (expensesByCategory[category] ?? 0) + amount;
      }

      final grossProfit = revenue - expenses;
      final netProfit = grossProfit; // Can add more deductions here

      if (mounted) {
        setState(() {
          _pnlData = {
            'revenue': revenue,
            'expenses': expenses,
            'expensesByCategory': expensesByCategory,
            'grossProfit': grossProfit,
            'netProfit': netProfit,
            'invoiceCount': invoicesSnapshot.size,
            'expenseCount': expensesSnapshot.size,
          };
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      _generatePnL();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('P&L Statement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectMonth,
            tooltip: 'Select Month',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pnlData == null
              ? const Center(child: Text('No data available'))
              : RefreshIndicator(
                  onRefresh: _generatePnL,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header Card
                      Card(
                        color: Colors.blue.shade50,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.assessment, color: Colors.blue.shade700, size: 32),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Profit & Loss Statement',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
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
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Net Profit Card
                      Card(
                        elevation: 4,
                        color: (_pnlData!['netProfit'] as double) >= 0
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: ((_pnlData!['netProfit'] as double) >= 0
                                          ? Colors.green
                                          : Colors.red)
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  (_pnlData!['netProfit'] as double) >= 0
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  color: (_pnlData!['netProfit'] as double) >= 0
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (_pnlData!['netProfit'] as double) >= 0
                                          ? 'Net Profit'
                                          : 'Net Loss',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currency.format((_pnlData!['netProfit'] as double).abs()),
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: (_pnlData!['netProfit'] as double) >= 0
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
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

                      // Revenue Section
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.arrow_circle_down, color: Colors.green.shade700),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Revenue (Income)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildRow(
                                'Sales Revenue',
                                _pnlData!['revenue'] as double,
                                currency,
                              ),
                              _buildRow(
                                'Invoices',
                                _pnlData!['invoiceCount'] as int,
                                null,
                                isCount: true,
                              ),
                              const Divider(height: 20),
                              _buildRow(
                                'Total Revenue',
                                _pnlData!['revenue'] as double,
                                currency,
                                isBold: true,
                                color: Colors.green,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Expenses Section
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.arrow_circle_up, color: Colors.red.shade700),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Expenses',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...(_pnlData!['expensesByCategory'] as Map<String, double>)
                                  .entries
                                  .map((entry) => _buildRow(
                                        entry.key,
                                        entry.value,
                                        currency,
                                      )),
                              const Divider(height: 20),
                              _buildRow(
                                'Total Expenses',
                                _pnlData!['expenses'] as double,
                                currency,
                                isBold: true,
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Chart
                      if ((_pnlData!['expensesByCategory'] as Map<String, double>).isNotEmpty)
                        _buildExpensesChart(),

                      const SizedBox(height: 16),

                      // Summary Card
                      Card(
                        elevation: 3,
                        color: Colors.grey.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Summary',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildRow('Revenue', _pnlData!['revenue'] as double, currency),
                              _buildRow('Expenses', _pnlData!['expenses'] as double, currency),
                              const Divider(height: 20),
                              _buildRow(
                                (_pnlData!['netProfit'] as double) >= 0 ? 'Net Profit' : 'Net Loss',
                                (_pnlData!['netProfit'] as double).abs(),
                                currency,
                                isBold: true,
                                color: (_pnlData!['netProfit'] as double) >= 0 ? Colors.green : Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRow(
    String label,
    dynamic value,
    NumberFormat? currency, {
    bool isBold = false,
    Color? color,
    bool isCount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 15 : 14,
              color: color,
            ),
          ),
          Text(
            isCount ? value.toString() : currency!.format(value),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 15 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesChart() {
    final expensesByCategory = _pnlData!['expensesByCategory'] as Map<String, double>;
    final sortedExpenses = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      Colors.red,
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.green,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expense Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        centerSpaceRadius: 40,
                        sections: sortedExpenses.asMap().entries.map((entry) {
                          final index = entry.key;
                          final expense = entry.value;
                          final percentage = (expense.value / _pnlData!['expenses']) * 100;
                          return PieChartSectionData(
                            value: expense.value,
                            title: '${percentage.toStringAsFixed(0)}%',
                            color: colors[index % colors.length],
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: sortedExpenses.take(5).toList().asMap().entries.map((entry) {
                        final index = entry.key;
                        final expense = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: colors[index % colors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  expense.key,
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
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
}
