import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'models/expense_model.dart';

class AddExpenseScreen extends StatefulWidget {
  final ExpenseModel? expense;

  const AddExpenseScreen({super.key, this.expense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _vendorController = TextEditingController();

  String _selectedCategory = 'Other';
  DateTime _selectedDate = DateTime.now();
  bool _isRecurring = false;
  String? _recurringFrequency;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _titleController.text = widget.expense!.title;
      _descriptionController.text = widget.expense!.description;
      _amountController.text = widget.expense!.amount.toString();
      _vendorController.text = widget.expense!.vendor ?? '';
      _selectedCategory = widget.expense!.category;
      _selectedDate = widget.expense!.date;
      _isRecurring = widget.expense!.isRecurring;
      _recurringFrequency = widget.expense!.recurringFrequency;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _vendorController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final expenseData = {
        'userId': user.uid,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'amount': double.parse(_amountController.text),
        'category': _selectedCategory,
        'date': Timestamp.fromDate(_selectedDate),
        'vendor': _vendorController.text.trim().isEmpty ? null : _vendorController.text.trim(),
        'isRecurring': _isRecurring,
        'recurringFrequency': _isRecurring ? _recurringFrequency : null,
        'updatedAt': Timestamp.now(),
      };

      if (widget.expense == null) {
        // Add new expense
        expenseData['createdAt'] = Timestamp.now();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('expenses')
            .add(expenseData);
      } else {
        // Update existing expense
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('expenses')
            .doc(widget.expense!.id)
            .update(expenseData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.expense == null ? 'Expense added successfully' : 'Expense updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Add Expense' : 'Edit Expense'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Expense Title *',
                hintText: 'e.g., Office Rent, Electricity Bill',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter expense title';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Category Selection
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.category, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Category *',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ExpenseCategory.defaultCategories.map((cat) {
                      final isSelected = _selectedCategory == cat.name;
                      return InkWell(
                        onTap: () => setState(() => _selectedCategory = cat.name),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(int.parse(cat.colorHex.replaceFirst('#', '0xff'))).withOpacity(0.2)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Color(int.parse(cat.colorHex.replaceFirst('#', '0xff')))
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(cat.icon, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected
                                      ? Color(int.parse(cat.colorHex.replaceFirst('#', '0xff')))
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount *',
                hintText: '0.00',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter valid amount';
                }
                if (double.parse(value) <= 0) {
                  return 'Amount must be greater than 0';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Date
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date *',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Vendor (Optional)
            TextFormField(
              controller: _vendorController,
              decoration: InputDecoration(
                labelText: 'Vendor (Optional)',
                hintText: 'e.g., Electricity Board, Landlord',
                prefixIcon: const Icon(Icons.business),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Add notes about this expense',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 16),

            // Recurring Expense
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile(
                title: const Text('Recurring Expense'),
                subtitle: const Text('This expense repeats regularly'),
                value: _isRecurring,
                onChanged: (value) => setState(() => _isRecurring = value),
              ),
            ),

            if (_isRecurring) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Frequency',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Monthly'),
                          selected: _recurringFrequency == 'monthly',
                          onSelected: (selected) {
                            setState(() => _recurringFrequency = 'monthly');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Yearly'),
                          selected: _recurringFrequency == 'yearly',
                          onSelected: (selected) {
                            setState(() => _recurringFrequency = 'yearly');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveExpense,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(widget.expense == null ? 'ADD EXPENSE' : 'UPDATE EXPENSE'),
            ),

            const SizedBox(height: 12),

            if (widget.expense == null)
              OutlinedButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        _formKey.currentState?.reset();
                        _titleController.clear();
                        _descriptionController.clear();
                        _amountController.clear();
                        _vendorController.clear();
                        setState(() {
                          _selectedCategory = 'Other';
                          _selectedDate = DateTime.now();
                          _isRecurring = false;
                          _recurringFrequency = null;
                        });
                      },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('CLEAR FORM'),
              ),
          ],
        ),
      ),
    );
  }
}
