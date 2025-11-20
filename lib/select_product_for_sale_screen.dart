// lib/select_product_for_sale_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'line_item.dart';

class SelectProductForSaleScreen extends StatefulWidget {
  const SelectProductForSaleScreen({super.key});

  @override
  State<SelectProductForSaleScreen> createState() => _SelectProductForSaleScreenState();
}

class _SelectProductForSaleScreenState extends State<SelectProductForSaleScreen> {
  String _searchQuery = '';

  // Helper to get the current user's document reference
  DocumentReference<Map<String, dynamic>>? _getUserDocRef() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  Future<void> _showQuantityDialog(DocumentSnapshot productDoc) async {
  final data = productDoc.data() as Map<String, dynamic>;
  
  final productName = data['name'] ?? 'No Name';
  final availableStock = (data['currentStock'] as num?)?.toDouble() ?? 0.0;
  final sellingPrice = (data['sellingPrice'] as num?)?.toDouble() ?? 0.0;
  final hsnSac = data['hsnSac'] ?? '';
  final taxRate = (data['taxRate'] as num?)?.toDouble() ?? 0.0;

  final quantityController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final double? quantityToSell = await showDialog<double>(  // ✅ Return double
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Sell "$productName"'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Stock: ${availableStock.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Price: ₹${sellingPrice.toStringAsFixed(2)}'),
            Text('Tax Rate: ${(taxRate * 100).toStringAsFixed(2)}%'),
            const SizedBox(height: 16),
            TextFormField(
              controller: quantityController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Quantity to Sell *',
                border: OutlineInputBorder(),
                hintText: 'Enter quantity',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter a quantity';
                }
                final qty = double.tryParse(value);
                if (qty == null) {
                  return 'Enter a valid number';
                }
                if (qty <= 0) {
                  return 'Quantity must be positive';
                }
                if (qty > availableStock) {
                  return 'Not enough stock! Available: ${availableStock.toStringAsFixed(2)}';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(context).pop(double.parse(quantityController.text));
            }
          },
          child: const Text('Add to Invoice'),
        ),
      ],
    ),
  );

  if (quantityToSell != null && quantityToSell > 0) {
    // ✅ Create LineItem with double quantity
    final lineItem = LineItem(
      id: productDoc.id,
      name: productName,
      quantity: quantityToSell,  // Now double
      price: sellingPrice,
      hsnSac: hsnSac,
      taxRate: taxRate,
    );
    
    if (mounted) {
      Navigator.of(context).pop(lineItem);
    }
  }
}


  @override
  Widget build(BuildContext context) {
    final userDocRef = _getUserDocRef();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Product'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: userDocRef
            ?.collection('products')
            .orderBy('name')
            .limit(100)  // ✅ ADDED: Limit results for performance
            .snapshots(),
        builder: (context, snapshot) {
          // ✅ IMPROVED: Better error handling
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading products...'),
                ],
              ),
            );
          }

          if (userDocRef == null) {
            return const Center(
              child: Text('Please log in to see products.'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No products found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add products from the Products screen',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          var productDocs = snapshot.data!.docs;

          // ✅ ADDED: Filter by search query
          if (_searchQuery.isNotEmpty) {
            productDocs = productDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString().toLowerCase();
              final hsnSac = (data['hsnSac'] ?? '').toString().toLowerCase();
              return name.contains(_searchQuery) || hsnSac.contains(_searchQuery);
            }).toList();
          }

          if (productDocs.isEmpty && _searchQuery.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No products match "$_searchQuery"',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: productDocs.length,
            itemBuilder: (context, index) {
              final doc = productDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              // ✅ FIXED: Use correct field names
              final productName = data['name'] ?? 'Unnamed Product';
              final stock = (data['currentStock'] as num?)?.toDouble() ?? 0.0;  // Changed
              final price = (data['sellingPrice'] as num?)?.toDouble() ?? 0.0;  // Changed
              final hsnSac = data['hsnSac'] ?? '';
              final taxRate = (data['taxRate'] as num?)?.toDouble() ?? 0.0;
              final bool inStock = stock > 0;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: inStock ? Colors.green : Colors.red,
                    child: Text(
                      productName.isNotEmpty ? productName[0].toUpperCase() : 'P',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    productName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Stock: ${stock.toStringAsFixed(2)} | Price: ₹${price.toStringAsFixed(2)}'),
                      if (hsnSac.isNotEmpty)
                        Text('HSN/SAC: $hsnSac', style: const TextStyle(fontSize: 11)),
                      Text('Tax: ${(taxRate * 100).toStringAsFixed(2)}%', 
                           style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  trailing: inStock
                      ? const Icon(Icons.add_circle, color: Colors.green)
                      : const Icon(Icons.block, color: Colors.red),
                  onTap: inStock ? () => _showQuantityDialog(doc) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
