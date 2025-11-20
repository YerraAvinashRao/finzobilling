import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/role_service.dart';
import '../../models/user_role.dart';
import '../screens/admin/user_management_screen.dart';
import '../screens/admin/support_management_screen.dart';
import '../screens/admin/analytics_screen.dart';


class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  // 🍎 Apple iOS Colors
  static const Color appleBackground = Color(0xFFF2F2F7);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleRed = Color(0xFFFF3B30);
  static const Color appleOrange = Color(0xFFFF9500);
  static const Color appleGreen = Color(0xFF34C759);
  static const Color applePurple = Color(0xFFAF52DE);

  UserRole? _currentRole;
  bool _isLoading = true;
  
  // Real-time stats
  int _totalUsers = 0;
  int _openTickets = 0;
  int _newUsersToday = 0;
  final int _activeUsers = 0;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _checkAccess();
    _loadRealTimeStats();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    final canAccess = await RoleService.canAccessAdmin();
    
    if (!canAccess && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⛔ Access Denied: Admin privileges required')),
      );
      return;
    }

    final role = await RoleService.getCurrentUserRole();
    if (mounted) {
      setState(() {
        _currentRole = role;
        _isLoading = false;
      });
      _fadeController.forward();
    }
  }

  // 📊 Load real-time statistics
  void _loadRealTimeStats() {
    // Listen to users collection
    FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _totalUsers = snapshot.docs.length;
          
          // Calculate today's new users
          final today = DateTime.now();
          _newUsersToday = snapshot.docs.where((doc) {
            final data = doc.data();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            return createdAt != null &&
                   createdAt.year == today.year &&
                   createdAt.month == today.month &&
                   createdAt.day == today.day;
          }).length;
        });
      }
    });

    // Listen to support tickets
    FirebaseFirestore.instance
        .collection('support_tickets')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _openTickets = snapshot.docs.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: appleBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: appleAccent),
              const SizedBox(height: 16),
              Text(
                'Loading Admin Dashboard...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    UserRoleHelper.getRoleDisplayName(_currentRole!),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              actions: [
                // Notification badge
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
                      onPressed: () {},
                    ),
                    if (_openTickets > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: appleRed,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$_openTickets',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
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

      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: () async {
            _loadRealTimeStats();
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📊 Real-time Stats Cards
                _buildStatsGrid(),
                
                const SizedBox(height: 24),
                
                // 🎯 Quick Actions
                _buildQuickActionsSection(),
                
                const SizedBox(height: 24),
                
                // 📈 Main Admin Cards
                _buildAdminCardsGrid(),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 📊 Real-time Stats Grid
  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Users',
          '$_totalUsers',
          Icons.people_rounded,
          appleAccent,
        ),
        _buildStatCard(
          'Open Tickets',
          '$_openTickets',
          Icons.support_agent_rounded,
          appleOrange,
        ),
        _buildStatCard(
          'New Today',
          '$_newUsersToday',
          Icons.person_add_rounded,
          appleGreen,
        ),
        _buildStatCard(
          'Active Now',
          '$_activeUsers',
          Icons.online_prediction_rounded,
          applePurple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -1,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🎯 Quick Actions
  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                'Add Admin',
                Icons.admin_panel_settings,
                appleAccent,
                () => _showAddAdminDialog(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                'View Logs',
                Icons.history,
                appleOrange,
                () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 Main Admin Cards
  Widget _buildAdminCardsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            _buildAdminCard(
              'User Management',
              'Manage users & roles',
              Icons.people_rounded,
              appleAccent,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UserManagementScreen()),
              ),
            ),
            _buildAdminCard(
              'Support Tickets',
              '$_openTickets open',
              Icons.support_agent_rounded,
              appleOrange,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SupportManagementScreen()),
              ),
            ),
            _buildAdminCard(
              'Analytics',
              'View insights',
              Icons.analytics_rounded,
              appleGreen,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AnalyticsScreen()),
              ),
            ),
            _buildAdminCard(
              'Settings',
              'System config',
              Icons.settings_rounded,
              applePurple,
              () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAdminDialog() {
    // TODO: Implement add admin dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Feature coming soon!')),
    );
  }
}
