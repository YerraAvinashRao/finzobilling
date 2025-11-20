import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseModel {
  final String id;
  final String userId;
  final String purchaseNumber;
  final String supplierId;
  final String supplierName;
  final DateTime purchaseDate;
  final List<PurchaseItem> items;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final String status; // pending, received, partial
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PurchaseModel({
    required this.id,
    required this.userId,
    required this.purchaseNumber,
    required this.supplierId,
    required this.supplierName,
    required this.purchaseDate,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    required this.status,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory PurchaseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    final itemsList = data['items'] as List<dynamic>? ?? [];
    final items = itemsList.map((item) => PurchaseItem.fromMap(item as Map<String, dynamic>)).toList();

    return PurchaseModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      purchaseNumber: data['purchaseNumber'] ?? '',
      supplierId: data['supplierId'] ?? '',
      supplierName: data['supplierName'] ?? '',
      purchaseDate: (data['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: items,
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (data['taxAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'pending',
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'purchaseNumber': purchaseNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'status': status,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

class PurchaseItem {
  final String productId;
  final String productName;
  final int quantity;
  final double purchasePrice;
  final double total;

  PurchaseItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.purchasePrice,
    required this.total,
  });

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'total': total,
    };
  }
}
