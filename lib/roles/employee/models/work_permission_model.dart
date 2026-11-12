
class EmployeeWorkPermissions {
  final int? employeeId;
  final String? employeeCode;
  final String? firstName;
  final String? lastName;
  final String role;
  final List<String> workPermissions;
  final Map<String, bool> effectivePermissions;
  final List<String> commonModules;
  final bool isCrmEligible;

  const EmployeeWorkPermissions({
    this.employeeId,
    this.employeeCode,
    this.firstName,
    this.lastName,
    required this.role,
    required this.workPermissions,
    this.effectivePermissions = const {},
    this.commonModules = const [
      'dashboard',
      'attendance',
      'leave',
      'calendar',
      'profile',
    ],
    this.isCrmEligible = false,
  });

  static const Set<String> ssmWorkModules = {
    'video_edit',
    'post_design',
    'story_design',
    'reel_shoot',
    'reel_post',
    'story_post',
    'post_publish',
    'influencer_promo',
    'creative_work',
    'my_work',
    'ssm',
  };

  /// Whether the employee has at least one active SSM / Creative Work module permission.
  /// Strictly filters out CRM modules (leads, data_capture, customers) to avoid false positives.
  bool get hasSsmWorkPermission {
    return workPermissions.any(
          (p) => ssmWorkModules.contains(p.toLowerCase()),
        ) ||
        effectivePermissions.entries.any(
          (e) =>
              ssmWorkModules.contains(e.key.toLowerCase()) && e.value == true,
        );
  }

  bool hasPermission(String moduleKey) {
    if (effectivePermissions.containsKey(moduleKey)) {
      return effectivePermissions[moduleKey] == true;
    }
    return workPermissions.contains(moduleKey);
  }

  bool get isProductionManager {
    final r = role.toUpperCase();
    return r.contains('PRODUCTION') ||
        r.contains('PROD_MGR') ||
        r.contains('PRODUCTION_MANAGER') ||
        r.contains('PRODUCTION_LEAD');
  }

  /// Whether this employee has supervisor-level access.
  /// PREFERRED: Check RBAC permission 'TASKS.APPROVE' via PermissionManager in the UI.
  /// This getter is kept for legacy SSM-specific workflow only.
  /// Do NOT use for RBAC-controlled screens or actions.
  bool get isSupervisor =>
      effectivePermissions['supervisor'] == true ||
      effectivePermissions['tasks_approve'] == true ||
      effectivePermissions['tasks.approve'] == true ||
      effectivePermissions['creative_work.approve'] == true ||
      effectivePermissions['creative_work_approve'] == true ||
      effectivePermissions['work_execution.approve'] == true ||
      effectivePermissions['work_execution_approve'] == true ||
      isProductionManager ||
      role.toUpperCase().contains('ADMIN') ||
      role.toUpperCase().contains('DIRECTOR') ||
      (role.toUpperCase().contains('MANAGER') &&
          !role.toUpperCase().contains('SOCIAL'));

  factory EmployeeWorkPermissions.fromJson(Map<String, dynamic> json) {
    final rawPerms = json['workPermissions'];
    final List<String> permissions = [];
    if (rawPerms is List) {
      for (final p in rawPerms) {
        if (p != null) {
          permissions.add(p.toString());
        }
      }
    }

    final rawEffective = json['effectivePermissions'];
    final Map<String, bool> effectiveMap = {};
    if (rawEffective is Map) {
      rawEffective.forEach((k, v) {
        effectiveMap[k.toString()] = v == true;
      });
    }

    final rawCommon = json['commonModules'];
    final List<String> common = [];
    if (rawCommon is List) {
      for (final c in rawCommon) {
        if (c != null) {
          common.add(c.toString());
        }
      }
    }

    final bool isCrmEligible =
        json['isCrmEligible'] == true || json['crmMobileAccess'] == true;

    return EmployeeWorkPermissions(
      employeeId: json['employeeId'] is int
          ? json['employeeId']
          : int.tryParse('${json['employeeId']}'),
      employeeCode: json['employeeCode']?.toString(),
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      role: json['role']?.toString() ?? 'Employee',
      workPermissions: permissions,
      effectivePermissions: effectiveMap,
      commonModules: common.isNotEmpty
          ? common
          : const ['dashboard', 'attendance', 'leave', 'calendar', 'profile'],
      isCrmEligible: isCrmEligible,
    );
  }

  factory EmployeeWorkPermissions.empty() {
    return const EmployeeWorkPermissions(
      role: 'Employee',
      workPermissions: [],
      effectivePermissions: {},
      commonModules: [
        'dashboard',
        'attendance',
        'leave',
        'calendar',
        'profile',
      ],
      isCrmEligible: false,
    );
  }
}
