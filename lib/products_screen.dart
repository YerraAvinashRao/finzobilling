import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:finzobilling/models/product_model.dart';
import 'package:finzobilling/widgets/add_edit_product_dialog.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortBy = 'name'; // name, stock, price
  bool _showLowStockOnly = false;
  bool _showInactiveProducts = false;

  // 🍎 Apple iOS Premium Colors
  static const Color appleBackground = Color(0xFFFBFBFD);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleText = Color(0xFF1D1D1F);
  static const Color appleSecondary = Color(0xFF86868B);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleDivider = Color(0xFFD2D2D7);
  static const Color appleSubtle = Color(0xFFF5F5F7);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CollectionReference _getProductsCollection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in!');
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('products');
  }

  List<ProductModel> _filterAndSortProducts(List<QueryDocumentSnapshot> docs) {
    // Convert to ProductModel
    List<ProductModel> products = docs
        .map((doc) => ProductModel.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
        .toList();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      products = products.where((p) {
        final query = _searchQuery.toLowerCase();
        return p.name.toLowerCase().contains(query) ||
            (p.sku?.toLowerCase().contains(query) ?? false) ||
            (p.barcode?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Filter by category
    if (_selectedCategory != 'All') {
      products = products.where((p) => p.category == _selectedCategory).toList();
    }

    // Filter by active status
    if (!_showInactiveProducts) {
      products = products.where((p) => p.isActive).toList();
    }

    // Filter by low stock
    if (_showLowStockOnly) {
      products = products.where((p) => p.isLowStock).toList();
    }

    // Sort products
    switch (_sortBy) {
      case 'name':
        products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'stock':
        products.sort((a, b) => a.currentStock.compareTo(b.currentStock));
        break;
      case 'price':
        products.sort((a, b) => b.sellingPrice.compareTo(a.sellingPrice));
        break;
    }

    return products;
  }

  Future<void> _showAddEditDialog({ProductModel? product}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddEditProductDialog(product: product),
    );
    if (result == true) {
      setState(() {}); // Refresh list
    }
  }

  Future<void> _toggleProductStatus(ProductModel product) async {
    try {
      await _getProductsCollection().doc(product.id).update({
        'isActive': !product.isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        _showSnackBar(product.isActive ? 'Product deactivated' : 'Product activated');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirm = await _showConfirmDialog(
      'Delete Product?',
      'Are you sure you want to delete "${product.name}"?\n\nThis action cannot be undone.',
    );

    if (confirm != true) return;

    try {
      await _getProductsCollection().doc(product.id).delete();
      
      if (mounted) {
        _showSnackBar('Product deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  Future<bool?> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: appleText,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: TextStyle(
                  fontSize: 14,
                  color: appleSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildDialogButton('Cancel', Icons.close_rounded, () => Navigator.pop(context, false), isCancel: true),
              const SizedBox(height: 8),
              _buildDialogButton('Delete', Icons.delete_outline, () => Navigator.pop(context, true), isDestructive: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogButton(String label, IconData icon, VoidCallback onPressed, {bool isCancel = false, bool isDestructive = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive 
              ? Colors.red 
              : (isCancel ? appleSubtle : appleAccent),
          foregroundColor: isCancel ? appleText : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: appleCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: appleDivider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filter & Sort',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: appleText,
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = 'All';
                                _sortBy = 'name';
                                _showLowStockOnly = false;
                                _showInactiveProducts = false;
                              });
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Reset'),
                          ),
                        ],
                      ),
                      
                      Divider(height: 24, color: appleDivider.withOpacity(0.5)),
                      
                      // Category Filter
                      const Text(
                        'Category',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: appleText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['All', ...ProductCategories.all].map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() => _selectedCategory = cat);
                                setModalState(() {});
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? appleAccent : appleSubtle,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? appleAccent : appleDivider,
                                    width: isSelected ? 0 : 0.5,
                                  ),
                                ),
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected ? Colors.white : appleText,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // Sort Options
                      const Text(
                        'Sort By',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: appleText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      ...[
                        _buildSortOption('name', 'Name', Icons.sort_by_alpha_rounded, setModalState),
                        _buildSortOption('stock', 'Stock', Icons.inventory_rounded, setModalState),
                        _buildSortOption('price', 'Price', Icons.currency_rupee_rounded, setModalState),
                      ],

                      const SizedBox(height: 24),

                      // Filters
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: appleText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      _buildFilterSwitch(
                        'Low Stock Only',
                        'Show products below reorder level',
                        _showLowStockOnly,
                        (val) {
                          setState(() => _showLowStockOnly = val);
                          setModalState(() {});
                        },
                      ),

                      _buildFilterSwitch(
                        'Include Inactive Products',
                        'Show deactivated products',
                        _showInactiveProducts,
                        (val) {
                          setState(() => _showInactiveProducts = val);
                          setModalState(() {});
                        },
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortOption(String value, String label, IconData icon, StateSetter setModalState) {
    final isSelected = _sortBy == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _sortBy = value);
          setModalState(() {});
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? appleAccent.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? appleAccent : appleDivider.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? appleAccent : appleSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Icon(icon, color: isSelected ? appleAccent : appleSecondary, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: appleText,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSwitch(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appleSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: appleText,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: appleSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: appleAccent,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      backgroundColor: appleBackground,
      body: Column(
        children: [
          // Search Bar & Filters
          Container(
            decoration: BoxDecoration(
              color: appleCard,
              border: Border(
                bottom: BorderSide(
                  color: appleDivider.withOpacity(0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: appleSubtle,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(
                              fontSize: 15,
                              color: appleText,
                              letterSpacing: -0.2,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search products...',
                              hintStyle: TextStyle(
                                color: appleSecondary,
                                fontSize: 15,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: appleSecondary,
                                size: 20,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.cancel_rounded,
                                        color: appleSecondary,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: (_selectedCategory != 'All' || _showLowStockOnly)
                              ? appleAccent
                              : appleSubtle,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: _showFilterSheet,
                          icon: Icon(
                            Icons.tune_rounded,
                            color: (_selectedCategory != 'All' || _showLowStockOnly)
                                ? Colors.white
                                : appleSecondary,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Active Filters
                  if (_selectedCategory != 'All' || _showLowStockOnly)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (_selectedCategory != 'All')
                            _buildFilterChip(_selectedCategory, () {
                              setState(() => _selectedCategory = 'All');
                            }),
                          if (_showLowStockOnly)
                            _buildFilterChip('Low Stock', () {
                              setState(() => _showLowStockOnly = false);
                            }, isWarning: true),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Products List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getProductsCollection().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: appleSecondary),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}', style: TextStyle(color: appleSecondary)),
                      ],
                    ),
                  );
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: appleAccent));
                }

                final docs = snapshot.data?.docs ?? [];
                final products = _filterAndSortProducts(docs);

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: appleSubtle,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.inventory_2_rounded,
                            size: 40,
                            color: appleSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _searchQuery.isEmpty ? 'No products found' : 'No matching products',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: appleText,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add products to get started',
                          style: TextStyle(
                            fontSize: 14,
                            color: appleSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _showAddEditDialog(),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text('Add First Product'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isLowStock = product.isLowStock;

                    return Material(
                      color: appleCard,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(productId: product.id),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: appleDivider.withOpacity(0.3),
                              width: 0.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Product Icon
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: appleAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.inventory_2_rounded,
                                        color: appleAccent,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Product Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  product.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                    color: appleText,
                                                    letterSpacing: -0.3,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (!product.isActive)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'Inactive',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                product.category,
                                                style: TextStyle(
                                                  color: appleSecondary,
                                                  fontSize: 13,
                                                  letterSpacing: -0.1,
                                                ),
                                              ),
                                              if (product.sku != null) ...[
                                                Text(
                                                  ' • ',
                                                  style: TextStyle(color: appleSecondary),
                                                ),
                                                Flexible(
                                                  child: Text(
                                                    'SKU: ${product.sku}',
                                                    style: TextStyle(
                                                      color: appleSecondary,
                                                      fontSize: 13,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Actions
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () => _showAddEditDialog(product: product),
                                          icon: const Icon(Icons.edit_outlined, size: 20),
                                          color: appleAccent,
                                          tooltip: 'Edit',
                                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                          padding: EdgeInsets.zero,
                                        ),
                                        PopupMenuButton<String>(
                                          icon: Icon(Icons.more_vert_rounded, color: appleSecondary, size: 20),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          onSelected: (value) {
                                            switch (value) {
                                              case 'toggle':
                                                _toggleProductStatus(product);
                                                break;
                                              case 'delete':
                                                _deleteProduct(product);
                                                break;
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'toggle',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    product.isActive 
                                                        ? Icons.visibility_off_outlined 
                                                        : Icons.visibility_outlined,
                                                    size: 20,
                                                    color: appleText,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    product.isActive ? 'Deactivate' : 'Activate',
                                                    style: const TextStyle(fontSize: 14),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuDivider(),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                                  SizedBox(width: 12),
                                                  Text(
                                                    'Delete',
                                                    style: TextStyle(color: Colors.red, fontSize: 14),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                Divider(height: 24, color: appleDivider.withOpacity(0.5)),

                                // Price & Stock Info
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoColumn(
                                        'Selling Price',
                                        currencyFormat.format(product.sellingPrice),
                                        color: appleAccent,
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 36,
                                      color: appleDivider.withOpacity(0.3),
                                    ),
                                    Expanded(
                                      child: _buildInfoColumn(
                                        'Stock',
                                        '${product.currentStock} ${product.unit}',
                                        color: isLowStock ? Colors.red : Colors.green,
                                        showWarning: isLowStock,
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 36,
                                      color: appleDivider.withOpacity(0.3),
                                    ),
                                    Expanded(
                                      child: _buildInfoColumn(
                                        'GST',
                                        '${product.gstRate.toStringAsFixed(product.gstRate % 1 == 0 ? 0 : 1)}%',
                                        color: appleText,
                                      ),
                                    ),
                                  ],
                                ),

                                // Low Stock Alert
                                if (isLowStock)
                                  Container(
                                    margin: const EdgeInsets.only(top: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 18,
                                          color: Colors.red.shade700,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Low Stock: Reorder at ${product.reorderLevel} ${product.unit}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDelete, {bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 8, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: isWarning ? Colors.orange.shade50 : appleSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWarning ? Colors.orange.shade200 : appleDivider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isWarning ? Colors.orange.shade900 : appleText,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(10),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: isWarning ? Colors.orange.shade900 : appleSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, {Color? color, bool showWarning = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: appleSecondary,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: color ?? appleText,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showWarning) ...[
              const SizedBox(width: 4),
              Icon(Icons.warning_rounded, size: 14, color: Colors.red),
            ],
          ],
        ),
      ],
    );
  }
}
