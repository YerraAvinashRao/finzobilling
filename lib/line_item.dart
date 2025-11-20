import 'package:uuid/uuid.dart';

class LineItem {
  final String? id;
  final String name;
  final double quantity;
  final double price; // ✅ Tax-INCLUSIVE selling price per unit
  final double taxRate; // e.g., 0.18 for 18%
  final String? hsnSac;
  final double? costPrice; // Nullable cost price
  final double discountPercent;  // ✅ NEW: Line-item discount %
  final double discountAmount;   // ✅ NEW: Line-item discount ₹

  LineItem({
    String? id,
    required this.name,
    required this.quantity,
    required this.price,
    this.taxRate = 0.0,
    this.hsnSac,
    this.costPrice,
    this.discountPercent = 0,    // ✅ NEW: Default 0%
    this.discountAmount = 0,     // ✅ NEW: Default ₹0
  }) : id = id ?? const Uuid().v4();

  // ✅ BACKWARD TAX CALCULATION (Tax-Inclusive Pricing)
  // Formula: Taxable Value = Price / (1 + Tax Rate)
  
  double get baseUnitPrice => price / (1 + taxRate); // Price without tax
  
  // ✅ UPDATED: Calculate subtotal and discount first
  double get subtotalBeforeDiscount => price * quantity; // Total before discount
  
  // ✅ NEW: Calculate discount value
  double get totalDiscount {
    return discountAmount > 0 
        ? discountAmount 
        : subtotalBeforeDiscount * (discountPercent / 100);
  }
  
  // ✅ UPDATED: Line total after discount (replaces old lineTotal)
  double get lineTotal => subtotalBeforeDiscount - totalDiscount;
  
  // ✅ Tax calculations based on line total (after discount)
  double get taxableValue => lineTotal / (1 + taxRate); // Taxable amount after discount
  double get totalTaxAmount => lineTotal - taxableValue; // Total tax
  
  // For display purposes (assuming intra-state by default)
  double get cgstAmount => totalTaxAmount / 2;
  double get sgstAmount => totalTaxAmount / 2;
  double get igstAmount => totalTaxAmount; // For inter-state

  Map<String, dynamic> toMap() {
    double round2(double v) => double.parse(v.toStringAsFixed(2));

    return {
      'productId': id,
      'productName': name,
      'quantity': round2(quantity),
      'price': round2(price), // Tax-inclusive price
      'hsnSac': hsnSac,
      'taxRate': taxRate,
      'discountPercent': round2(discountPercent),      // ✅ NEW
      'discountAmount': round2(discountAmount),        // ✅ NEW
      'totalDiscount': round2(totalDiscount),          // ✅ NEW
      'subtotal': round2(subtotalBeforeDiscount),      // ✅ NEW
      'taxableValue': round2(taxableValue),
      'cgstAmount': round2(cgstAmount),
      'sgstAmount': round2(sgstAmount),
      'igstAmount': round2(igstAmount),
      'totalTaxAmount': round2(totalTaxAmount),
      'lineTotal': round2(lineTotal),
      'costPrice': costPrice,
    };
  }

  factory LineItem.fromMap(Map<String, dynamic> map) {
    double numToDouble(dynamic v, {double fallback = 0.0}) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return fallback;
    }

    String toStringValue(dynamic v, {String fallback = ''}) {
      if (v == null) return fallback;
      if (v is String) return v;
      return fallback;
    }

    return LineItem(
      id: toStringValue(map['productId'], fallback: const Uuid().v4()),
      name: toStringValue(map['productName'], fallback: ''),
      quantity: numToDouble(map['quantity'], fallback: 1.0),
      price: numToDouble(map['price'], fallback: 0.0),
      taxRate: numToDouble(map['taxRate'], fallback: 0.0),
      hsnSac: map['hsnSac'] is String ? map['hsnSac'] as String : null,
      costPrice: (map['costPrice'] is num) ? (map['costPrice'] as num).toDouble() : null,
      discountPercent: numToDouble(map['discountPercent'], fallback: 0.0),  // ✅ NEW
      discountAmount: numToDouble(map['discountAmount'], fallback: 0.0),    // ✅ NEW
    );
  }

  LineItem copyWith({
    String? id,
    String? name,
    double? quantity,
    double? price,
    double? taxRate,
    String? hsnSac,
    double? costPrice,
    double? discountPercent,  // ✅ NEW
    double? discountAmount,   // ✅ NEW
  }) {
    return LineItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      taxRate: taxRate ?? this.taxRate,
      hsnSac: hsnSac ?? this.hsnSac,
      costPrice: costPrice ?? this.costPrice,
      discountPercent: discountPercent ?? this.discountPercent,  // ✅ NEW
      discountAmount: discountAmount ?? this.discountAmount,      // ✅ NEW
    );
  }
}
