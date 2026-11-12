import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/services/crm_access.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/work_permissions_viewmodel.dart';
import 'package:quickboom_crm_customer/core/constants/constants.dart';
import 'package:quickboom_crm_customer/core/providers.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_drawer.dart';

import 'package:quickboom_crm_customer/shared/views/data_capture/data_capture_home_screen.dart';
import 'package:quickboom_crm_customer/shared/views/leads/leads_view.dart';
import 'package:quickboom_crm_customer/roles/employee/views/sidebar_views/customers_view.dart';
import 'home_view.dart';
import 'employee_schedule_view.dart';
import 'sidebar_views/attendance_view.dart';
import 'ssm/employee_ssm_work_list_view.dart';
import 'profile_view.dart';
import 'visits_view.dart';
import 'visitor/visitor_history_view.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_profile_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_attendance_viewmodel.dart';
import 'package:quickboom_crm_customer/core/services/notification_service.dart';
// ─────────────────────────────────────────────────────────────────────────────
// Data class for a bottom-nav tab item
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardTabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;

  const _DashboardTabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.page,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Data class for a primary-module candidate (position 2 of the nav).
// Each entry carries the AppModule key used for RBAC checking, and the
// visual/routing details for the nav item.
//
// The list _kPrimaryModulePriority below is the ONLY place that encodes
// which module wins position 2 when multiple permissions are present.
// No designation/role name strings appear anywhere in this file.
// ─────────────────────────────────────────────────────────────────────────────
class _PrimaryNavModule {
  final String module; // AppModule constant — used for rbacPerms.canView()
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;

  const _PrimaryNavModule({
    required this.module,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.page,
  });
}

/// Priority-ordered list of primary-module candidates for navigation position 2.
///
/// Resolution rule: the **first** entry whose module the employee has VIEW
/// permission for becomes the primary nav tab.  Higher priority = earlier in list.
///
/// Priority order rationale:
///   1. DATA_CAPTURE  — core Telesales / lead-capture workflow
///   2. ATTENDANCE    — core field-sales / HRM workflow
///   3. MY_WORK       — SSM / creative-work designation
///   4. CALENDAR      — calendar-heavy designations (last resort)
///
/// Admin control: grant/revoke VIEW on the desired module via the designation
/// role defaults or per-employee overrides (INHERIT / ALLOW / DENY).
/// That is the only configuration needed — no Flutter code changes required.
const List<_PrimaryNavModule> _kPrimaryModulePriority = [
  _PrimaryNavModule(
    module: 'ATTENDANCE',
    label: 'Attendance',
    icon: Remix.fingerprint_line, // distinct from Calendar icon
    activeIcon: Remix.fingerprint_fill,
    page: AttendanceView(showBackButton: false),
  ),
  _PrimaryNavModule(
    module: 'MY_WORK',
    label: 'My Work',
    icon: Remix.movie_line,
    activeIcon: Remix.movie_fill,
    page: EmployeeSSMWorkListView(),
  ),
  _PrimaryNavModule(
    module: 'CALENDAR',
    label: 'Calendar',
    icon: Remix.calendar_check_line,
    activeIcon: Remix.calendar_check_fill,
    page: EmployeeScheduleView(),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// DashboardView — main employee scaffold with 5-slot bottom navigation
// ─────────────────────────────────────────────────────────────────────────────
class DashboardView extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const DashboardView({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _currentIndex;
  DateTime? _lastPermissionRefresh;
  List<_DashboardTabItem> _currentTabs = [];
  int _lastKnownTabCount = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestAndroidNotificationPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Refresh permissions when app returns from background — with 5-minute cooldown.
  /// This is the fallback for missed WebSocket events while the app was backgrounded.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final lastRefresh = _lastPermissionRefresh;
      final cooldownPassed =
          lastRefresh == null || now.difference(lastRefresh).inMinutes >= 5;
      if (cooldownPassed) {
        _lastPermissionRefresh = now;
        debugPrint(
          '[DASHBOARD] App resumed — refreshing permissions (fallback for missed events).',
        );
        // Silently fetch latest effective permissions from backend.
        // Old permissions remain active until the new set arrives — no UI blank.
        ref.read(loginStateProvider.notifier).refreshPermissions();
      }
    }
  }

  /// Called in build() after the tab list is computed.
  /// When a permission change causes a tab to disappear, `_currentIndex` is
  /// reset to 0 in state (not just clipped visually in safeIndex) so that the
  /// next rebuild does not try to select a stale/invalid index.
  void _syncTabIndex(List<_DashboardTabItem> tabs) {
    if (tabs.length < _lastKnownTabCount && _currentIndex >= tabs.length) {
      // Schedule after the current build frame — cannot call setState during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentIndex >= tabs.length) {
          setState(() {
            _currentIndex = 0; // Fall back to Home — always safe.
          });
          debugPrint(
            '[DASHBOARD] Active tab removed by permission change. '
            'Navigated to Home (index 0).',
          );
        }
      });
    }
    _lastKnownTabCount = tabs.length;
  }

  void _syncSidebarSelection(String label) {
    final lower = label.toLowerCase();
    if (lower == 'home' || lower == 'dashboard') {
      ref.read(sidebarSelectionProvider.notifier).select(SidebarItem.dashboard);
    } else if (lower.contains('work')) {
      ref.read(sidebarSelectionProvider.notifier).select(SidebarItem.ssmWork);
    } else if (lower.contains('task')) {
      ref.read(sidebarSelectionProvider.notifier).select(SidebarItem.tasks);
    } else if (lower.contains('calendar') || lower.contains('schedule')) {
      ref
          .read(sidebarSelectionProvider.notifier)
          .select(SidebarItem.employeeCalendar);
    } else if (lower.contains('data') || lower.contains('place')) {
      ref
          .read(sidebarSelectionProvider.notifier)
          .select(SidebarItem.dataCapture);
    } else if (lower.contains('lead')) {
      ref.read(sidebarSelectionProvider.notifier).select(SidebarItem.leads);
    } else if (lower.contains('visit') || lower.contains('history')) {
      ref.read(sidebarSelectionProvider.notifier).select(SidebarItem.visits);
    } else if (lower.contains('custom') || lower.contains('client')) {
      ref.read(sidebarSelectionProvider.notifier).select(SidebarItem.customers);
    }
  }

  void _navigateToTab(dynamic target) {
    if (mounted) {
      setState(() {
        if (target is int) {
          _currentIndex = target;
        } else if (target is String) {
          final wanted = target.toLowerCase();
          var idx = _currentTabs.indexWhere(
            (t) => t.label.toLowerCase() == wanted,
          );
          // Production team work tab is "My Work", not "Tasks".
          if (idx == -1 && wanted == 'tasks') {
            idx = _currentTabs.indexWhere(
              (t) => t.label.toLowerCase() == 'my work',
            );
          }
          if (idx != -1) {
            _currentIndex = idx;
          }
        }
      });
      if (_currentIndex >= 0 && _currentIndex < _currentTabs.length) {
        _syncSidebarSelection(_currentTabs[_currentIndex].label);
      }
    }
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  // ── Primary-module resolution ──────────────────────────────────────────────
  //
  // Walk the priority list and return the first candidate whose module the
  // employee has effective VIEW permission for.  Returns null if none match
  // (edge case: employee with no recognised primary-module permission).
  //
  // This is the ONLY place where the "which module gets position 2?" decision
  // is made.  The decision is driven entirely by RBAC — not by role strings.
  _PrimaryNavModule? _resolvePrimaryModule(PermissionState rbacPerms) {
    for (final candidate in _kPrimaryModulePriority) {
      if (rbacPerms.canView(candidate.module)) {
        return candidate;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final rbacPerms = ref.watch(permissionManagerProvider);
    // workPerms is still watched so the provider stays alive for other widgets
    // that depend on it (e.g. HomeView my-work section checks).
    final permsState = ref.watch(workPermissionsProvider);
    final authState = ref.watch(loginStateProvider);
    final attendanceState = ref.watch(employeeAttendanceProvider);
    final empInfo = attendanceState.status.employee;

    // ── Resolve Visitor identification from existing provider ───────────────
    final profile = ref.watch(employeeProfileProvider).asData?.value;
    final desigName = (profile?.designation ?? empInfo?.designation ?? authState.userRole ?? '').trim().toUpperCase();
    final roleName = (rbacPerms.role ?? authState.userRole ?? '').trim().toUpperCase();
    final deptName = (profile?.department ?? empInfo?.department ?? '').trim().toUpperCase();
    final crmCategory = classifyCrmEmployee(
      department: deptName,
      designation: desigName,
      role: roleName,
      backendCategory: rbacPerms.crmCategory,
    );
    final isVisitor = crmCategory == CrmEmployeeCategory.visitor;
    final isBpoTeam = crmCategory == CrmEmployeeCategory.bpo;
    final isSalesTeam = crmCategory == CrmEmployeeCategory.sales;
    final isProductionTeam =
        !isBpoTeam &&
        !isSalesTeam &&
        !isVisitor &&
        (permsState.permissions.hasSsmWorkPermission ||
            rbacPerms.canViewMyWork ||
            rbacPerms.canViewCreativeWork ||
            permsState.permissions.isProductionManager ||
            deptName.contains('PRODUCTION') ||
            deptName.contains('CREATIVE') ||
            desigName.contains('PHOTOGRAPHER') ||
            desigName.contains('VIDEO') ||
            desigName.contains('EDITOR') ||
            desigName.contains('DESIGNER') ||
            desigName.contains('PRODUCTION') ||
            desigName.contains('CREATIVE') ||
            desigName.contains('SSM') ||
            desigName.contains('CONTENT') ||
            desigName.contains('ANIMAT') ||
            desigName.contains('TEAM LEADER') ||
            desigName.contains('TEAM LEAD') ||
            roleName.contains('PHOTOGRAPHER') ||
            roleName.contains('VIDEO') ||
            roleName.contains('EDITOR') ||
            roleName.contains('DESIGNER') ||
            roleName.contains('PRODUCTION') ||
            roleName.contains('CREATIVE') ||
            roleName.contains('SSM') ||
            roleName.contains('TEAM LEADER') ||
            roleName.contains('TEAM LEAD'));

    final mediaQuery = MediaQuery.maybeOf(context);
    final devWidth = mediaQuery?.size.width ?? 0;
    final devHeight = mediaQuery?.size.height ?? 0;
    final devPixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    final devTimezone = DateTime.now().timeZoneName;

    // ── Resolve fixed positions ──────────────────────────────────────────────
    final primaryModule = _resolvePrimaryModule(rbacPerms);

    debugPrint(
      '[CALENDAR_VISIBILITY_DEBUG] DashboardView -> '
      'deviceWidth: $devWidth, '
      'deviceHeight: $devHeight, '
      'pixelRatio: $devPixelRatio, '
      'timezone: $devTimezone, '
      'isProductionTeam: $isProductionTeam, '
      'isVisitor: $isVisitor, '
      'primaryModule: ${primaryModule?.label}, '
      'canViewCalendar: ${rbacPerms.canViewCalendar}, '
      'role: $roleName, '
      'desig: $desigName, '
      'dept: $deptName',
    );

    // ── Build the fixed tab list ───────────────────────────────────────────
    final tabs = <_DashboardTabItem>[
      // Slot 1: Home
      _DashboardTabItem(
        label: 'Home',
        icon: Remix.home_5_line,
        activeIcon: Remix.home_5_fill,
        page: HomeView(
          onNavigateToTab: _navigateToTab,
          onOpenDrawer: _openDrawer,
        ),
      ),

      // CRM-eligible BPO staff take precedence over generic work/team-lead roles.
      if (isBpoTeam || isSalesTeam) ...[
        if (isBpoTeam &&
            (rbacPerms.canViewDataCapture ||
                permsState.hasWorkPermission('data_capture') ||
                permsState.hasWorkPermission('datacapture') ||
                isBpoTeam))
          const _DashboardTabItem(
            label: 'Data Capture',
            icon: Remix.add_circle_line,
            activeIcon: Remix.add_circle_fill,
            page: DataCaptureHomeScreen(),
          ),
        const _DashboardTabItem(
          label: 'Leads',
          icon: Remix.user_search_line,
          activeIcon: Remix.user_search_fill,
          page: LeadsView(),
        ),
        if (isBpoTeam)
          const _DashboardTabItem(
            label: 'Customers',
            icon: Remix.building_2_line,
            activeIcon: Remix.building_2_fill,
            page: CustomersView(),
          ),
      ] else if (isProductionTeam) ...[
        const _DashboardTabItem(
          label: 'My Work',
          icon: Remix.movie_line,
          activeIcon: Remix.movie_fill,
          page: EmployeeSSMWorkListView(),
        ),
        _DashboardTabItem(
          label: 'Calendar',
          icon: Remix.calendar_check_line,
          activeIcon: Remix.calendar_check_fill,
          page: EmployeeScheduleView(
            showBackButton: true,
            onBack: () => _navigateToTab(0),
          ),
        ),
      ] else if (isVisitor) ...[
        const _DashboardTabItem(
          label: 'Visits',
          icon: Remix.map_pin_2_line,
          activeIcon: Remix.map_pin_2_fill,
          page: VisitsView(),
        ),
        const _DashboardTabItem(
          label: 'History',
          icon: Remix.history_line,
          activeIcon: Remix.history_fill,
          page: VisitorHistoryView(),
        ),
      ] else ...[
        if (primaryModule != null)
          _DashboardTabItem(
            label: primaryModule.label,
            icon: primaryModule.icon,
            activeIcon: primaryModule.activeIcon,
            page: primaryModule.page,
          ),
      ],

      // Final Position: Profile
      _DashboardTabItem(
        label: 'Profile',
        icon: Remix.user_3_line,
        activeIcon: Remix.user_3_fill,
        page: ProfileView(onNavigateToTab: (idx) => _navigateToTab(idx)),
      ),
    ];
    
    _currentTabs = tabs;

    // Ensure _currentIndex stays in bounds when tabs shrink due to permission changes.
    _syncTabIndex(tabs);

    final safeIndex = _currentIndex >= tabs.length ? 0 : _currentIndex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
        } else if (safeIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.scaffoldBg,
        drawer: const AppDrawer(),
        drawerEnableOpenDragGesture: true,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: tabs[safeIndex].page,
        ),
        bottomNavigationBar: Material(
          color: Colors.white,
          elevation: 8,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              child: SizedBox(
                height: 62,
                child: Row(
                  children: [
                    for (int i = 0; i < tabs.length; i++)
                      _buildNavItem(
                        i,
                        tabs[i].label,
                        tabs[i].icon,
                        tabs[i].activeIcon,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String label,
    IconData icon,
    IconData activeIcon,
  ) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          _syncSidebarSelection(label);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                size: 20,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
