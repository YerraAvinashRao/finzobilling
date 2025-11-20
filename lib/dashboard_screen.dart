// lib/dashboard_screen.dart
import 'dart:ui';
import 'package:finzobilling/auth_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ ADDED

// Core Screens
import 'products_screen.dart';
import 'clients_screen.dart';
import 'invoices_screen.dart';
import 'dashboard_metrics_screen.dart';

// Navigation Screens
import 'settings_screen.dart';
import 'reports_screen.dart';
import 'purchases_list_screen.dart';
import 'expenses_screen.dart';
import 'create_invoice_screen.dart';
import 'new_purchase_screen.dart';
import 'add_expense_screen.dart';
import 'services/role_service.dart';
import 'screens/admin/admin_dashboard.dart';
import 'notifications_inbox_screen.dart';
import 'screens/user_support_screen.dart';
import 'screens/admin/support_management_screen.dart';



// Credit/Debit Notes
import 'screens/credit_notes_list_screen.dart';
import 'screens/debit_notes_list_screen.dart';
import 'screens/create_debit_note_screen.dart';
import 'screens/create_credit_note_screen.dart';
import 'widgets/ai_assistant_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
  
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  Stream<DocumentSnapshot>? roleStream;
  String? currentRole;


  // 🍎 APPLE iOS PREMIUM COLORS
  static const Color appleBackground = Color(0xFFFBFBFD);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleText = Color(0xFF1D1D1F);
  static const Color appleSecondary = Color(0xFF86868B);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleDivider = Color(0xFFD2D2D7);
  static const Color appleSubtle = Color(0xFFF5F5F7);

  static final List<Widget> _widgetOptions = <Widget>[
    const DashboardMetricsScreen(),
    const InvoicesScreen(),
    const ProductsScreen(),
    const ClientsScreen(),
  ];

  static const List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.dashboard_rounded,
      label: 'Dashboard',
    ),
    _NavItem(
      icon: Icons.receipt_long_rounded,
      label: 'Invoices',
    ),
    _NavItem(
      icon: Icons.inventory_2_rounded,
      label: 'Products',
    ),
    _NavItem(
      icon: Icons.people_rounded,
      label: 'Clients',
    ),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
    void initState() {
      super.initState();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        roleStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('info')
        .snapshots();
      }
    }


  @override
    Widget build(BuildContext context) {
      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email ?? 'Guest';

      // Check if roleStream is initialized
      if (roleStream == null) {
        return Scaffold(
          backgroundColor: appleBackground,
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      // Wrap everything in StreamBuilder to listen to role changes
      return StreamBuilder<DocumentSnapshot>(
        stream: roleStream,
        builder: (context, snapshot) {
          // Handle loading and error states
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(
              backgroundColor: appleBackground,
              body: const Center(child: Text('User data not found')),
            );
          }

          // Get user role from Firestore
          final data = snapshot.data!.data() as Map<String, dynamic>;
          currentRole = data['role'];

          // Route to appropriate screen based on role
          if (currentRole == 'support') {
            return SupportManagementScreen();  // ✅ CHANGED
          } else if (currentRole == 'admin' || currentRole == 'super_admin') {
            return AdminDashboard();
          } else {
            // Default dashboard for regular users (your existing UI - unchanged)
            return Scaffold(
              backgroundColor: appleBackground,
              
              // 🍎 Apple-style Frosted Glass AppBar
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
                        centerTitle: false,
                        leading: Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu_rounded, color: appleText),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                        title: Row(
                          children: [
                            Icon(
                              _navItems[_selectedIndex].icon,
                              color: appleText,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _navItems[_selectedIndex].label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 20,
                                color: appleText,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          // 🔔 NOTIFICATION BELL WITH BADGE (UPDATED)
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_outlined,
                                    color: appleText, size: 22),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const NotificationsInboxScreen(),
                                    ),
                                  );
                                },
                              ),
                              // Real-time Unread Badge
                              Positioned(
                                right: 8,
                                top: 8,
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('notifications')
                                      .where('read', isEqualTo: false)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    
                                    final unreadCount = snapshot.data!.docs.length;
                                    
                                    return Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF3B30),
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        unreadCount > 9 ? '9+' : '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined,
                                color: appleText, size: 22),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (ctx) => const SettingsScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              drawer: _buildAppleDrawer(context, userEmail),

              body: Stack(
                children: [
                  _widgetOptions[_selectedIndex],
                  const AIAssistant(),
                ],
              ),

              // 🍎 Apple-style FAB
              floatingActionButton: SpeedDial(
                heroTag: 'dashboard-speed-dial',
                icon: Icons.add_rounded,
                activeIcon: Icons.close_rounded,
                backgroundColor: appleAccent,
                foregroundColor: Colors.white,
                overlayColor: Colors.black,
                overlayOpacity: 0.5,
                spacing: 10,
                spaceBetweenChildren: 10,
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                children: [
                  SpeedDialChild(
                    child: const Icon(Icons.receipt_long_rounded, size: 20),
                    label: 'New Invoice',
                    backgroundColor: appleAccent,
                    labelStyle:
                        const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const CreateInvoiceScreen()),
                    ),
                  ),
                  SpeedDialChild(
                    child: const Icon(Icons.shopping_cart_rounded, size: 20),
                    label: 'New Purchase',
                    backgroundColor: appleAccent,
                    labelStyle:
                        const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const NewPurchaseScreen()),
                    ),
                  ),
                  SpeedDialChild(
                    child: const Icon(Icons.money_off_rounded, size: 20),
                    label: 'New Expense',
                    backgroundColor: appleAccent,
                    labelStyle:
                        const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const AddExpenseScreen()),
                    ),
                  ),
                  SpeedDialChild(
                    child: const Icon(Icons.assignment_return_rounded, size: 20),
                    label: 'Credit Note',
                    backgroundColor: Colors.red,
                    labelStyle:
                        const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (ctx) => const CreateCreditNoteScreen()),
                    ),
                  ),
                  SpeedDialChild(
                    child: const Icon(Icons.assignment_returned_rounded, size: 20),
                    label: 'Debit Note',
                    backgroundColor: Colors.orange,
                    labelStyle:
                        const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (ctx) => const CreateDebitNoteScreen()),
                    ),
                  ),
                ],
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

              bottomNavigationBar: _buildAppleBottomBar(),
            );
          }
        },
      );
    }


  // 🍎 Apple-style Drawer
  Widget _buildAppleDrawer(BuildContext context, String userEmail) {
    final userName = userEmail.split('@').first;

    return Drawer(
      backgroundColor: appleCard,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: appleAccent,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: appleAccent,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FinzoBilling',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'GST Billing & Invoicing',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              userName.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerTile(
                  context,
                  Icons.assessment_rounded,
                  'Reports',
                  const ReportsScreen(),
                  appleAccent,
                ),
                _buildDrawerTile(
                  context,
                  Icons.shopping_cart_rounded,
                  'Purchase History',
                  const PurchasesListScreen(),
                  appleAccent,
                ),
                _buildDrawerTile(
                  context,
                  Icons.money_off_rounded,
                  'Expenses',
                  const ExpensesScreen(),
                  appleAccent,
                ),
                Divider(color: appleDivider.withOpacity(0.5), height: 1),
                _buildDrawerTile(
                  context,
                  Icons.assignment_return_rounded,
                  'Credit Notes',
                  const CreditNotesListScreen(),
                  Colors.red,
                ),
                _buildDrawerTile(
                  context,
                  Icons.assignment_returned_rounded,
                  'Debit Notes',
                  const DebitNotesListScreen(),
                  Colors.orange,
                ),
                
                // ADMIN SECTION
                FutureBuilder<bool>(
                  future: RoleService.canAccessAdmin(),
                  builder: (context, snapshot) {
                    if (snapshot.data == true) {
                      return Column(
                        children: [
                          Divider(color: appleDivider.withOpacity(0.5), height: 1, thickness: 2),
                          
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red.shade50,
                                  Colors.orange.shade50,
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.admin_panel_settings,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'ADMIN PANEL',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'SUPER ADMIN',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.dashboard_rounded,
                                color: Colors.red,
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'Admin Dashboard',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: appleText,
                                letterSpacing: -0.2,
                              ),
                            ),
                            subtitle: const Text(
                              'User Management & Analytics',
                              style: TextStyle(
                                fontSize: 11,
                                color: appleSecondary,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.red,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminDashboard(),
                                ),
                              );
                            },
                          ),
                          
                          Divider(color: appleDivider.withOpacity(0.5), height: 1, thickness: 2),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded, color: Colors.orange),
                  title: const Text(
                    'Support',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                  subtitle: const Text(
                    'Get help & raise tickets',
                    style: TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserSupportScreen(),
                      ),
                    );
                  },
                ),

                Divider(color: appleDivider.withOpacity(0.5), height: 1),
                _buildDrawerTile(
                  context,
                  Icons.settings_rounded,
                  'Settings',
                  const SettingsScreen(),
                  appleSecondary,
                ),
              ],
            ),
          ),

          // Logout
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: appleDivider.withOpacity(0.5)),
              ),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile(
    BuildContext context,
    IconData icon,
    String title,
    Widget targetScreen,
    Color iconColor,
  ) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: appleText,
          letterSpacing: -0.2,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (ctx) => targetScreen),
        );
      },
    );
  }

  Widget _buildAppleBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: appleCard.withOpacity(0.9),
        border: Border(
          top: BorderSide(color: appleDivider.withOpacity(0.5), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            color: Colors.transparent,
            elevation: 0,
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavItem(0),
                  _buildNavItem(1),
                  const SizedBox(width: 50),
                  _buildNavItem(2),
                  _buildNavItem(3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isSelected = _selectedIndex == index;
    final item = _navItems[index];

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: isSelected
              ? BoxDecoration(
                  color: appleAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: isSelected ? appleAccent : appleSecondary,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                  color: isSelected ? appleAccent : appleSecondary,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.label,
  });
}
