import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_role.dart';

class RoleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's role
  static Future<UserRole> getCurrentUserRole() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return UserRole.user;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('info')
          .get();

      if (doc.exists && doc.data()!.containsKey('role')) {
        final roleString = doc.data()!['role'] as String;
        return UserRoleHelper.stringToRole(roleString);
      }

      return UserRole.user; // Default role
    } catch (e) {
      print('Error getting user role: $e');
      return UserRole.user;
    }
  }

  // Check if user has specific role
  static Future<bool> hasRole(UserRole requiredRole) async {
    final userRole = await getCurrentUserRole();
    return userRole == requiredRole;
  }

  // Check if user can access admin panel
  static Future<bool> canAccessAdmin() async {
    final role = await getCurrentUserRole();
    return UserRoleHelper.canAccessAdminPanel(role);
  }

  // Check if user can access support panel
  static Future<bool> canAccessSupport() async {
    final role = await getCurrentUserRole();
    return UserRoleHelper.canAccessSupportPanel(role);
  }

  // ✅ FIXED: Assign role to user (Super Admin only)
  static Future<void> assignRole(String userId, UserRole role) async {
    final currentRole = await getCurrentUserRole();
    
    if (currentRole != UserRole.superAdmin) {
      throw Exception('Only Super Admin can assign roles');
    }

    try {
      print('🔍 Assigning role to userId: $userId');
      
      // ✅ Just update the role - DON'T touch email or name
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('info')
          .set({
        'role': UserRoleHelper.roleToString(role),
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));  // ✅ merge: true preserves existing fields

      print('✅ Role "${UserRoleHelper.roleToString(role)}" assigned successfully');

    } catch (e) {
      print('❌ ERROR in assignRole: $e');
      throw Exception('Failed to assign role: $e');
    }
  }


  // ✅ Get all users with their roles (Admin only)
  static Future<List<Map<String, dynamic>>> getAllUsersWithRoles() async {
    final canAccess = await canAccessAdmin();
    if (!canAccess) {
      throw Exception('Access denied: Admin privileges required');
    }

    try {
      final usersSnapshot = await _firestore.collection('users').get();
      List<Map<String, dynamic>> usersWithRoles = [];
      
      for (var userDoc in usersSnapshot.docs) {
        try {
          // ✅ STEP 1: Get email/username from ROOT document (source of truth)
          final userData = userDoc.data();
          
          if (userData == null) {
            print('⚠️ Skipping user ${userDoc.id}: No data');
            continue;
          }
          
          final email = userData['email'] as String?;
          final userName = userData['username'] as String?;
          final createdAt = userData['createdAt'];
          
          // Skip if no email (invalid user)
          if (email == null || email.isEmpty) {
            print('⚠️ Skipping user ${userDoc.id}: No email in root document');
            continue;
          }
          
          // ✅ STEP 2: Get role from profile/info subcollection
          final profileDoc = await userDoc.reference
              .collection('profile')
              .doc('info')
              .get();
          
          String role = 'user';
          bool isActive = true;
          
          if (profileDoc.exists && profileDoc.data() != null) {
            final profileData = profileDoc.data()!;
            role = profileData['role'] as String? ?? 'user';
            isActive = profileData['isActive'] as bool? ?? true;
          }
          
          // ✅ STEP 3: Add to list (email from root, role from profile)
          usersWithRoles.add({
            'userId': userDoc.id,
            'name': userName ?? email.split('@')[0],
            'email': email,  // ✅ Always from root document
            'role': role,
            'isActive': isActive,
            'createdAt': createdAt,
          });
          
          print('✅ Loaded: $userName ($email) - Role: $role');
          
        } catch (e) {
          print('⚠️ Error loading user ${userDoc.id}: $e');
        }
      }
      
      print('📊 Total users loaded: ${usersWithRoles.length}');
      return usersWithRoles;
      
    } catch (e) {
      print('❌ Error in getAllUsersWithRoles: $e');
      throw Exception('Failed to load users: $e');
    }
  }


  // ✅ FIXED: Make yourself Super Admin (one-time setup)
  static Future<void> makeCurrentUserSuperAdmin() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('❌ No user logged in');
      return;
    }

    try {
      // Fetch current user's data from ROOT document
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        print('❌ User document not found');
        return;
      }

      final userData = userDoc.data()!;
      final userEmail = userData['email'] ?? 'no-email@unknown.com';
      final userName = userData['username'] ?? userEmail.split('@')[0];

      // Set Super Admin role in profile/info
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('info')
          .set({
        'role': 'super_admin',
        'name': userName,
        'email': userEmail,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ SUCCESS! You are now Super Admin!');
      print('👤 Name: $userName');
      print('📧 Email: $userEmail');
      print('🆔 User ID: $userId');
      
    } catch (e) {
      print('❌ Error making user Super Admin: $e');
    }
  }

  // Get user statistics
  static Future<Map<String, int>> getUserStatistics() async {
    try {
      final users = await getAllUsersWithRoles();
      
      int superAdmins = 0;
      int admins = 0;
      int support = 0;
      int regularUsers = 0;
      int activeUsers = 0;
      int inactiveUsers = 0;
      
      for (var user in users) {
        final role = UserRoleHelper.stringToRole(user['role']);
        final isActive = user['isActive'] ?? true;
        
        switch (role) {
          case UserRole.superAdmin:
            superAdmins++;
            break;
          case UserRole.admin:
            admins++;
            break;
          case UserRole.support:
            support++;
            break;
          case UserRole.user:
            regularUsers++;
            break;
        }
        
        if (isActive) {
          activeUsers++;
        } else {
          inactiveUsers++;
        }
      }
      
      return {
        'total': users.length,
        'superAdmins': superAdmins,
        'admins': admins,
        'support': support,
        'users': regularUsers,
        'active': activeUsers,
        'inactive': inactiveUsers,
      };
    } catch (e) {
      print('Error getting user statistics: $e');
      return {};
    }
  }

  // Bulk role assignment
  static Future<void> bulkAssignRole(List<String> userIds, UserRole role) async {
    final currentRole = await getCurrentUserRole();
    
    if (currentRole != UserRole.superAdmin) {
      throw Exception('Only Super Admin can bulk assign roles');
    }

    final batch = _firestore.batch();
    
    for (var userId in userIds) {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('info');
      
      batch.set(docRef, {
        'role': UserRoleHelper.roleToString(role),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    
    await batch.commit();
    print('✅ Bulk role assignment complete: ${userIds.length} users updated');
  }

  // Search users by name or email
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final allUsers = await getAllUsersWithRoles();
    
    if (query.isEmpty) return allUsers;
    
    final lowerQuery = query.toLowerCase();
    
    return allUsers.where((user) {
      final name = user['name'].toString().toLowerCase();
      final email = user['email'].toString().toLowerCase();
      return name.contains(lowerQuery) || email.contains(lowerQuery);
    }).toList();
  }

  // Get users by role
  static Future<List<Map<String, dynamic>>> getUsersByRole(UserRole role) async {
    final allUsers = await getAllUsersWithRoles();
    final roleString = UserRoleHelper.roleToString(role);
    
    return allUsers.where((user) => user['role'] == roleString).toList();
  }

  // Deactivate/Activate user
  static Future<void> toggleUserStatus(String userId, bool activate) async {
    final currentRole = await getCurrentUserRole();
    
    if (!UserRoleHelper.canAccessAdminPanel(currentRole)) {
      throw Exception('Admin privileges required');
    }

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('info')
        .update({
      'isActive': activate,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    print('${activate ? '✅ Activated' : '🚫 Deactivated'} user: $userId');
  }

  // Check if user exists
  static Future<bool> userExists(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get user role by ID
  static Future<UserRole> getUserRole(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('info')
          .get();

      if (doc.exists && doc.data()!.containsKey('role')) {
        final roleString = doc.data()!['role'] as String;
        return UserRoleHelper.stringToRole(roleString);
      }

      return UserRole.user;
    } catch (e) {
      print('Error getting user role for $userId: $e');
      return UserRole.user;
    }
  }
}
