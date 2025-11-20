import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/role_service.dart';
import '../../models/user_role.dart';
import 'package:intl/intl.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> with SingleTickerProviderStateMixin {
  // 🍎 Apple iOS Colors
  static const Color appleBackground = Color(0xFFF2F2F7);
  static const Color appleCard = Color(0xFFFFFFFF);
  static const Color appleAccent = Color(0xFF007AFF);
  static const Color appleRed = Color(0xFFFF3B30);
  static const Color appleOrange = Color(0xFFFF9500);
  static const Color appleGreen = Color(0xFF34C759);
  static const Color applePurple = Color(0xFFAF52DE);

  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';
  UserRole? _filterRole;

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
    _loadUsers();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    try {
      final users = await RoleService.getAllUsersWithRoles();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    return _users.where((user) {
      final matchesSearch = user['name']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase()) ||
          user['email']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      
      final matchesRole = _filterRole == null ||
          UserRoleHelper.stringToRole(user['role']) == _filterRole;
      
      return matchesSearch && matchesRole;
    }).toList();
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
                'User Management',
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
                  onPressed: _loadUsers,
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.filter_list_rounded, color: Colors.black87),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: null,
                      child: Text('All Users'),
                    ),
                    ...UserRole.values.map((role) => PopupMenuItem(
                      value: role,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getRoleColor(role),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(UserRoleHelper.getRoleDisplayName(role)),
                        ],
                      ),
                    )),
                  ],
                  onSelected: (value) {
                    setState(() => _filterRole = value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          // 🔍 Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appleCard,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                filled: true,
                fillColor: appleBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: appleCard,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatChip('Total', _users.length, appleAccent),
                _buildStatChip('Super Admin', _getUserCountByRole(UserRole.superAdmin), appleRed),
                _buildStatChip('Admin', _getUserCountByRole(UserRole.admin), applePurple),
                _buildStatChip('Support', _getUserCountByRole(UserRole.support), appleOrange),
                _buildStatChip('Users', _getUserCountByRole(UserRole.user), appleGreen),
              ],
            ),
          ),

          // User List
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: appleAccent),
                        const SizedBox(height: 16),
                        Text(
                          'Loading users...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : _filteredUsers.isEmpty
                    ? _buildEmptyState()
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            return _buildPremiumUserCard(user);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // 📊 Stat Chip
  Widget _buildStatChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  int _getUserCountByRole(UserRole role) {
    return _users.where((user) => 
      UserRoleHelper.stringToRole(user['role']) == role
    ).length;
  }

  // 👤 Premium User Card
  Widget _buildPremiumUserCard(Map<String, dynamic> user) {
    final role = UserRoleHelper.stringToRole(user['role']);
    final roleColor = _getRoleColor(role);
    final isActive = user['isActive'] ?? true;
    
    // ✅ FIXED: Handle both Timestamp and String for createdAt
    DateTime? createdAt;
    try {
      final createdAtData = user['createdAt'];
      if (createdAtData is Timestamp) {
        createdAt = createdAtData.toDate();
      } else if (createdAtData is String) {
        createdAt = DateTime.tryParse(createdAtData);
      }
    } catch (e) {
      createdAt = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showUserDetailsDialog(user),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [roleColor, roleColor.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          user['name'][0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (!isActive)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: appleRed,
                            shape: BoxShape.circle,
                            border: Border.all(color: appleCard, width: 2),
                          ),
                          child: const Icon(
                            Icons.block,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(width: 14),
                
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              UserRoleHelper.getRoleDisplayName(role),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: roleColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['email'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        createdAt != null 
                            ? 'Joined ${DateFormat('MMM dd, yyyy').format(createdAt)}'
                            : 'Recently joined',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Actions
                PopupMenuButton(
                  icon: Icon(Icons.more_vert_rounded, color: Colors.grey[600]),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'change_role',
                      child: Row(
                        children: [
                          Icon(Icons.admin_panel_settings, size: 20),
                          SizedBox(width: 12),
                          Text('Change Role'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'view_details',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 20),
                          SizedBox(width: 12),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: isActive ? 'deactivate' : 'activate',
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.block : Icons.check_circle,
                            size: 20,
                            color: isActive ? appleRed : appleGreen,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isActive ? 'Deactivate' : 'Activate',
                            style: TextStyle(
                              color: isActive ? appleRed : appleGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'change_role') {
                      _showChangeRoleDialog(user);
                    } else if (value == 'view_details') {
                      _showUserDetailsDialog(user);
                    } else if (value == 'deactivate' || value == 'activate') {
                      _toggleUserStatus(user['userId'], isActive);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // 🎨 Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search'
                : 'No users match the filter',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // 🎨 Role Colors
  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return appleRed;
      case UserRole.admin:
        return applePurple;
      case UserRole.support:
        return appleOrange;
      case UserRole.user:
        return appleAccent;
    }
  }

  // 🔄 Change Role Dialog
  void _showChangeRoleDialog(Map<String, dynamic> user) {
    final currentRole = UserRoleHelper.stringToRole(user['role']);
    UserRole? selectedRole = currentRole;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: applePurple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: applePurple,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Change Role for ${user['name']}',
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: UserRole.values.map((role) {
              return RadioListTile<UserRole>(
                title: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getRoleColor(role),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(UserRoleHelper.getRoleDisplayName(role)),
                  ],
                ),
                value: role,
                groupValue: selectedRole,
                activeColor: _getRoleColor(role),
                onChanged: (newRole) {
                  setDialogState(() => selectedRole = newRole);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: appleAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                if (selectedRole != null && selectedRole != currentRole) {
                  try {
                    await RoleService.assignRole(user['userId'], selectedRole!);
                    if (mounted) {
                      Navigator.pop(context);
                      _loadUsers();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Role updated to ${UserRoleHelper.getRoleDisplayName(selectedRole!)}'),
                          backgroundColor: appleGreen,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: appleRed),
                      );
                    }
                  }
                }
              },
              child: const Text('Update Role'),
            ),
          ],
        ),
      ),
    );
  }

  // 📋 User Details Dialog
  void _showUserDetailsDialog(Map<String, dynamic> user) {
    final role = UserRoleHelper.stringToRole(user['role']);
    
    // ✅ FIX: Handle both Timestamp and String
    DateTime? createdAt;
    try {
      final createdAtData = user['createdAt'];
      if (createdAtData is Timestamp) {
        createdAt = createdAtData.toDate();
      } else if (createdAtData is String) {
        createdAt = DateTime.tryParse(createdAtData);
      }
    } catch (e) {
      createdAt = null;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_getRoleColor(role), _getRoleColor(role).withOpacity(0.7)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user['name'][0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(user['name']),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Email', user['email']),
            _buildDetailRow('Role', UserRoleHelper.getRoleDisplayName(role)),
            _buildDetailRow('Status', user['isActive'] ?? true ? 'Active' : 'Inactive'),
            if (createdAt != null)
              _buildDetailRow('Joined', DateFormat('MMM dd, yyyy').format(createdAt))
            else
              _buildDetailRow('Joined', 'Recently'),
            _buildDetailRow('User ID', user['userId']),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: appleAccent,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }


  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ⚡ Toggle User Status
  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    final newStatus = !currentStatus;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('info')
          .update({'isActive': newStatus});
      
      _loadUsers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? '✅ User activated' : '🚫 User deactivated'),
            backgroundColor: newStatus ? appleGreen : appleRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: appleRed),
        );
      }
    }
  }
}
