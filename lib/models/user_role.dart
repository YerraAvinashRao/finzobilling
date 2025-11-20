enum UserRole {
  superAdmin,  // You (Avinash) - Full access
  admin,       // Other admins - Most access
  support,     // Support team - View tickets, reply
  user,        // Regular users - Normal app access
}

class UserRoleHelper {
  static String roleToString(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.admin:
        return 'admin';
      case UserRole.support:
        return 'support';
      case UserRole.user:
        return 'user';
    }
  }

  static UserRole stringToRole(String roleString) {
    switch (roleString) {
      case 'super_admin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'support':
        return UserRole.support;
      default:
        return UserRole.user;
    }
  }

  static String getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.support:
        return 'Support Staff';
      case UserRole.user:
        return 'User';
    }
  }

  static bool canAccessAdminPanel(UserRole role) {
    return role == UserRole.superAdmin || role == UserRole.admin;
  }

  static bool canAccessSupportPanel(UserRole role) {
    return role == UserRole.superAdmin || 
           role == UserRole.admin || 
           role == UserRole.support;
  }

  static bool canManageUsers(UserRole role) {
    return role == UserRole.superAdmin || role == UserRole.admin;
  }

  static bool canViewAllData(UserRole role) {
    return role == UserRole.superAdmin || role == UserRole.admin;
  }
}
