import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  final String id;
  final String invoiceId;
  final double amount;
  final String method; // 'Cash', 'UPI', 'Bank Transfer', 'Card', 'Cheque'
  final DateTime paymentDate;
  final String? reference; // Transaction ID, Cheque number, etc.
  final String? notes;
  final String createdBy;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.method,
    required this.paymentDate,
    this.reference,
    this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'invoiceId': invoiceId,
      'amount': amount,
      'method': method,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'reference': reference,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore document
  factory Payment.fromFirestore(String id, Map<String, dynamic> data) {
    return Payment(
      id: id,
      invoiceId: data['invoiceId'] as String,
      amount: (data['amount'] as num).toDouble(),
      method: data['method'] as String,
      paymentDate: (data['paymentDate'] as Timestamp).toDate(),
      reference: data['reference'] as String?,
      notes: data['notes'] as String?,
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Copy with modifications
  Payment copyWith({
    String? id,
    String? invoiceId,
    double? amount,
    String? method,
    DateTime? paymentDate,
    String? reference,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return Payment(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      paymentDate: paymentDate ?? this.paymentDate,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
