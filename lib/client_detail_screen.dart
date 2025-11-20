import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ Add for call/email features

class ClientDetailScreen extends StatefulWidget {
  final String clientName;
  final Map<String, dynamic>? clientData;
  
  const ClientDetailScreen({
    super.key,
    required this.clientName,
    this.clientData,
  });

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  String? _userId;
  late TabController _tabController;

  // 🍎 Apple iOS Premium Colors
  static const Color appleBackground = Color(0xFFFBFBFD);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleText = Color(0xFF1D1D1F);
  static const Color appleSecondary = Color(0xFF86868B);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleDivider = Color(0xFFD2D2D7);
  static const Color appleSubtle = Color(0xFFF5F5F7);

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getClientStats() async {
    if (_userId == null) return {};

    try {
      final invoicesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('invoices')
          .where('clientName', isEqualTo: widget.clientName)
          .get();

      double totalBilled = 0;
      double totalPaid = 0;
      double outstanding = 0;
      int paidCount = 0;
      int unpaidCount = 0;
      int partialCount = 0;

      for (var doc in invoicesSnapshot.docs) {
        final data = doc.data();
        final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;
        final status = data['status'] as String?;

        totalBilled += total;

        if (status == 'Paid') {
          totalPaid += total;
          paidCount++;
        } else if (status == 'Unpaid') {
          outstanding += total;
          unpaidCount++;
        } else if (status == 'Partially Paid') {
          final payments = data['payments'] as List<dynamic>? ?? [];
          double paidAmount = 0;
          for (var payment in payments) {
            paidAmount += (payment['amount'] as num?)?.toDouble() ?? 0;
          }
          totalPaid += paidAmount;
          outstanding += (total - paidAmount);
          partialCount++;
        }
      }

      return {
        'totalBilled': totalBilled,
        'totalPaid': totalPaid,
        'outstanding': outstanding,
        'invoiceCount': invoicesSnapshot.docs.length,
        'paidCount': paidCount,
        'unpaidCount': unpaidCount,
        'partialCount': partialCount,
      };
    } catch (e) {
      debugPrint('Error getting client stats: $e');
      return {};
    }
  }

  // ✅ NEW: Call client
  Future<void> _callClient() async {
    final phone = widget.clientData?['phone'];
    if (phone == null) {
      _showSnackBar('No phone number available', isError: true);
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ✅ NEW: Email client
  Future<void> _emailClient() async {
    final email = widget.clientData?['email'];
    if (email == null) {
      _showSnackBar('No email available', isError: true);
      return;
    }
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        backgroundColor: appleBackground,
        body: const Center(child: Text('Please log in')),
      );
    }

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: appleBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: appleCard.withOpacity(0.8),
                border: Border(
                  bottom: BorderSide(
                    color: appleDivider.withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: appleText, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  widget.clientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: appleText,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  // ✅ Call button
                  if (widget.clientData?['phone'] != null)
                    IconButton(
                      icon: const Icon(Icons.phone_rounded, color: appleAccent, size: 22),
                      onPressed: _callClient,
                      tooltip: 'Call',
                    ),
                  // ✅ Email button
                  if (widget.clientData?['email'] != null)
                    IconButton(
                      icon: const Icon(Icons.email_rounded, color: appleAccent, size: 22),
                      onPressed: _emailClient,
                      tooltip: 'Email',
                    ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: appleAccent, size: 22),
                    onPressed: _generateStatement,
                    tooltip: 'Download Statement',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getClientStats(),
        builder: (context, statsSnapshot) {
          if (!statsSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: appleAccent),
            );
          }

          final stats = statsSnapshot.data!;

          return Column(
            children: [
              // Client Info Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      appleAccent.withOpacity(0.05),
                      appleBackground,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    // Client Avatar
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            appleAccent.withOpacity(0.2),
                            appleAccent.withOpacity(0.4),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: appleAccent.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.clientName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            color: appleAccent,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.clientName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: appleText,
                        letterSpacing: -0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.clientData?['phone'] != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone_rounded, size: 14, color: appleSecondary),
                          const SizedBox(width: 6),
                          Text(
                            widget.clientData!['phone'],
                            style: TextStyle(
                              fontSize: 14,
                              color: appleSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.clientData?['email'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.email_rounded, size: 14, color: appleSecondary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.clientData!['email'],
                              style: TextStyle(
                                fontSize: 14,
                                color: appleSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),

                    // ✅ ADD THESE PROMINENT QUICK ACTION BUTTONS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.clientData?['phone'] != null)
                          _buildQuickActionButton(
                            Icons.phone_rounded,
                            'Call',
                            appleAccent,
                            _callClient,
                          ),
                        if (widget.clientData?['phone'] != null && widget.clientData?['email'] != null)
                          const SizedBox(width: 12),
                        if (widget.clientData?['email'] != null)
                          _buildQuickActionButton(
                            Icons.email_rounded,
                            'Email',
                            Colors.green,
                            _emailClient,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Stats Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Billed',
                            currency.format(stats['totalBilled'] ?? 0),
                            Icons.receipt_long_rounded,
                            appleAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            'Paid',
                            currency.format(stats['totalPaid'] ?? 0),
                            Icons.check_circle_rounded,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            'Outstanding',
                            currency.format(stats['outstanding'] ?? 0),
                            Icons.pending_rounded,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tabs
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
                child: TabBar(
                  controller: _tabController,
                  labelColor: appleAccent,
                  unselectedLabelColor: appleSecondary,
                  indicatorColor: appleAccent,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  tabs: const [
                    Tab(text: 'Invoices'),
                    Tab(text: 'Payments'),
                    Tab(text: 'Info'),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInvoicesTab(),
                    _buildPaymentsTab(),
                    _buildInfoTab(stats),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
    Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: appleSecondary,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('invoices')
          .where('clientName', isEqualTo: widget.clientName)
          .orderBy('invoiceDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: appleAccent),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: appleSubtle,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 40,
                    color: appleSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No invoices yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: appleText,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildInvoiceCard(data);
          },
        );
      },
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final status = invoice['status'] ?? 'Unpaid';
    final date = (invoice['invoiceDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final amount = (invoice['totalAmount'] as num?)?.toDouble() ?? 0;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Paid':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Partially Paid':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      default:
        statusColor = Colors.red;
        statusIcon = Icons.pending_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(14),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Navigate to invoice detail
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice['invoiceNumber'] ?? 'N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: appleText,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(date),
                        style: TextStyle(
                          fontSize: 13,
                          color: appleSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.format(amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: appleText,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('invoices')
          .where('clientName', isEqualTo: widget.clientName)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: appleAccent),
          );
        }

        List<Map<String, dynamic>> allPayments = [];

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final payments = data['payments'] as List<dynamic>? ?? [];
          final invoiceNumber = data['invoiceNumber'] ?? 'N/A';

          for (var payment in payments) {
            allPayments.add({
              'invoiceNumber': invoiceNumber,
              'amount': payment['amount'],
              'date': payment['date'],
              'method': payment['method'] ?? 'Cash',
            });
          }
        }

        allPayments.sort((a, b) {
          final dateA = (a['date'] as Timestamp?)?.toDate() ?? DateTime.now();
          final dateB = (b['date'] as Timestamp?)?.toDate() ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        if (allPayments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: appleSubtle,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.payments_rounded,
                    size: 40,
                    color: appleSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No payments received yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: appleText,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: allPayments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildPaymentCard(allPayments[index]);
          },
        );
      },
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final date = (payment['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(14),
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
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade100,
                    Colors.green.shade200,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.payments_rounded,
                color: Colors.green.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice: ${payment['invoiceNumber']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: appleText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 12, color: appleSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: appleSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.account_balance_wallet_rounded, size: 12, color: appleSecondary),
                      const SizedBox(width: 4),
                      Text(
                        payment['method'],
                        style: TextStyle(
                          fontSize: 12,
                          color: appleSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              currency.format(amount),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: Colors.green.shade700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab(Map<String, dynamic> stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact Information Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appleCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: appleDivider.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: appleAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.contact_page_rounded, color: appleAccent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: appleText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.clientData?['phone'] != null)
                  _buildInfoRow(Icons.phone_rounded, 'Phone', widget.clientData!['phone']),
                if (widget.clientData?['email'] != null)
                  _buildInfoRow(Icons.email_rounded, 'Email', widget.clientData!['email']),
                if (widget.clientData?['gstin'] != null)
                  _buildInfoRow(Icons.business_rounded, 'GSTIN', widget.clientData!['gstin']),
                if (widget.clientData?['phone'] == null && 
                    widget.clientData?['email'] == null && 
                    widget.clientData?['gstin'] == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No contact information available',
                      style: TextStyle(
                        fontSize: 13,
                        color: appleSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Statistics Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appleCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: appleDivider.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: appleAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.bar_chart_rounded, color: appleAccent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Statistics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: appleText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.receipt_rounded, 'Total Invoices', '${stats['invoiceCount'] ?? 0}'),
                _buildInfoRow(Icons.check_circle_rounded, 'Paid Invoices', '${stats['paidCount'] ?? 0}'),
                _buildInfoRow(Icons.pending_rounded, 'Unpaid Invoices', '${stats['unpaidCount'] ?? 0}'),
                if ((stats['partialCount'] ?? 0) > 0)
                  _buildInfoRow(Icons.hourglass_empty_rounded, 'Partial Payments', '${stats['partialCount']}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: appleSubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: appleSecondary),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: appleSecondary,
              letterSpacing: -0.1,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: appleText,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _generateStatement() {
    // TODO: Implement PDF generation
    _showSnackBar('Statement generation coming soon!');
  }

    Widget _buildQuickActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
