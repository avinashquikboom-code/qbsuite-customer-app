import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../models/permission_model.dart";
import "secure_storage_service.dart";

/// Comprehensive permission state representation
enum PermissionStatus {
  loading,
  successWithPermissions,
  successWithZeroPermissions,
  error,
}

/// Centralized state representing the current user's effective permissions.
class PermissionState {
  final List<UserPermission> permissions;
  final String? role;
  final String? employeeId;
  final String? designationId;
  final String? tenantId;
  final bool isCrmEligible;
  final String? crmCategory;
  final bool isInitialized;
  final bool isLoading;
  final String? error;
  final DateTime? lastFetchedAt;

  const PermissionState({
    this.permissions = const [],
    this.role,
    this.employeeId,
    this.designationId,
    this.tenantId,
    this.isCrmEligible = false,
    this.crmCategory,
    this.isInitialized = false,
    this.isLoading = false,
    this.error,
    this.lastFetchedAt,
  });

  /// Explicitly distinguish the 4 permission lifecycle states
  PermissionStatus get status {
    if (isLoading || !isInitialized) return PermissionStatus.loading;
    if (error != null) return PermissionStatus.error;
    if (permissions.isEmpty) return PermissionStatus.successWithZeroPermissions;
    return PermissionStatus.successWithPermissions;
  }

  /// Check whether permissions are ready/resolved to prevent UI flash
  bool get isReady => isInitialized && !isLoading;

  /// Check whether permissions have definitively completed loading with 0 modules
  bool get hasZeroPermissions =>
      isInitialized && !isLoading && error == null && permissions.isEmpty;

  /// Check whether permissions are populated
  bool get hasPermissions => permissions.isNotEmpty;

  bool customerCan(String module, String action) {
    return hasPermission(module, action);
  }

  /// Check whether user has a specific module and action permission.
  /// Strictly driven by actual user permissions (NO role string hardcoding).
  /// Supports both hasPermission("LEADS", "EDIT") and hasPermission("employee.leads.edit")
  bool hasPermission(String moduleOrKey, [String? action]) {
    if (!isInitialized && permissions.isEmpty) return false;

    String targetMod;
    String targetAct;

    if (action != null) {
      targetMod = AppModule.normalize(moduleOrKey);
      targetAct = PermissionAction.normalize(action);
    } else {
      final clean = moduleOrKey.trim();
      if (clean.startsWith("employee.")) {
        final withoutPrefix = clean.substring(9);
        final dotIdx = withoutPrefix.indexOf(".");
        if (dotIdx > 0) {
          targetMod = AppModule.normalize(withoutPrefix.substring(0, dotIdx));
          targetAct = PermissionAction.normalize(
            withoutPrefix.substring(dotIdx + 1),
          );
        } else {
          targetMod = AppModule.normalize(withoutPrefix);
          targetAct = PermissionAction.view;
        }
      } else if (clean.contains(":")) {
        final parts = clean.split(":");
        targetMod = AppModule.normalize(parts[0]);
        targetAct = PermissionAction.normalize(parts[1]);
      } else {
        targetMod = AppModule.normalize(clean);
        targetAct = PermissionAction.view;
      }
    }

    return permissions.any(
      (p) {
        final pMod = p.module.toUpperCase();
        final pAct = p.action.toUpperCase();
        final tMod = targetMod.toUpperCase();
        final tAct = targetAct.toUpperCase();

        final customerModule =
            tMod.startsWith('CUSTOMER_') || pMod.startsWith('CUSTOMER_');
        final modMatches = customerModule
            ? pMod == tMod
            : pMod == tMod ||
                pMod == tMod.replaceAll('_', '') ||
                (pMod.endsWith('S') && pMod.substring(0, pMod.length - 1) == tMod) ||
                (tMod.endsWith('S') && tMod.substring(0, tMod.length - 1) == pMod);

        final actMatches = pAct == tAct ||
            pAct == '*' ||
            pAct == 'ALL' ||
            pAct == 'MANAGE' ||
            (tAct == 'VIEW' && (pAct == 'READ' || pAct == 'VIEW')) ||
            (tAct == 'CREATE' &&
                (pAct == 'CREATE' ||
                    pAct == 'SCHEDULE' ||
                    pAct == 'ADD'));

        return modMatches && actMatches;
      },
    );
  }

  /// Convenience CRUD & Action checks
  bool canView(String module) {
    if (hasPermission(module, PermissionAction.view)) return true;
    final norm = AppModule.normalize(module).toUpperCase();
    return permissions.any((p) {
      final pMod = p.module.toUpperCase();
      return pMod == norm ||
          pMod == norm.replaceAll('_', '') ||
          (pMod.endsWith('S') && pMod.substring(0, pMod.length - 1) == norm) ||
          (norm.endsWith('S') && norm.substring(0, norm.length - 1) == pMod);
    });
  }

  bool canCreate(String module) =>
      hasPermission(module, PermissionAction.create);
  bool canEdit(String module) => hasPermission(module, PermissionAction.edit);
  bool canDelete(String module) =>
      hasPermission(module, PermissionAction.delete);
  bool canAction(String module, String action) => hasPermission(module, action);
  bool canPerformAction(String module, String action) =>
      hasPermission(module, action);

  /// Specific Granular UI Action & Screen getters
  bool get canViewCalendar =>
      hasPermission("employee.calendar.view") ||
      hasPermission("CALENDAR", "VIEW") ||
      hasPermission("CALENDAR", "READ") ||
      canView(AppModule.calendar);
  bool get canCreateCalendar =>
      hasPermission("employee.calendar.create") ||
      hasPermission("CALENDAR", "CREATE") ||
      hasPermission("CALENDAR", "SCHEDULE") ||
      canCreate(AppModule.calendar);
  bool get canViewMyWork =>
      hasPermission("employee.my_work.view") ||
      canView(AppModule.myWork) ||
      canView(AppModule.creativeWork);
  bool get canViewPackages =>
      hasPermission("employee.packages.view") || canView(AppModule.packages);
  bool get canViewWorkExecution =>
      hasPermission("employee.work_execution.view") ||
      canView(AppModule.workExecution);
  bool get canViewCreativeWork =>
      hasPermission("employee.creative_work.view") ||
      canView(AppModule.creativeWork);
  bool get canViewRemoteWork =>
      hasPermission("employee.remote_work.view") ||
      canView(AppModule.remoteWork);
  bool get canViewExpenses =>
      hasPermission("employee.expenses.view") || canView(AppModule.expenses);
  bool get canChangeLeadStage => hasPermission("employee.leads.change_stage");
  bool get canApproveCreativeWork =>
      hasPermission("employee.creative_work.approve");
  bool get canApproveTask => hasPermission("employee.tasks.approve");
  bool get canReopenWork => hasPermission("employee.work_execution.reopen");
  bool get canScheduleVisits =>
      canCreate(AppModule.visits) ||
      hasPermission("VISITS", "CREATE") ||
      hasPermission("employee.visits.create") ||
      hasPermission("LEADS", "SCHEDULE_VISIT");
  bool get canStartVisit =>
      hasPermission("VISITS", "START") ||
      hasPermission("employee.visits.start") ||
      canEdit(AppModule.visits);
  bool get canCompleteVisit =>
      hasPermission("VISITS", "COMPLETE") ||
      hasPermission("employee.visits.complete") ||
      canEdit(AppModule.visits);
  bool get canDeleteVisit =>
      hasPermission("VISITS", "DELETE") ||
      hasPermission("employee.visits.delete") ||
      canDelete(AppModule.visits);

  /// Standard Business Module Getters
  bool get canViewLeads => canView(AppModule.leads);
  bool get canViewFollowUp => canView(AppModule.followUp);
  bool get canViewVisits =>
      hasPermission(AppModule.visits, PermissionAction.view) ||
      hasPermission("VISITS", "VIEW") ||
      hasPermission("employee.visits.view");
  bool get canViewTasks => canView(AppModule.tasks);
  bool get canViewAttendance => canView(AppModule.attendance);
  bool get canViewLeave => canView(AppModule.leave);
  bool get canViewSalary => canView(AppModule.salary);
  bool get canViewLoan => canView(AppModule.loan);
  bool get canViewCustomers => canView(AppModule.customers);
  bool get canViewDataCapture => canView(AppModule.dataCapture);
  bool get canViewProposals => canView(AppModule.proposals);
  bool get canViewPayments => canView(AppModule.payments);
  bool get canViewNotifications => canView(AppModule.notifications);
  bool get canViewDashboard => canView(AppModule.dashboard);
  bool get canViewCommission =>
      hasPermission("employee.commission.view") ||
      hasPermission("COMMISSION", "VIEW") ||
      canView(AppModule.commission);

  /// CRM Mobile Access: true ONLY for CRM-eligible staff (BPO / Telesales) with at least 1 CRM child module permission
  bool get hasCrmAccess =>
      isCrmEligible && (canViewDataCapture || canViewLeads || canViewCustomers);

  /// Check whether user can access a given screen or page
  bool canAccessScreen(String screenName) {
    final s = screenName.trim().toUpperCase();
    switch (s) {
      case 'DASHBOARD':
      case 'HOME':
        return canView(AppModule.dashboard);
      case 'LEADS':
        return canView(AppModule.leads);
      case 'CUSTOMERS':
      case 'CLIENTS':
        return canView(AppModule.customers);
      case 'DATA_CAPTURE':
      case 'DATACAPTURE':
      case 'DATA-CAPTURE':
      case 'CAPTURE':
        return canView(AppModule.dataCapture);
      case 'FOLLOW_UPS':
      case 'FOLLOWUPS':
      case 'FOLLOW_UP':
        return canView(AppModule.followUp);
      case 'VISITS':
        return canViewVisits;
      case 'PROPOSALS':
        return canView(AppModule.proposals);
      case 'PACKAGES':
        return canViewPackages;
      case 'PAYMENTS':
        return canView(AppModule.payments);
      case 'WORK':
      case 'WORK_EXECUTION':
        return canViewWorkExecution;
      case 'CALENDAR':
      case 'SCHEDULE':
        return canViewCalendar;
      case 'MY_WORK':
        return canViewMyWork;
      case 'CREATIVE':
      case 'CREATIVE_WORK':
      case 'SSM':
        return canViewCreativeWork;
      case 'NOTIFICATIONS':
        return canView(AppModule.notifications);
      case 'ATTENDANCE':
        return canView(AppModule.attendance);
      case 'LEAVE':
      case 'REQUESTS':
        return canView(AppModule.leave);
      case 'EXPENSES':
        return canViewExpenses;
      case 'REMOTE_WORK':
      case 'WFH':
        return canViewRemoteWork;
      case 'TASKS':
        return canView(AppModule.tasks);
      case 'SALARY':
      case 'SALARY_SLIP':
        return canView(AppModule.salary);
      case 'LOAN':
        return canView(AppModule.loan);
      case 'REPORTS':
        return canView(AppModule.reports);
      case 'SETTINGS':
        return canView(AppModule.settings);
      case 'COMMISSION':
      case 'COMMISSIONS':
        return canViewCommission;
      default:
        return canView(AppModule.normalize(screenName));
    }
  }

  /// Check if user has ANY access (at least VIEW) to a module
  bool hasModuleAccess(String module) => canView(module);

  /// Section & Tab level permission checking
  bool canViewTab(String module, String tabKey) {
    if (!canView(module)) return false;
    final normTab = tabKey.toUpperCase();
    // If specific tab permission exists, check it
    final specificTabPerm = permissions.any(
      (p) =>
          p.module == AppModule.normalize(module) &&
          (p.action == normTab || p.action == "TAB_$normTab"),
    );
    // If explicit tab permissions are used for this module, require it; else default to view permission
    final moduleHasTabRestrictions = permissions.any(
      (p) =>
          p.module == AppModule.normalize(module) &&
          p.action.startsWith("TAB_"),
    );
    return moduleHasTabRestrictions ? specificTabPerm : true;
  }

  /// Dashboard Widget & Card level permission checking
  bool canViewCard(String cardKey) {
    final normCard = cardKey.toUpperCase();
    // 1. Direct card check on DASHBOARD (e.g. CARD_LEADS, CARD_STATS, CARD_VISITS)
    if (permissions.any(
      (p) =>
          p.module == AppModule.dashboard &&
          (p.action == normCard || p.action == "CARD_$normCard"),
    )) {
      return true;
    }

    // 2. Underlying module view check
    if (normCard.contains("LEAD") || normCard.contains("FOLLOW")) {
      return canView(AppModule.leads);
    }
    if (normCard.contains("CLIENT") || normCard.contains("CUSTOMER")) {
      return canView(AppModule.customers);
    }
    if (normCard.contains("VISIT")) {
      return canView(AppModule.visits);
    }
    if (normCard.contains("PROPOSAL")) {
      return canView(AppModule.proposals);
    }
    if (normCard.contains("WORK") || normCard.contains("TASK")) {
      return canView(AppModule.tasks);
    }
    if (normCard.contains("EMPLOYEE") || normCard.contains("TEAM")) {
      return canView("EMPLOYEES") ||
          canView(AppModule.tasks) ||
          canView(AppModule.settings);
    }
    if (normCard.contains("ATTENDANCE")) {
      return canView(AppModule.attendance);
    }
    if (normCard.contains("PAYMENT") || normCard.contains("REVENUE")) {
      return canView(AppModule.payments);
    }
    if (normCard.contains("STATS") || normCard.contains("SUMMARY")) {
      return canView(AppModule.dashboard);
    }

    return canView(AppModule.dashboard);
  }

  /// Settings item level permission checking
  bool canViewSetting(String settingKey) {
    if (!canView(AppModule.settings)) return false;
    final normSetting = settingKey.toUpperCase();
    final specificSettingPerm = permissions.any(
      (p) =>
          p.module == AppModule.settings &&
          (p.action == normSetting || p.action == "SETTING_$normSetting"),
    );
    final moduleHasSettingRestrictions = permissions.any(
      (p) => p.module == AppModule.settings && p.action.startsWith("SETTING_"),
    );

    if (moduleHasSettingRestrictions) {
      return specificSettingPerm;
    }

    // Fallback based on specific sensitive settings
    if (normSetting.contains("INTEGRATION")) {
      return permissions.any(
        (p) =>
            p.module == AppModule.settings &&
            p.action == "SETTING_INTEGRATIONS",
      );
    }
    if (normSetting.contains("USER") || normSetting.contains("ROLE")) {
      return permissions.any(
        (p) => p.module == AppModule.settings && p.action == "SETTING_USERS",
      );
    }
    return true;
  }

  /// Get aggregated permissions for a module
  ModulePermissions getModulePermissions(String module) {
    final normModule = AppModule.normalize(module);
    return ModulePermissions(
      module: normModule,
      canView: canView(normModule),
      canCreate: canCreate(normModule),
      canEdit: canEdit(normModule),
      canDelete: canDelete(normModule),
    );
  }

  /// Get list of all modules the user is authorized to view
  List<String> getAvailableModules() {
    return AppModule.all.where((m) => canView(m)).toList();
  }

  PermissionState copyWith({
    List<UserPermission>? permissions,
    String? role,
    String? employeeId,
    String? designationId,
    String? tenantId,
    bool? isCrmEligible,
    String? crmCategory,
    bool? isInitialized,
    bool? isLoading,
    String? error,
    DateTime? lastFetchedAt,
  }) {
    return PermissionState(
      permissions: permissions ?? this.permissions,
      role: role ?? this.role,
      employeeId: employeeId ?? this.employeeId,
      designationId: designationId ?? this.designationId,
      tenantId: tenantId ?? this.tenantId,
      isCrmEligible: isCrmEligible ?? this.isCrmEligible,
      crmCategory: crmCategory ?? this.crmCategory,
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
    );
  }

  @override
  String toString() =>
      "PermissionState(role: $role, employeeId: $employeeId, designationId: $designationId, initialized: $isInitialized, loading: $isLoading, error: $error, count: ${permissions.length})";
}

/// Riverpod Notifier for managing reactive permission state in the app
class PermissionNotifier extends Notifier<PermissionState> {
  @override
  PermissionState build() {
    Future.microtask(() => _restoreFromCache());
    return PermissionManager.instance.currentState;
  }

  Future<void> _restoreFromCache() async {
    if (state.isInitialized && state.permissions.isNotEmpty) return;
    try {
      final cached = await SecureStorageService.getPermissions();
      if (cached.isNotEmpty &&
          (!state.isInitialized || state.permissions.isEmpty)) {
        final roleStr = await SecureStorageService.getUserRole();
        final isCrm = await SecureStorageService.getCrmMobileAccess();
        final crmCategory = await SecureStorageService.getCrmCategory();
        setPermissions(
          cached,
          role: roleStr,
          isCrmEligible: isCrm,
          crmCategory: crmCategory,
        );
      }
    } catch (_) {}
  }

  void setLoading([bool loading = true]) {
    PermissionManager.instance.setLoading(loading);
    state = PermissionManager.instance.currentState;
  }

  void setError(String error) {
    PermissionManager.instance.setError(error);
    state = PermissionManager.instance.currentState;
  }

  void setPermissions(
    List<UserPermission> permissions, {
    String? role,
    String? employeeId,
    String? designationId,
    String? tenantId,
    bool? isCrmEligible,
    String? crmCategory,
  }) {
    PermissionManager.instance.setPermissions(
      permissions,
      role: role,
      employeeId: employeeId,
      designationId: designationId,
      tenantId: tenantId,
      isCrmEligible: isCrmEligible,
      crmCategory: crmCategory,
    );
    state = PermissionManager.instance.currentState;
  }

  void clear() {
    PermissionManager.instance.clear();
    state = PermissionManager.instance.currentState;
  }

  bool canView(String module) => state.canView(module);
  bool canCreate(String module) => state.canCreate(module);
  bool canEdit(String module) => state.canEdit(module);
  bool canDelete(String module) => state.canDelete(module);
  bool canAction(String module, String action) =>
      state.canAction(module, action);
  bool canPerformAction(String module, String action) =>
      state.canPerformAction(module, action);
  bool canAccessScreen(String screenName) => state.canAccessScreen(screenName);
  bool canViewTab(String module, String tabKey) =>
      state.canViewTab(module, tabKey);
  bool canViewCard(String cardKey) => state.canViewCard(cardKey);
  bool canViewSetting(String settingKey) => state.canViewSetting(settingKey);
  bool hasPermission(String moduleOrKey, [String? action]) =>
      state.hasPermission(moduleOrKey, action);

  bool get canViewCalendar => state.canViewCalendar;
  bool get canCreateCalendar => state.canCreateCalendar;
  bool get canViewMyWork => state.canViewMyWork;
  bool get canViewPackages => state.canViewPackages;
  bool get canViewWorkExecution => state.canViewWorkExecution;
  bool get canViewCreativeWork => state.canViewCreativeWork;
  bool get canViewRemoteWork => state.canViewRemoteWork;
  bool get canViewExpenses => state.canViewExpenses;
  bool get canChangeLeadStage => state.canChangeLeadStage;
  bool get canApproveCreativeWork => state.canApproveCreativeWork;
  bool get canApproveTask => state.canApproveTask;
  bool get canReopenWork => state.canReopenWork;
  bool get canScheduleVisits => state.canScheduleVisits;
  bool get canStartVisit => state.canStartVisit;
  bool get canCompleteVisit => state.canCompleteVisit;
  bool get canDeleteVisit => state.canDeleteVisit;

  bool get canViewLeads => state.canViewLeads;
  bool get canViewFollowUp => state.canViewFollowUp;
  bool get canViewVisits => state.canViewVisits;
  bool get canViewTasks => state.canViewTasks;
  bool get canViewAttendance => state.canViewAttendance;
  bool get canViewLeave => state.canViewLeave;
  bool get canViewSalary => state.canViewSalary;
  bool get canViewLoan => state.canViewLoan;
  bool get canViewCustomers => state.canViewCustomers;
  bool get canViewProposals => state.canViewProposals;
  bool get canViewPayments => state.canViewPayments;
  bool get canViewNotifications => state.canViewNotifications;
  bool get canViewDashboard => state.canViewDashboard;
  bool get canViewDataCapture => state.canViewDataCapture;
  bool get canViewCommission => state.canViewCommission;
  bool get isCrmEligible => state.isCrmEligible;
  String? get crmCategory => state.crmCategory;
  bool get hasCrmAccess => state.hasCrmAccess;
}

final permissionManagerProvider =
    NotifierProvider<PermissionNotifier, PermissionState>(
      PermissionNotifier.new,
    );

/// Singleton instance for synchronous permission evaluation when ref is unavailable
class PermissionManager {
  PermissionManager._internal();
  static final PermissionManager instance = PermissionManager._internal();

  PermissionState _state = const PermissionState();

  PermissionState get currentState => _state;

  void setLoading([bool loading = true]) {
    _state = _state.copyWith(isLoading: loading, error: null);
  }

  void setError(String error) {
    _state = _state.copyWith(
      isLoading: false,
      isInitialized: true,
      error: error,
    );
  }

  void setPermissions(
    List<UserPermission> permissions, {
    String? role,
    String? employeeId,
    String? designationId,
    String? tenantId,
    bool? isCrmEligible,
    String? crmCategory,
  }) {
    _state = PermissionState(
      permissions: List.unmodifiable(permissions),
      role: role ?? _state.role,
      employeeId: employeeId ?? _state.employeeId,
      designationId: designationId ?? _state.designationId,
      tenantId: tenantId ?? _state.tenantId,
      isCrmEligible: isCrmEligible ?? _state.isCrmEligible,
      crmCategory: crmCategory ?? _state.crmCategory,
      isInitialized: true,
      isLoading: false,
      error: null,
      lastFetchedAt: DateTime.now(),
    );
    debugPrint(
      "[PERMISSION_MANAGER] Updated permissions: count=${permissions.length}, role=${_state.role}, employeeId=${_state.employeeId}, designationId=${_state.designationId}, isCrmEligible=${_state.isCrmEligible}",
    );
  }

  void updateRole(String role) {
    _state = _state.copyWith(role: role);
  }

  void clear() {
    _state = const PermissionState(
      permissions: [],
      role: null,
      employeeId: null,
      designationId: null,
      tenantId: null,
      isCrmEligible: false,
      crmCategory: null,
      isInitialized: false,
      isLoading: false,
      error: null,
    );
    debugPrint(
      "[PERMISSION_MANAGER] Permissions cleared on logout/reset (isCrmEligible=false)",
    );
  }

  bool get isReady => _state.isReady;
  bool canView(String module) => _state.canView(module);
  bool canCreate(String module) => _state.canCreate(module);
  bool canEdit(String module) => _state.canEdit(module);
  bool canDelete(String module) => _state.canDelete(module);
  bool canAction(String module, String action) =>
      _state.canAction(module, action);
  bool canPerformAction(String module, String action) =>
      _state.canPerformAction(module, action);
  bool canAccessScreen(String screenName) => _state.canAccessScreen(screenName);
  bool canViewTab(String module, String tabKey) =>
      _state.canViewTab(module, tabKey);
  bool canViewCard(String cardKey) => _state.canViewCard(cardKey);
  bool canViewSetting(String settingKey) => _state.canViewSetting(settingKey);
  bool hasPermission(String moduleOrKey, [String? action]) =>
      _state.hasPermission(moduleOrKey, action);

  bool get canViewCalendar => _state.canViewCalendar;
  bool get canCreateCalendar => _state.canCreateCalendar;
  bool get canViewMyWork => _state.canViewMyWork;
  bool get canViewPackages => _state.canViewPackages;
  bool get canViewWorkExecution => _state.canViewWorkExecution;
  bool get canViewCreativeWork => _state.canViewCreativeWork;
  bool get canViewRemoteWork => _state.canViewRemoteWork;
  bool get canViewExpenses => _state.canViewExpenses;
  bool get canChangeLeadStage => _state.canChangeLeadStage;
  bool get canApproveCreativeWork => _state.canApproveCreativeWork;
  bool get canApproveTask => _state.canApproveTask;
  bool get canReopenWork => _state.canReopenWork;
  bool get canScheduleVisits => _state.canScheduleVisits;
  bool get canStartVisit => _state.canStartVisit;
  bool get canCompleteVisit => _state.canCompleteVisit;
  bool get canDeleteVisit => _state.canDeleteVisit;

  bool get canViewLeads => _state.canViewLeads;
  bool get canViewFollowUp => _state.canViewFollowUp;
  bool get canViewVisits => _state.canViewVisits;
  bool get canViewTasks => _state.canViewTasks;
  bool get canViewAttendance => _state.canViewAttendance;
  bool get canViewLeave => _state.canViewLeave;
  bool get canViewSalary => _state.canViewSalary;
  bool get canViewLoan => _state.canViewLoan;
  bool get canViewCustomers => _state.canViewCustomers;
  bool get canViewProposals => _state.canViewProposals;
  bool get canViewPayments => _state.canViewPayments;
  bool get canViewNotifications => _state.canViewNotifications;
  bool get canViewDashboard => _state.canViewDashboard;
  bool get canViewDataCapture => _state.canViewDataCapture;
  bool get canViewCommission => _state.canViewCommission;
  bool get isCrmEligible => _state.isCrmEligible;
  String? get crmCategory => _state.crmCategory;
  bool get hasCrmAccess => _state.hasCrmAccess;

  ModulePermissions getModulePermissions(String module) =>
      _state.getModulePermissions(module);
  List<String> getAvailableModules() => _state.getAvailableModules();
}
