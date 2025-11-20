import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'create_invoice_screen.dart';
import 'invoice_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finzobilling/models/invoice_settings.dart';
import 'package:finzobilling/services/invoice_pdf_service.dart';
import 'package:finzobilling/services/audit_service.dart';
import 'screens/amend_invoice_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';

  // 🍎 Apple iOS Premium Colors
  static const Color appleBackground = Color(0xFFFBFBFD);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleText = Color(0xFF1D1D1F);
  static const Color appleSecondary = Color(0xFF86868B);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleDivider = Color(0xFFD2D2D7);
  static const Color appleSubtle = Color(0xFFF5F5F7);

  final List<String> _statusOptions = ['All', 'Paid', 'Unpaid', 'Overdue', 'Void', 'Amended'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildQuery() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return FirebaseFirestore.instance.collection('__non_existent__');

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('invoices')
        .orderBy('createdAt', descending: true);

    if (_statusFilter == 'Amended') {
      query = query.where('isAmended', isEqualTo: true);
    } else if (_statusFilter != 'All') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    return query;
  }

  Future<void> _viewInvoicePDF(DocumentSnapshot<Map<String, dynamic>> invoiceDoc) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: appleCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: appleAccent),
                SizedBox(height: 16),
                Text(
                  'Generating PDF...',
                  style: TextStyle(
                    color: appleText,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('invoice_settings');
      final settings = settingsJson != null 
          ? InvoiceSettings.fromJson(settingsJson) 
          : InvoiceSettings();

      final user = FirebaseAuth.instance.currentUser;
      final businessDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('settings')
          .doc('business_details')
          .get();

      final businessData = businessDoc.data() ?? {};
      final invoiceData = invoiceDoc.data()!;

      final pdfService = InvoicePdfService();
      final pdf = await pdfService.generateInvoicePdf(
        invoiceData: invoiceData,
        businessData: businessData,
        settings: settings,
      );

      if (mounted) Navigator.pop(context);

      if (mounted) {
        final action = await showDialog<String>(
          context: context,
          builder: (context) => _buildAppleDialog(
            title: 'Invoice: ${invoiceData['invoiceNumber']}',
            content: 'Choose an action:',
            actions: [
              _AppleDialogAction(
                label: 'Preview',
                icon: Icons.visibility_outlined,
                onPressed: () => Navigator.pop(context, 'preview'),
              ),
              _AppleDialogAction(
                label: 'Share',
                icon: Icons.share_outlined,
                onPressed: () => Navigator.pop(context, 'share'),
              ),
              _AppleDialogAction(
                label: 'Print',
                icon: Icons.print_outlined,
                onPressed: () => Navigator.pop(context, 'print'),
              ),
              _AppleDialogAction(
                label: 'Cancel',
                icon: Icons.close_rounded,
                isCancel: true,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );

        if (action == 'preview') {
          await pdfService.previewPdf(pdf, context);
        } else if (action == 'share') {
          await pdfService.sharePdf(pdf, 'Invoice_${invoiceData['invoiceNumber']}');
          
          await AuditService().logAction(
            entityType: 'invoice',
            entityId: invoiceDoc.id,
            action: 'SHARE_PDF',
            afterData: {'invoiceNumber': invoiceData['invoiceNumber']},
            reason: 'Invoice PDF shared',
          );
        } else if (action == 'print') {
          await pdfService.printPdf(pdf);
          
          await AuditService().logAction(
            entityType: 'invoice',
            entityId: invoiceDoc.id,
            action: 'PRINT_PDF',
            afterData: {'invoiceNumber': invoiceData['invoiceNumber']},
            reason: 'Invoice PDF printed',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showAppleSnackBar('Error: $e', isError: true);
      }
    }
  }

  Future<void> _changeStatus(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final currentStatus = doc.data()?['status'] ?? 'Unpaid';
    
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => _buildAppleDialog(
        title: 'Change Status',
        content: null,
        customContent: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Paid', 'Unpaid', 'Overdue', 'Void'].map((status) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context, status),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: currentStatus == status 
                        ? appleAccent.withOpacity(0.1) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        currentStatus == status 
                            ? Icons.radio_button_checked 
                            : Icons.radio_button_unchecked,
                        color: currentStatus == status ? appleAccent : appleSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: currentStatus == status 
                              ? FontWeight.w600 
                              : FontWeight.w400,
                          color: appleText,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );

    if (newStatus != null && newStatus != currentStatus) {
      try {
        await doc.reference.update({
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
          if (newStatus == 'Paid') 'paidAt': FieldValue.serverTimestamp(),
        });

        await AuditService().logAction(
          entityType: 'invoice',
          entityId: doc.id,
          action: 'STATUS_CHANGE',
          beforeData: {'status': currentStatus},
          afterData: {'status': newStatus},
          reason: 'Status changed by user',
        );

        if (mounted) {
          _showAppleSnackBar('Status changed to $newStatus');
        }
      } catch (e) {
        if (mounted) {
          _showAppleSnackBar('Error: $e', isError: true);
        }
      }
    }
  }

  Future<void> _deleteInvoice(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _buildAppleDialog(
        title: 'Delete Invoice?',
        content: 'Delete invoice ${doc.data()?['invoiceNumber']}?\n\nStock will be restored.',
        actions: [
          _AppleDialogAction(
            label: 'Cancel',
            icon: Icons.close_rounded,
            isCancel: true,
            onPressed: () => Navigator.pop(context, false),
          ),
          _AppleDialogAction(
            label: 'Delete',
            icon: Icons.delete_outline,
            isDestructive: true,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final batch = FirebaseFirestore.instance.batch();
        final invoiceData = doc.data()!;
        
        final lineItems = invoiceData['lineItems'] as List<dynamic>? ?? [];
        for (var item in lineItems) {
          final productId = item['productId'];
          final quantity = item['quantity'] as num? ?? 0;
          
          if (productId != null) {
            final productRef = FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('products')
                .doc(productId.toString());
            
            batch.update(productRef, {
              'currentStock': FieldValue.increment(quantity.toDouble()),
            });
          }
        }

        batch.update(doc.reference, {
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': user.email,
        });
        
        await batch.commit();

        await AuditService().logAction(
          entityType: 'invoice',
          entityId: doc.id,
          action: 'DELETE',
          beforeData: {
            'invoiceNumber': invoiceData['invoiceNumber'],
            'clientName': invoiceData['clientName'],
            'totalAmount': invoiceData['totalAmount'],
          },
          reason: 'Invoice deleted and stock restored',
        );

        if (mounted) {
          _showAppleSnackBar('Invoice deleted, stock restored');
        }
      } catch (e) {
        if (mounted) {
          _showAppleSnackBar('Error: $e', isError: true);
        }
      }
    }
  }

  void _showActions(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAppleBottomSheet(doc, data),
    );
  }

  Widget _buildAppleBottomSheet(
    DocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic>? data,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: appleDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Invoice Actions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: appleSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            
            const Divider(height: 1, color: appleDivider),
            
            _buildActionTile(
              icon: Icons.picture_as_pdf_outlined,
              title: 'View PDF',
              iconColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _viewInvoicePDF(doc);
              },
            ),
            
            if (data?['isAmended'] != true && data?['status'] != 'Void')
              _buildActionTile(
                icon: Icons.edit_note_outlined,
                title: 'Amend Invoice',
                subtitle: 'Create correction',
                iconColor: Colors.orange,
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AmendInvoiceScreen(
                        invoiceId: doc.id,
                        originalInvoice: data!,
                      ),
                    ),
                  );
                  if (result == true && mounted) {
                    setState(() {});
                  }
                },
              ),
            
            _buildActionTile(
              icon: Icons.swap_horiz_rounded,
              title: 'Change Status',
              iconColor: appleAccent,
              onTap: () {
                Navigator.pop(context);
                _changeStatus(doc);
              },
            ),
            
            _buildActionTile(
              icon: Icons.visibility_outlined,
              title: 'View Details',
              iconColor: Colors.green,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceDetailScreen(invoiceId: doc.id),
                  ),
                );
              },
            ),
            
            const Divider(height: 1, color: appleDivider),
            
            _buildActionTile(
              icon: Icons.delete_outline,
              title: 'Delete',
              iconColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _deleteInvoice(doc);
              },
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
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
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: appleSecondary,
                          letterSpacing: -0.1,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: appleSecondary.withOpacity(0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppleSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
          ),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      backgroundColor: appleBackground,
      body: Column(
        children: [
          // 🍎 Apple-style Search & Filter Header
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
                  // Search Bar
                  Container(
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
                        hintText: 'Search invoices...',
                        hintStyle: TextStyle(
                          color: appleSecondary,
                          fontSize: 15,
                          letterSpacing: -0.2,
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
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Filter Chips
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _statusOptions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final status = _statusOptions[index];
                        final isSelected = _statusFilter == status;
                        
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _statusFilter = status),
                            borderRadius: BorderRadius.circular(18),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? appleAccent 
                                    : appleSubtle,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected 
                                      ? appleAccent 
                                      : appleDivider,
                                  width: isSelected ? 0 : 0.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected 
                                        ? FontWeight.w600 
                                        : FontWeight.w500,
                                    color: isSelected 
                                        ? Colors.white 
                                        : appleText,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Invoice List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Error',
                    subtitle: 'Failed to load invoices',
                  );
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: appleAccent),
                  );
                }

                var docs = snapshot.data?.docs ?? [];

                docs = docs.where((doc) {
                  final isDeleted = doc.data()['isDeleted'] as bool?;
                  return isDeleted != true;
                }).toList();

                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data();
                    final clientName = (data['client']?['name'] ?? data['clientName'] ?? '').toString().toLowerCase();
                    final invoiceNumber = (data['invoiceNumber'] ?? '').toString().toLowerCase();
                    return clientName.contains(_searchQuery.toLowerCase()) ||
                           invoiceNumber.contains(_searchQuery.toLowerCase());
                  }).toList();
                }

                if (docs.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No invoices found',
                    subtitle: _searchQuery.isNotEmpty 
                        ? 'Try a different search' 
                        : 'Create your first invoice',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    return _buildInvoiceCard(doc, data, currency);
                  },
                );
              },
            ),
          ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'invoices-screen-fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
        ),
        backgroundColor: appleAccent,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'New Invoice',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildInvoiceCard(
    DocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
    NumberFormat currency,
  ) {
    final ts = data['createdAt'] as Timestamp?;
    final date = ts != null ? DateFormat.yMMMd().format(ts.toDate()) : 'N/A';
    final status = data['status'] ?? 'Unpaid';
    final totalAmount = currency.format(data['totalAmount'] ?? 0);
    final clientName = data['client']?['name'] ?? data['clientName'] ?? 'No Client';
    final invoiceNumber = data['invoiceNumber'] ?? 'N/A';
    final isAmended = data['isAmended'] == true;
    final isAmendment = data['isAmendment'] == true;
    final originalInvoiceNumber = data['originalInvoiceNumber'];

    return Material(
      color: appleCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _showActions(doc),
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
                // Header Row
                Row(
                  children: [
                    // Status Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: _getStatusColor(status),
                        size: 22,
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Client Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clientName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: appleText,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$invoiceNumber • $date',
                            style: TextStyle(
                              fontSize: 13,
                              color: appleSecondary,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          totalAmount,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: appleText,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _StatusChip(status: status),
                      ],
                    ),
                  ],
                ),
                
                // Amendment Badges
                if (isAmended || isAmendment) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (isAmended)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange.shade700,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'AMENDED',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isAmendment && originalInvoiceNumber != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.update_rounded,
                                color: Colors.blue.shade700,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'From: $originalInvoiceNumber',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
              icon,
              size: 40,
              color: appleSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: appleText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: appleSecondary,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid': return Colors.green;
      case 'Unpaid': return Colors.orange;
      case 'Overdue': return Colors.red;
      case 'Void': return Colors.grey;
      default: return Colors.blueGrey;
    }
  }
}

// 🍎 Apple-style Status Chip
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _getStatusColor() {
    switch (status) {
      case 'Paid': return Colors.green;
      case 'Unpaid': return Colors.orange;
      case 'Overdue': return Colors.red;
      case 'Void': return Colors.grey;
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// 🍎 Apple-style Dialog
Widget _buildAppleDialog({
  required String title,
  String? content,
  Widget? customContent,
  List<_AppleDialogAction>? actions,
}) {
  return Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    backgroundColor: const Color(0xFFFFFFFF),
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
              color: Color(0xFF1D1D1F),
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          if (content != null) ...[
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF86868B),
                letterSpacing: -0.1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (customContent != null) ...[
            const SizedBox(height: 16),
            customContent,
          ],
          if (actions != null) ...[
            const SizedBox(height: 20),
            ...actions.map((action) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: action,
              ),
            )),
          ],
        ],
      ),
    ),
  );
}

// 🍎 Apple-style Dialog Action Button
class _AppleDialogAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isCancel;
  final bool isDestructive;

  const _AppleDialogAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isCancel = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDestructive 
            ? Colors.red 
            : (isCancel ? const Color(0xFFF5F5F7) : const Color(0xFF007AFF)),
        foregroundColor: isCancel ? const Color(0xFF1D1D1F) : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
