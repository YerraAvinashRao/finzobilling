// lib/models/invoice_purchase_item.dart
class InvoicePurchaseItem {
  String productName;
  int quantity;
  double costPrice;
  double sellingPrice;
  double taxRate; // e.g., 0.18 for 18%
  String? hsnSac;
  String? unit;

  InvoicePurchaseItem({
    required this.productName,
    required this.quantity,
    required this.costPrice,
    required this.sellingPrice,
    this.taxRate = 0.0,
    this.hsnSac,
    this.unit,
  });

  double get taxableValue => quantity * costPrice;
  double get totalTax => taxableValue * taxRate;
  double get cgstAmount => totalTax / 2;
  double get sgstAmount => totalTax / 2;
  double get igstAmount => totalTax; // If interstate

  double get lineTotal => taxableValue + totalTax;

  Map<String, dynamic> toMap() => {
        'productName': productName,
        'quantity': quantity,
        'costPrice': costPrice,
        'sellingPrice': sellingPrice,
        'taxRate': taxRate,
        'hsnSac': hsnSac,
        'unit': unit,
        'taxableValue': taxableValue,
        'totalTaxAmount': totalTax,
        'cgstAmount': cgstAmount,
        'sgstAmount': sgstAmount,
        'igstAmount': igstAmount,
        'lineTotal': lineTotal,
      };
}
