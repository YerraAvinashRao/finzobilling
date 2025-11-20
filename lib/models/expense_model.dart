import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final String? vendor;
  final String? receiptUrl;
  final bool isRecurring;
  final String? recurringFrequency;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.vendor,
    this.receiptUrl,
    this.isRecurring = false,
    this.recurringFrequency,
    required this.createdAt,
    this.updatedAt,
  });

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] ?? 'Other',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      vendor: data['vendor'],
      receiptUrl: data['receiptUrl'],
      isRecurring: data['isRecurring'] ?? false,
      recurringFrequency: data['recurringFrequency'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'vendor': vendor,
      'receiptUrl': receiptUrl,
      'isRecurring': isRecurring,
      'recurringFrequency': recurringFrequency,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

class ExpenseCategory {
  final String name;
  final String icon;
  final String colorHex;

  const ExpenseCategory({
    required this.name,
    required this.icon,
    required this.colorHex,
  });

  static const List<ExpenseCategory> defaultCategories = [
    ExpenseCategory(name: 'Rent', icon: '🏢', colorHex: '#FF6B6B'),
    ExpenseCategory(name: 'Salary', icon: '💰', colorHex: '#4ECDC4'),
    ExpenseCategory(name: 'Utilities', icon: '💡', colorHex: '#45B7D1'),
    ExpenseCategory(name: 'Marketing', icon: '📢', colorHex: '#F7B731'),
    ExpenseCategory(name: 'Travel', icon: '✈️', colorHex: '#5F27CD'),
    ExpenseCategory(name: 'Office Supplies', icon: '📎', colorHex: '#00D2D3'),
    ExpenseCategory(name: 'Equipment', icon: '🖥️', colorHex: '#FF9FF3'),
    ExpenseCategory(name: 'Maintenance', icon: '🔧', colorHex: '#54A0FF'),
    ExpenseCategory(name: 'Insurance', icon: '🛡️', colorHex: '#48DBFB'),
    ExpenseCategory(name: 'Taxes', icon: '📊', colorHex: '#EE5A6F'),
    ExpenseCategory(name: 'Professional Fees', icon: '👔', colorHex: '#C44569'),
    ExpenseCategory(name: 'Communication', icon: '📱', colorHex: '#786FA6'),
    ExpenseCategory(name: 'Food & Beverage', icon: '🍽️', colorHex: '#F8B500'),
    ExpenseCategory(name: 'Training', icon: '📚', colorHex: '#58B19F'),
    ExpenseCategory(name: 'Other', icon: '📦', colorHex: '#95A5A6'),
  ];

  static ExpenseCategory getCategory(String name) {
    return defaultCategories.firstWhere(
      (cat) => cat.name == name,
      orElse: () => defaultCategories.last,
    );
  }
}
