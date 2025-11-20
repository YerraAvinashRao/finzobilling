import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;

  // 🍎 Apple iOS Colors
  static const Color appleBackground = Color(0xFFF2F2F7);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleRed = Color(0xFFFF3B30);
  static const Color appleOrange = Color(0xFFFF9500);
  static const Color appleGreen = Color(0xFF34C759);
  static const Color applePurple = Color(0xFFAF52DE);
  static const Color applePink = Color(0xFFFF2D55);

  // Real-time analytics data
  int _totalUsers = 0;
  int _activeUsersToday = 0;
  int _newUsersThisWeek = 0;
  int _totalInvoices = 0;
  int _openTickets = 0;
  int _closedTickets = 0;
  int _featureRequests = 0;
  int _totalProducts = 0;
  double _totalRevenue = 0.0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _loadAnalytics();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 📊 Load real-time analytics
  void _loadAnalytics() {
    // Listen to users collection
    _firestore.collection('users').snapshots().listen((snapshot) {
      if (!mounted) return;
      
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      
      int newThisWeek = 0;
      int activeToday = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        if (createdAt != null && createdAt.isAfter(weekAgo)) {
          newThisWeek++;
        }
        
        // Check if user was active today
        if (createdAt != null &&
            createdAt.year == now.year &&
            createdAt.month == now.month &&
            createdAt.day == now.day) {
          activeToday++;
        }
      }

      setState(() {
        _totalUsers = snapshot.docs.length;
        _newUsersThisWeek = newThisWeek;
        _activeUsersToday = activeToday;
      });
    });

    // Listen to support tickets
    _firestore.collection('support_tickets').snapshots().listen((snapshot) {
      if (!mounted) return;
      
      int open = 0;
      int closed = 0;
      
      for (var doc in snapshot.docs) {
        final status = doc.data()['status'];
        if (status == 'open') open++;
        if (status == 'closed') closed++;
      }

      setState(() {
        _openTickets = open;
        _closedTickets = closed;
      });
    });

    // Listen to feature requests
    _firestore.collection('feature_requests').snapshots().listen((snapshot) {
      if (mounted) {
        setState(() => _featureRequests = snapshot.docs.length);
      }
    });

    // Calculate total invoices and revenue
    _calculateInvoiceStats();
  }

  Future<void> _calculateInvoiceStats() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      
      int totalInvoices = 0;
      double totalRevenue = 0.0;
      int totalProducts = 0;

      for (var userDoc in usersSnapshot.docs) {
        // Get invoices for each user
        final invoicesSnapshot = await userDoc.reference
            .collection('invoices')
            .get();
        
        totalInvoices += invoicesSnapshot.docs.length;
        
        for (var invoice in invoicesSnapshot.docs) {
          final data = invoice.data();
          totalRevenue += (data['totalAmount'] ?? 0.0).toDouble();
        }

        // Get products count
        final productsSnapshot = await userDoc.reference
            .collection('products')
            .get();
        
        totalProducts += productsSnapshot.docs.length;
      }

      if (mounted) {
        setState(() {
          _totalInvoices = totalInvoices;
          _totalRevenue = totalRevenue;
          _totalProducts = totalProducts;
        });
      }
    } catch (e) {
      debugPrint('Error calculating stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appleBackground,
      
      // 🍎 Frosted Glass AppBar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: appleCard.withOpacity(0.8),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Analytics',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
                  onPressed: () {
                    _loadAnalytics();
                    _animationController.forward(from: 0);
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: () async {
            _loadAnalytics();
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 👥 User Analytics Section
              _buildSectionHeader('User Analytics', Icons.people_rounded),
              const SizedBox(height: 12),
              _buildUserAnalyticsGrid(),
              
              const SizedBox(height: 24),
              
              // 💬 Support Analytics Section
              _buildSectionHeader('Support Metrics', Icons.support_agent_rounded),
              const SizedBox(height: 12),
              _buildSupportAnalyticsGrid(),
              
              const SizedBox(height: 24),
              
              // 💰 Business Analytics Section
              _buildSectionHeader('Business Metrics', Icons.business_center_rounded),
              const SizedBox(height: 12),
              _buildBusinessAnalyticsGrid(),
              
              const SizedBox(height: 24),
              
              // 📈 Growth Indicators
              _buildSectionHeader('Growth Indicators', Icons.trending_up_rounded),
              const SizedBox(height: 12),
              _buildGrowthIndicators(),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // 📌 Section Header
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: appleAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: appleAccent, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  // 👥 User Analytics Grid - ✅ FIXED TO 1.1
  Widget _buildUserAnalyticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1, // ✅ CHANGED FROM 1.4 TO 1.1
      children: [
        _buildMetricCard(
          'Total Users',
          _totalUsers.toString(),
          Icons.people_rounded,
          appleAccent,
          '+$_newUsersThisWeek this week',
        ),
        _buildMetricCard(
          'Active Today',
          _activeUsersToday.toString(),
          Icons.online_prediction_rounded,
          appleGreen,
          '${((_activeUsersToday / (_totalUsers > 0 ? _totalUsers : 1)) * 100).toStringAsFixed(1)}% active',
        ),
        _buildMetricCard(
          'New This Week',
          _newUsersThisWeek.toString(),
          Icons.person_add_rounded,
          applePurple,
          'Weekly growth',
        ),
        _buildMetricCard(
          'Avg. Daily',
          (_totalUsers / 30).toStringAsFixed(0),
          Icons.calendar_today_rounded,
          appleOrange,
          'Per month',
        ),
      ],
    );
  }

  // 💬 Support Analytics Grid - ✅ FIXED TO 1.1
  Widget _buildSupportAnalyticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1, // ✅ CHANGED FROM 1.4 TO 1.1
      children: [
        _buildMetricCard(
          'Open Tickets',
          _openTickets.toString(),
          Icons.support_agent_rounded,
          appleOrange,
          'Need attention',
        ),
        _buildMetricCard(
          'Closed Tickets',
          _closedTickets.toString(),
          Icons.check_circle_rounded,
          appleGreen,
          'Resolved',
        ),
        _buildMetricCard(
          'Resolution Rate',
          '${(_closedTickets / ((_openTickets + _closedTickets) > 0 ? (_openTickets + _closedTickets) : 1) * 100).toStringAsFixed(0)}%',
          Icons.analytics_rounded,
          applePurple,
          'Success rate',
        ),
        _buildMetricCard(
          'Feature Requests',
          _featureRequests.toString(),
          Icons.lightbulb_rounded,
          applePink,
          'User ideas',
        ),
      ],
    );
  }

  // 💰 Business Analytics Grid - ✅ ALREADY 1.2, KEEP IT
  Widget _buildBusinessAnalyticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1, // ✅ CHANGED FROM 1.2 TO 1.1
      children: [
        _buildMetricCard(
          'Total Invoices',
          _totalInvoices.toString(),
          Icons.receipt_long_rounded,
          appleAccent,
          'All time',
        ),
        _buildMetricCard(
          'Total Revenue',
          '₹${NumberFormat('#,##,###').format(_totalRevenue)}',
          Icons.currency_rupee_rounded,
          appleGreen,
          'Gross revenue',
        ),
        _buildMetricCard(
          'Total Products',
          _totalProducts.toString(),
          Icons.inventory_2_rounded,
          appleOrange,
          'In catalog',
        ),
        _buildMetricCard(
          'Avg. Invoice',
          '₹${NumberFormat('#,##,###').format(_totalInvoices > 0 ? _totalRevenue / _totalInvoices : 0)}',
          Icons.analytics_rounded,
          applePurple,
          'Per invoice',
        ),
      ],
    );
  }

  // 📈 Growth Indicators
  Widget _buildGrowthIndicators() {
    final userGrowth = _newUsersThisWeek / (_totalUsers > 0 ? _totalUsers : 1) * 100;
    final supportHealth = _closedTickets / ((_openTickets + _closedTickets) > 0 ? (_openTickets + _closedTickets) : 1) * 100;
    final businessActivity = _totalInvoices / (_totalUsers > 0 ? _totalUsers : 1);

    return Column(
      children: [
        _buildProgressIndicator(
          'User Growth',
          userGrowth,
          appleGreen,
          '${userGrowth.toStringAsFixed(1)}% weekly growth',
        ),
        const SizedBox(height: 12),
        _buildProgressIndicator(
          'Support Health',
          supportHealth,
          appleAccent,
          '${supportHealth.toStringAsFixed(0)}% resolution rate',
        ),
        const SizedBox(height: 12),
        _buildProgressIndicator(
          'Business Activity',
          (businessActivity * 10).clamp(0, 100),
          applePurple,
          '${businessActivity.toStringAsFixed(1)} invoices per user',
        ),
      ],
    );
  }

  // 📊 Metric Card - ✅ FIXED WITH BETTER SIZING
  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(14), // Reduced from 16
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min, // ✅ ADDED
        children: [
          Container(
            padding: const EdgeInsets.all(6), // Reduced from 8
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18), // Reduced from 20
          ),
          const SizedBox(height: 6), // ✅ ADDED SPACING
          Flexible( // ✅ WRAPPED IN FLEXIBLE
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox( // ✅ PREVENTS OVERFLOW
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22, // Reduced from 24
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11, // Reduced from 12
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9, // Reduced from 10
                    color: Colors.grey[500],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 📈 Progress Indicator
  Widget _buildProgressIndicator(String title, double value, Color color, String subtitle) {
    final clampedValue = value.clamp(0.0, 100.0);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appleCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${clampedValue.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: clampedValue / 100,
              minHeight: 8,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
