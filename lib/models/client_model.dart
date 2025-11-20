import 'package:cloud_firestore/cloud_firestore.dart';

class ClientModel {
  final String id;
  final String userId;
  final String name;
  final String? email;
  final String? phone;
  final String? gstin;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final double creditLimit;
  final int creditDays;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ClientModel({
    required this.id,
    required this.userId,
    required this.name,
    this.email,
    this.phone,
    this.gstin,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.creditLimit = 0.0,
    this.creditDays = 30,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory ClientModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClientModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'],
      phone: data['phone'],
      gstin: data['gstin'],
      address: data['address'],
      city: data['city'],
      state: data['state'],
      pincode: data['pincode'],
      creditLimit: (data['creditLimit'] as num?)?.toDouble() ?? 0.0,
      creditDays: data['creditDays'] ?? 30,
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'gstin': gstin,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'creditLimit': creditLimit,
      'creditDays': creditDays,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

class ClientLedgerEntry {
  final String id;
  final String clientId;
  final String type; // invoice, payment, credit_note, debit_note
  final String? referenceNumber;
  final DateTime date;
  final double debit;
  final double credit;
  final double balance;
  final String? description;

  ClientLedgerEntry({
    required this.id,
    required this.clientId,
    required this.type,
    this.referenceNumber,
    required this.date,
    required this.debit,
    required this.credit,
    required this.balance,
    this.description,
  });
}
