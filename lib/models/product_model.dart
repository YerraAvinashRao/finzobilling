import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? hsnCode;
  final String category;
  final String unit; // Pcs, Kg, Ltr, Box, etc.
  final double sellingPrice;
  final double? purchasePrice;
  final double? mrp;
  final int currentStock;
  final int? openingStock;
  final int? reorderLevel;
  final double gstRate; // 0, 5, 12, 18, 28
  final String? description;
  final String? imageUrl;
  final bool trackInventory;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  ProductModel({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.hsnCode,
    required this.category,
    required this.unit,
    required this.sellingPrice,
    this.purchasePrice,
    this.mrp,
    required this.currentStock,
    this.openingStock,
    this.reorderLevel,
    required this.gstRate,
    this.description,
    this.imageUrl,
    this.trackInventory = true,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  // Check if low stock
  bool get isLowStock => reorderLevel != null && currentStock <= reorderLevel!;

  // Calculate profit margin
  double? get profitMargin {
    if (purchasePrice == null || purchasePrice == 0) return null;
    return ((sellingPrice - purchasePrice!) / purchasePrice!) * 100;
  }

  // Stock value
  double get stockValue => currentStock * sellingPrice;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'hsnCode': hsnCode,
      'category': category,
      'unit': unit,
      'sellingPrice': sellingPrice,
      'purchasePrice': purchasePrice,
      'mrp': mrp,
      'currentStock': currentStock,
      'openingStock': openingStock,
      'reorderLevel': reorderLevel,
      'gstRate': gstRate,
      'description': description,
      'imageUrl': imageUrl,
      'trackInventory': trackInventory,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
    };
  }

  // Safe integer conversion helper
  static int _safeToInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return defaultValue;
  }

  // Safe nullable integer conversion helper
  static int? _safeToIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return null;
  }

  factory ProductModel.fromFirestore(String id, Map<String, dynamic> data) {
    return ProductModel(
      id: id,
      name: data['name'] as String,
      sku: data['sku'] as String?,
      barcode: data['barcode'] as String?,
      hsnCode: data['hsnCode'] as String?,
      category: data['category'] as String? ?? 'General',
      unit: data['unit'] as String? ?? 'Pcs',
      sellingPrice: (data['sellingPrice'] ?? data['price'] ?? 0).toDouble(),
      purchasePrice: (data['purchasePrice'] as num?)?.toDouble(),
      mrp: (data['mrp'] as num?)?.toDouble(),
      // ✅ FIXED: Safe conversion for int fields
      currentStock: _safeToInt(data['currentStock'] ?? data['quantity'], 0),
      openingStock: _safeToIntNullable(data['openingStock']),
      reorderLevel: _safeToIntNullable(data['reorderLevel']),
      gstRate: (data['gstRate'] ?? 18.0).toDouble(),
      description: data['description'] as String?,
      imageUrl: data['imageUrl'] as String?,
      trackInventory: data['trackInventory'] as bool? ?? true,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  ProductModel copyWith({
    String? name,
    String? sku,
    String? barcode,
    String? hsnCode,
    String? category,
    String? unit,
    double? sellingPrice,
    double? purchasePrice,
    double? mrp,
    int? currentStock,
    int? openingStock,
    int? reorderLevel,
    double? gstRate,
    String? description,
    String? imageUrl,
    bool? trackInventory,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      hsnCode: hsnCode ?? this.hsnCode,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      mrp: mrp ?? this.mrp,
      currentStock: currentStock ?? this.currentStock,
      openingStock: openingStock ?? this.openingStock,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      gstRate: gstRate ?? this.gstRate,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      trackInventory: trackInventory ?? this.trackInventory,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      createdBy: createdBy,
    );
  }
}

// Product Categories (Indian business standard)
class ProductCategories {
  static const List<String> all = [
    'General',
    'Electronics',
    'Clothing & Apparel',
    'Food & Beverages',
    'Furniture',
    'Building Materials',
    'Medicines & Healthcare',
    'Beauty & Cosmetics',
    'Stationery & Office Supplies',
    'Automobile Parts',
    'Agricultural Products',
    'Jewelry & Accessories',
    'Books & Publications',
    'Sports & Fitness',
    'Toys & Games',
    'Home & Kitchen',
    'Industrial Equipment',
    'Chemicals & Raw Materials',
  ];
}

// Units of Measurement (Indian standard)
class ProductUnits {
  static const List<String> all = [
    'Pcs', // Pieces
    'Kg', // Kilogram
    'Gm', // Gram
    'Ltr', // Liter
    'Ml', // Milliliter
    'Box',
    'Carton',
    'Dozen',
    'Set',
    'Pair',
    'Meter',
    'Feet',
    'Quintal',
    'Tonne',
    'Bundle',
    'Roll',
    'Pack',
  ];
}

// GST Rates (India)
class GSTRates {
  static const List<double> all = [0, 5, 12, 18, 28];
}
