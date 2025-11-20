import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/role_service.dart';
import '../../models/user_role.dart';
import '../../auth_screen.dart';
import 'user_management_screen.dart';
import 'support_management_screen.dart';
import 'analytics_screen.dart';
import 'system_settings_screen.dart';
import 'activity_logs_screen.dart';
import 'database_management_screen.dart';
import 'notifications_center_screen.dart';
import 'app_updates_screen.dart';

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
  static const Color applePink = Color(0xFFFF2D55);
  static const Color appleTeal = Color(0xFF5AC8FA);

  UserRole? _currentRole;
  bool _isLoading = true;
  
  // Real-time stats
  int _totalUsers = 0;
  int _openTickets = 0;
  int _newUsersToday = 0;
  int _activeUsers = 0;
  int _totalTickets = 0;
  int _resolvedTickets = 0;

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

          // Calculate active users (logged in today)
          _activeUsers = snapshot.docs.where((doc) {
            final data = doc.data();
            final lastLogin = (data['lastLoginAt'] as Timestamp?)?.toDate();
            return lastLogin != null &&
                   lastLogin.year == today.year &&
                   lastLogin.month == today.month &&
                   lastLogin.day == today.day;
          }).length;
        });
      }
    });

    // Listen to ALL support tickets
    FirebaseFirestore.instance
        .collection('support_tickets')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _totalTickets = snapshot.docs.length;
          _openTickets = snapshot.docs.where((doc) {
            final status = doc.data()['status'];
            return status == 'open' || status == 'pending';
          }).length;
          _resolvedTickets = snapshot.docs.where((doc) {
            return doc.data()['status'] == 'resolved';
          }).length;
        });
      }
    });
  }

  // 🚪 Logout Function
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: appleRed),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (Route<dynamic> route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
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
              const CircularProgressIndicator(color: appleAccent),
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

    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? 'Admin';

    return Scaffold(
      backgroundColor: appleBackground,
      
      // 🍎 Frosted Glass AppBar with Logout
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
                // Notification badge with ticket count
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()),
                        );
                      },
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
                
                // Profile Menu with Logout
                PopupMenuButton<String>(
                  icon: const Icon(Icons.account_circle_outlined, color: Colors.black87),
                  offset: const Offset(0, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'logout') {
                      _handleLogout();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userEmail,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            UserRoleHelper.getRoleDisplayName(_currentRole!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const Divider(),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded, color: appleRed, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Logout',
                            style: TextStyle(
                              color: appleRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
                
                // 🎯 Quick Actions Header
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // 📈 Management Grid
                _buildManagementGrid(),
                
                const SizedBox(height: 24),
                
                // 🔧 System Tools Header
                const Text(
                  'System Tools',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // 🛠️ System Tools Grid
                _buildSystemToolsGrid(),
                
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
      childAspectRatio: 1.2,
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
          badge: _openTickets > 0,
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool badge = false}) {
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
          Row(
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
              if (badge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: appleRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
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

  // 📈 Management Cards Grid
  Widget _buildManagementGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.0,
      children: [
        _buildAdminCard(
          'User Management',
          '$_totalUsers total users',
          Icons.people_rounded,
          appleAccent,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserManagementScreen()),
          ),
        ),
        _buildAdminCard(
          'Support Tickets',
          '$_openTickets open • $_resolvedTickets resolved',
          Icons.support_agent_rounded,
          appleOrange,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SupportManagementScreen()),
          ),
          badge: _openTickets,
        ),
        _buildAdminCard(
          'Analytics',
          'View insights & trends',
          Icons.analytics_rounded,
          appleGreen,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
          ),
        ),
        _buildAdminCard(
          'Activity Logs',
          'System activity',
          Icons.history_rounded,
          applePurple,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ActivityLogsScreen()),
          ),
        ),
      ],
    );
  }

  // 🛠️ System Tools Grid
  Widget _buildSystemToolsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.0,
      children: [
        _buildAdminCard(
          'System Settings',
          'App configuration',
          Icons.settings_rounded,
          Colors.grey[700]!,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SystemSettingsScreen()),
          ),
        ),
        _buildAdminCard(
          'Database',
          'Manage data',
          Icons.storage_rounded,
          applePink,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DatabaseManagementScreen()),
          ),
        ),
        _buildAdminCard(
          'Notifications',
          'Send alerts',
          Icons.notifications_rounded,
          appleRed,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()),
          ),
        ),
        _buildAdminCard(
          'App Updates',
          'Feature flags',
          Icons.update_rounded,
          appleTeal,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AppUpdatesScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    int badge = 0,
  }) {
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
            Row(
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
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: appleRed,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
