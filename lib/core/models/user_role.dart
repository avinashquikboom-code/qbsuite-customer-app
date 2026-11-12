/// Normalized user roles across the QuikBoom CRM application.
enum UserRole {
  companyAdmin,
  employee,
  customer;

  static UserRole fromString(String? role) =>
      UserRoleExtension.fromString(role);
  static UserRole? tryParse(String? role) => UserRoleExtension.tryParse(role);
}

extension UserRoleExtension on UserRole {
  /// Safely normalize roles returned from backend API or local storage.
  static UserRole fromString(String? role) {
    if (role == null || role.trim().isEmpty) {
      throw ArgumentError('User role is missing');
    }

    final normalized = role
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    switch (normalized) {
      // Company Admin
      case 'admin':
      case 'company_admin':
      case 'companyadmin':
      case 'company_administrator':
      case 'tenant_admin':
      case 'super_admin':
      case 'superadmin':
        return UserRole.companyAdmin;

      // Employee
      case 'employee':
      case 'staff':
      case 'sales_executive':
      case 'sales_manager':
      case 'support_agent':
      case 'field_agent':
      case 'video_editor':
      case 'videoeditor':
      case 'graphic_designer':
      case 'graphicdesigner':
      case 'photographer':
      case 'telesales_executive':
      case 'telesales':
      case 'production_manager':
      case 'productionmanager':
      case 'content_creator':
      case 'contentcreator':
      case 'motion_graphic_designer':
      case 'motion_graphics_designer':
      case 'animator':
      case 'editor':
      case 'digital_marketer':
      case 'lead_generator':
      case 'copywriter':
      case 'media_buyer':
      case 'accountant':
      case 'hr':
      case 'hr_manager':
        return UserRole.employee;

      // Customer
      case 'customer':
      case 'client':
      case 'customer_admin':
      case 'customer_administrator':
      case 'customer_user':
        return UserRole.customer;

      default:
        throw ArgumentError('Unsupported user role: $role');
    }
  }

  /// Safe parser that returns null on unrecognized roles without defaulting to Employee
  static UserRole? tryParse(String? role) {
    if (role == null || role.trim().isEmpty) return null;
    try {
      return fromString(role);
    } catch (_) {
      return null;
    }
  }

  /// Uppercase API / persistence value
  String get apiValue {
    switch (this) {
      case UserRole.companyAdmin:
        return 'COMPANY_ADMIN';
      case UserRole.employee:
        return 'EMPLOYEE';
      case UserRole.customer:
        return 'CUSTOMER';
    }
  }

  /// Uppercase display representation
  String toDisplayString() => apiValue;
}
