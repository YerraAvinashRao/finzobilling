import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'models/expense_model.dart';
import 'add_expense_screen.dart';
import 'screens/pnl_statement_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _auth = FirebaseAuth.instance;
  String? _userId;
  String _selectedCategory = 'All';
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
  }

  Future<void> _deleteExpense(String expenseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && _userId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('expenses')
            .doc(expenseId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view expenses')),
      );
    }

    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PnLStatementScreen()),
              );
            },
            tooltip: 'P&L Statement',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedMonth = DateTime(picked.year, picked.month));
              }
            },
            tooltip: 'Select Month',
          ),
        ],
      ),
      body: Column(
        children: [
          // Month Summary Card
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_userId)
                .collection('expenses')
                .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
                .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
              }

              final expenses = snapshot.data!.docs;
              double totalExpenses = 0.0;
                for (var doc in expenses) {
                  totalExpenses += ((doc.data() as Map<String, dynamic>)['amount'] as num?)?.toDouble() ?? 0.0;
                }

              // Category breakdown
              Map<String, double> categoryTotals = {};
              for (var doc in expenses) {
                final data = doc.data() as Map<String, dynamic>;
                final category = data['category'] as String? ?? 'Other';
                final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
              }

              return Card(
                margin: const EdgeInsets.all(16),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [Colors.red.shade50, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.red.shade700, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('MMMM yyyy').format(_selectedMonth),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Expenses',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
                                    .format(totalExpenses),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long, color: Colors.red.shade700, size: 24),
                                const SizedBox(height: 4),
                                Text(
                                  '${expenses.length}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                Text(
                                  'Expenses',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (categoryTotals.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: categoryTotals.length > 1
                              ? PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 30,
                                    sections: categoryTotals.entries.take(5).map((entry) {
                                      final category = ExpenseCategory.getCategory(entry.key);
                                      return PieChartSectionData(
                                        value: entry.value,
                                        title: '${((entry.value / totalExpenses) * 100).toStringAsFixed(0)}%',
                                        color: Color(int.parse(category.colorHex.replaceFirst('#', '0xff'))),
                                        radius: 45,
                                        titleStyle: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    'Add more expenses to see breakdown',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          // Category Filter
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip('All'),
                ...ExpenseCategory.defaultCategories.map((cat) => _buildCategoryChip(cat.name)),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Expenses List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_userId)
                  .collection('expenses')
                  .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
                  .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No expenses for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first expense',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                var expenses = snapshot.data!.docs;
                
                // Filter by category
                if (_selectedCategory != 'All') {
                  expenses = expenses.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['category'] == _selectedCategory;
                  }).toList();
                }

                if (expenses.isEmpty) {
                  return Center(
                    child: Text(
                      'No expenses in $_selectedCategory category',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = ExpenseModel.fromFirestore(expenses[index]);
                    final category = ExpenseCategory.getCategory(expense.category);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Color(int.parse(category.colorHex.replaceFirst('#', '0xff'))).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              category.icon,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        title: Text(
                          expense.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              expense.category,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(int.parse(category.colorHex.replaceFirst('#', '0xff'))),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd MMM yyyy').format(expense.date),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            if (expense.vendor != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Vendor: ${expense.vendor}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
                                  .format(expense.amount),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                            if (expense.isRecurring)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Recurring',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddExpenseScreen(expense: expense),
                            ),
                          );
                        },
                        onLongPress: () => _deleteExpense(expense.id),
                      ),
                    );
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
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category;
    final categoryData = category == 'All' 
        ? null 
        : ExpenseCategory.getCategory(category);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (categoryData != null) ...[
              Text(categoryData.icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
            ],
            Text(category, style: const TextStyle(fontSize: 12)),
          ],
        ),
        onSelected: (selected) {
          setState(() => _selectedCategory = category);
        },
        selectedColor: categoryData != null
            ? Color(int.parse(categoryData.colorHex.replaceFirst('#', '0xff'))).withOpacity(0.3)
            : Colors.blue.shade100,
        checkmarkColor: categoryData != null
            ? Color(int.parse(categoryData.colorHex.replaceFirst('#', '0xff')))
            : Colors.blue,
      ),
    );
  }
}
