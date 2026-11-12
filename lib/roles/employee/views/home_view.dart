import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/core/services/employee_live_tracking_service.dart';
import 'package:quickboom_crm_customer/core/models/user_role.dart';
import 'package:quickboom_crm_customer/core/services/crm_access.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import '../viewmodels/employee_attendance_viewmodel.dart';
import '../viewmodels/employee_profile_viewmodel.dart';
import '../viewmodels/work_permissions_viewmodel.dart';
import '../viewmodels/employee_calendar_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/views/employee_schedule_view.dart';
import 'visitor/visitor_home_section.dart';
import '../widgets/employee_home_calendar_section.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';
import 'package:quickboom_crm_customer/shared/widgets/animated_notification_bell.dart';
import '../viewmodels/employee_notification_viewmodel.dart';
import 'notifications_view.dart';
import '../widgets/lead_limit_card.dart';
import '../viewmodels/lead_limit_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/views/leads/leads_view.dart';
import '../widgets/overtime_panel.dart';

class EmployeeHomeView extends ConsumerStatefulWidget {
  final Function(dynamic)? onNavigateToTab;
  final VoidCallback? onOpenDrawer;

  const EmployeeHomeView({super.key, this.onNavigateToTab, this.onOpenDrawer});

  @override
  ConsumerState<EmployeeHomeView> createState() => _EmployeeHomeViewState();
}

class _EmployeeHomeViewState extends ConsumerState<EmployeeHomeView>
    with WidgetsBindingObserver {
  Timer? _liveClockTimer;
  int? _lastLoggedPermissionCount;
  String? _homeRefreshError;
  Future<void>? _homeRefreshInFlight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 1-second live ticker for local working hours, break duration and clock
    final isRunningInTest =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isRunningInTest) {
      _liveClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      debugPrint(
        '[APP_LIFECYCLE] Resumed: refreshing attendance state, live location, and lead limits',
      );
      _refreshAllData();
      EmployeeLiveTrackingService().sendImmediateLocationIfActive();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveClockTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAllData() async {
    final activeRefresh = _homeRefreshInFlight;
    if (activeRefresh != null) return activeRefresh;

    if (!mounted) return;
    setState(() => _homeRefreshError = null);
    final refresh = _loadHomeData().timeout(const Duration(seconds: 60));
    _homeRefreshInFlight = refresh;
    try {
      await refresh;
    } catch (error, stack) {
      if (!mounted) return;
      debugPrint(
        '[EMPLOYEE_HOME] Refresh failed: ${error.runtimeType}\n$stack',
      );
      if (ref.read(permissionManagerProvider).isLoading) {
        ref.read(permissionManagerProvider.notifier).setLoading(false);
      }
      setState(
        () => _homeRefreshError = error is TimeoutException
            ? 'Some dashboard data took too long to load. Please retry.'
            : 'Some dashboard data could not be loaded. Please retry.',
      );
    } finally {
      if (identical(_homeRefreshInFlight, refresh)) {
        _homeRefreshInFlight = null;
      }
      if (mounted && ref.read(permissionManagerProvider).isLoading) {
        ref.read(permissionManagerProvider.notifier).setLoading(false);
      }
    }
  }

  Future<void> _loadHomeData() async {
    final rbacPerms = ref.read(permissionManagerProvider);
    final canViewAttendance = rbacPerms.canViewAttendance;
    ref.invalidate(employeeProfileProvider);
    ref.invalidate(leadLimitProvider);

    // Run independent dashboard requests safely so that a failure or delay
    // in one section does not abort the entire dashboard loading flow.
    await Future.wait([
      // 1. Employee Profile
      ref.read(employeeProfileProvider.future).then((_) {}).catchError((e) {
        debugPrint('[EMPLOYEE_HOME] Profile load error: $e');
      }),

      // 2. Notifications
      ref.read(employeeNotificationProvider.notifier).loadNotifications(),

      // 3. Work Permissions
      ref
          .read(workPermissionsProvider.notifier)
          .loadPermissions()
          .catchError((e) {
            debugPrint('[EMPLOYEE_HOME] Work permissions load error: $e');
          }),

      // 4. RBAC Permissions
      ref
          .read(loginStateProvider.notifier)
          .refreshPermissions()
          .catchError((e) {
            debugPrint('[EMPLOYEE_HOME] RBAC permissions refresh error: $e');
          }),

      // 5. Lead Generation Quota
      ref.read(leadLimitProvider.future).then((_) {}).catchError((e) {
        debugPrint('[EMPLOYEE_HOME] Lead limit load error: $e');
      }),

      // 6. Attendance Status & Location
      if (canViewAttendance && !ref.read(employeeAttendanceProvider).isLoading)
        ref
            .read(employeeAttendanceProvider.notifier)
            .loadStatus()
            .catchError((e) {
              debugPrint('[EMPLOYEE_HOME] Attendance load error: $e');
            }),
      if (canViewAttendance)
        ref
            .read(employeeAttendanceProvider.notifier)
            .checkLocation(forceFresh: true)
            .catchError((e) {
              debugPrint('[EMPLOYEE_HOME] Location error: $e');
            }),
    ]);

    // The home screen can be left while these requests are still running.
    // Reading providers after dispose throws StateError.
    if (!mounted) return;

    // If attendance was not loaded because permissions were still arriving,
    // ensure attendance is loaded once permissions resolve.
    final finalRbac = ref.read(permissionManagerProvider);
    if (finalRbac.canViewAttendance &&
        !ref.read(employeeAttendanceProvider).isLoading &&
        ref.read(employeeAttendanceProvider).status.employee == null) {
      try {
        await ref.read(employeeAttendanceProvider.notifier).loadStatus();
      } catch (e) {
        debugPrint('[EMPLOYEE_HOME] Deferred attendance load error: $e');
      }
    }

    if (!mounted) return;
    refreshEmployeeCalendarProviders(ref);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(loginStateProvider);
    final attendanceState = ref.watch(employeeAttendanceProvider);
    final profileAsync = ref.watch(employeeProfileProvider);
    final profile = profileAsync.asData?.value;
    final rbacPerms = ref.watch(permissionManagerProvider);
    final canViewAttendance = rbacPerms.canViewAttendance;
    final canViewMyWork = rbacPerms.canViewMyWork;
    final canViewFollowUp = rbacPerms.canViewFollowUp;
    final canViewVisits = rbacPerms.canViewVisits;
    final canViewTasks = rbacPerms.canViewTasks;
    final canViewDashboard = rbacPerms.canViewDashboard;
    final canViewLeads = rbacPerms.canViewLeads;
    final canViewDataCapture = rbacPerms.canViewDataCapture;
    final empInfo = attendanceState.status.employee;
    final desigName =
        (profile?.designation ??
                empInfo?.designation ??
                authState.userRole ??
                '')
            .trim()
            .toUpperCase();
    final roleName = (rbacPerms.role ?? authState.userRole ?? '')
        .trim()
        .toUpperCase();
    final deptName = (profile?.department ?? empInfo?.department ?? '')
        .trim()
        .toUpperCase();
    final permsState = ref.watch(workPermissionsProvider);
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

    final canViewCalendar =
        !isBpoTeam && isProductionTeam && rbacPerms.canViewCalendar;

    final hasAnyPermittedWidget =
        isVisitor ||
        canViewDashboard ||
        canViewAttendance ||
        canViewCalendar ||
        canViewMyWork ||
        canViewFollowUp ||
        canViewVisits ||
        canViewTasks ||
        canViewLeads ||
        canViewDataCapture ||
        permsState.permissions.hasSsmWorkPermission ||
        permsState.permissions.workPermissions.isNotEmpty ||
        (authState.isLoggedIn &&
            (authState.role == UserRole.employee ||
                authState.userRole == 'EMPLOYEE'));

    final showBpoHomeSkeleton =
        isBpoTeam &&
        rbacPerms.permissions.isEmpty &&
        (rbacPerms.isLoading || !rbacPerms.isInitialized) &&
        rbacPerms.error == null;

    // Resolve REAL logged-in Employee Name from existing providers (profile, attendance, auth)
    String empName = '';
    if (profile != null &&
        profile.name.trim().isNotEmpty &&
        profile.name.trim().toLowerCase() != 'employee') {
      empName = profile.name.trim();
    } else if (empInfo != null &&
        empInfo.name.trim().isNotEmpty &&
        empInfo.name.trim().toLowerCase() != 'employee') {
      empName = empInfo.name.trim();
    } else if (authState.userName != null &&
        authState.userName!.trim().isNotEmpty &&
        authState.userName!.trim().toLowerCase() != 'employee') {
      empName = authState.userName!.trim();
    } else if (authState.userEmail != null &&
        authState.userEmail!.contains('@')) {
      final emailPrefix = authState.userEmail!.split('@').first;
      empName = emailPrefix.isNotEmpty
          ? '${emailPrefix[0].toUpperCase()}${emailPrefix.substring(1)}'
          : 'Employee';
    } else {
      empName = 'Employee';
    }

    final empCode = (profile != null && profile.employeeCode.isNotEmpty)
        ? profile.employeeCode
        : (empInfo?.employeeCode.isNotEmpty == true
              ? empInfo!.employeeCode
              : (authState.employeeCode?.isNotEmpty == true
                    ? authState.employeeCode!
                    : ''));

    // Today's Date String
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dateStr =
        '${weekDays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    final mediaQuery = MediaQuery.maybeOf(context);
    final devWidth = mediaQuery?.size.width ?? 0;
    final devHeight = mediaQuery?.size.height ?? 0;
    final devPixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    final devTimezone = DateTime.now().timeZoneName;

    // Concisely log state once or when permission count changes (avoids 1s tick spam)
    if (_lastLoggedPermissionCount != rbacPerms.permissions.length) {
      _lastLoggedPermissionCount = rbacPerms.permissions.length;
      debugPrint(
        '[CALENDAR_VISIBILITY_DEBUG] HomeView -> '
        'employeeCode: $empCode, '
        'role: $roleName, '
        'desig: $desigName, '
        'permissionsCount: ${rbacPerms.permissions.length}, '
        'canViewCalendar: $canViewCalendar, '
        'isVisitor: $isVisitor, '
        'deviceWidth: $devWidth, '
        'deviceHeight: $devHeight, '
        'pixelRatio: $devPixelRatio, '
        'timezone: $devTimezone',
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(
                  Remix.building_2_fill,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'QB Suite',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'EMPLOYEE WORKSPACE',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                      letterSpacing: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          AnimatedNotificationBell(
            dotColor: AppColors.error,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsView()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Remix.menu_line, color: AppColors.textPrimary),
            tooltip: 'Open Menu',
            onPressed:
                widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refreshAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 0. Welcome Greeting
              if (showBpoHomeSkeleton)
                _buildBpoGreetingSkeleton()
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            empName,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (empCode.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          empCode,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 14),

              if (_homeRefreshError != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _homeRefreshError!,
                          semanticsLabel: _homeRefreshError,
                        ),
                        TextButton.icon(
                          onPressed: _refreshAllData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry dashboard'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // State 1: Permission fetch error with 0 cached permissions
              if (rbacPerms.error != null && rbacPerms.permissions.isEmpty) ...[
                _buildErrorState(rbacPerms.error!),
              ]
              // Only permission initialization gates the whole workspace.
              // Each permitted section handles its own data loading/errors.
              else if (showBpoHomeSkeleton) ...[
                _buildBpoLoadingState(
                  showAttendance: true,
                  showQuota: !isProductionTeam,
                  showLeadPipeline: !isProductionTeam,
                  showFollowUps: !isProductionTeam,
                ),
              ]
              // State 2: Permissions still initializing / loading
              else if (!rbacPerms.isInitialized ||
                  (rbacPerms.isLoading && rbacPerms.permissions.isEmpty)) ...[
                _buildLoadingState(),
              ]
              // State 3: No workspace modules permitted
              else if (!hasAnyPermittedWidget) ...[
                _buildNoAccessFallback(),
              ]
              // State 4: Render permitted modules
              else ...[
                if (isVisitor) ...[
                  // 1. Shift/Attendance Card for Visitor (if permitted)
                  if (canViewAttendance) ...[
                    _buildAttendanceCard(context, attendanceState, dateStr),
                    const SizedBox(height: 16),
                  ],
                  // 2. Visitor Visit Overview (Summary Cards + Today's Visits)
                  VisitorHomeSection(
                    onNavigateToTab: (tab) => widget.onNavigateToTab?.call(tab),
                  ),
                  const SizedBox(height: 16),

                  // 3. Visitor Home Calendar Section (7-Day Strip & Scheduled Visits)
                  if (canViewCalendar) ...[
                    EmployeeHomeCalendarSection(
                      onViewAll: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EmployeeScheduleView(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ] else ...[
                  // 1. Attendance Card (Shift Status & Biometric-Gated Punch In/Out)
                  if (canViewAttendance ||
                      (authState.isLoggedIn &&
                          (authState.role == UserRole.employee ||
                              authState.userRole == 'EMPLOYEE'))) ...[
                    _buildAttendanceCard(context, attendanceState, dateStr),
                    const SizedBox(height: 16),
                  ],

                  // 2. Lead Generation Quota Card
                  if ((canViewLeads || canViewDataCapture) &&
                      isBpoTeam &&
                      !isProductionTeam) ...[
                    const LeadLimitCard(),
                    const SizedBox(height: 16),
                  ],

                  // 3. Lead Pipeline Card (Below Lead Quota)
                  if (canViewLeads && isBpoTeam && !isProductionTeam) ...[
                    _buildLeadPipelineCard(context),
                    const SizedBox(height: 16),
                  ],

                  // 4. Employee Home Calendar Section (7-Day Strip, Category Filters, Activities List)
                  if (canViewCalendar) ...[
                    EmployeeHomeCalendarSection(
                      onViewAll: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EmployeeScheduleView(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 5. Follow-ups Section
                  if (canViewFollowUp && !isProductionTeam) ...[
                    _buildFollowUpsCard(context),
                    const SizedBox(height: 16),
                  ],

                  // Assigned Tasks is no longer shown on the employee home.
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. LOADING, ERROR, & EMPTY ACCESS FALLBACK STATES
  // ===========================================================================
  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonAttendanceCard(),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: SkeletonStatCard()),
            SizedBox(width: 12),
            Expanded(child: SkeletonStatCard()),
          ],
        ),
        const SizedBox(height: 16),
        const SkeletonCalendarStrip(),
        const SizedBox(height: 16),
        const SkeletonCard(),
        const SkeletonCard(),
      ],
    );
  }

  Widget _buildBpoGreetingSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 118, height: 12),
                SizedBox(height: 7),
                SkeletonBox(width: 164, height: 20),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const SkeletonBox(width: 54, height: 11, borderRadius: 4),
          ),
        ],
      ),
    );
  }

  Widget _buildBpoLoadingState({
    required bool showAttendance,
    required bool showQuota,
    required bool showLeadPipeline,
    required bool showFollowUps,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAttendance) ...[
          _buildBpoAttendanceSkeleton(),
          const SizedBox(height: 16),
        ],
        if (showQuota) ...[
          _buildBpoQuotaSkeleton(),
          const SizedBox(height: 16),
        ],
        if (showLeadPipeline) ...[
          _buildBpoLeadPipelineSkeleton(),
          const SizedBox(height: 16),
        ],
        if (showFollowUps) const SkeletonCard(),
      ],
    );
  }

  Widget _buildBpoAttendanceSkeleton() {
    Widget metric() => const Expanded(
      child: Column(
        children: [
          SkeletonBox(width: 66, height: 11),
          SizedBox(height: 6),
          SkeletonBox(width: 54, height: 14),
        ],
      ),
    );

    return _bpoSkeletonCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 142, height: 16),
                    SizedBox(height: 6),
                    SkeletonBox(width: 112, height: 11),
                  ],
                ),
              ),
              const SkeletonBox(width: 92, height: 24, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.pillBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    metric(),
                    Container(width: 1, height: 38, color: AppColors.border),
                    metric(),
                  ],
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: AppColors.border),
                const SizedBox(height: 10),
                Row(
                  children: [
                    metric(),
                    Container(width: 1, height: 38, color: AppColors.border),
                    metric(),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const SkeletonCircle(size: 14),
              const SizedBox(width: 7),
              const Expanded(child: SkeletonBox(height: 11)),
              const SizedBox(width: 8),
              const SkeletonCircle(size: 26),
            ],
          ),
          const SizedBox(height: 14),
          const SkeletonBox(height: 48, borderRadius: 14),
        ],
      ),
    );
  }

  Widget _buildBpoQuotaSkeleton() {
    Widget periodCard() => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 58, height: 11),
            SizedBox(height: 7),
            SkeletonBox(width: 76, height: 17),
            SizedBox(height: 8),
            SkeletonBox(height: 5, borderRadius: 3),
          ],
        ),
      ),
    );

    return _bpoSkeletonCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              const SkeletonBox(width: 32, height: 32, borderRadius: 8),
              const SizedBox(width: 10),
              const Expanded(child: SkeletonBox(height: 14)),
              const SizedBox(width: 8),
              const SkeletonCircle(size: 26),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [periodCard(), const SizedBox(width: 10), periodCard()],
          ),
        ],
      ),
    );
  }

  Widget _buildBpoLeadPipelineSkeleton() {
    return _bpoSkeletonCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              const SkeletonBox(width: 40, height: 40, borderRadius: 12),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 104, height: 15),
                    SizedBox(height: 6),
                    SkeletonBox(width: 154, height: 11),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const SkeletonBox(height: 42, borderRadius: 10),
        ],
      ),
    );
  }

  Widget _bpoSkeletonCard({
    required EdgeInsetsGeometry padding,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Remix.error_warning_line,
              color: Colors.red,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Unable to load permissions',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () {
              _refreshAllData();
            },
            icon: const Icon(Remix.refresh_line, size: 16),
            label: Text(
              'Retry',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAccessFallback() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Remix.shield_keyhole_line,
              size: 28,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No workspace access configured',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your administrator has not assigned any Employee Mobile App modules to your account yet.\n\nPlease contact your administrator.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              _refreshAllData();
            },
            icon: const Icon(Remix.refresh_line, size: 16),
            label: Text(
              'Check Access / Refresh',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _showRbacDiagnosticsDialog(context),
            icon: const Icon(
              Remix.information_line,
              size: 15,
              color: AppColors.textSecondary,
            ),
            label: Text(
              'View Diagnostics',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textSecondary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRbacDiagnosticsDialog(BuildContext context) {
    final auth = ref.read(loginStateProvider);
    final perms = ref.read(permissionManagerProvider);
    final profile = ref.read(employeeProfileProvider).asData?.value;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Workspace RBAC Diagnostics',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDiagRow(
                'Employee ID',
                auth.employeeId ?? profile?.id.toString() ?? 'N/A',
              ),
              _buildDiagRow(
                'Employee Code',
                auth.employeeCode ?? profile?.employeeCode ?? 'N/A',
              ),
              _buildDiagRow(
                'Designation ID',
                profile?.designationId?.toString() ?? 'N/A',
              ),
              _buildDiagRow(
                'Designation',
                profile?.designation ?? perms.role ?? 'N/A',
              ),
              _buildDiagRow('Company/Tenant ID', auth.customerId ?? 'N/A'),
              _buildDiagRow(
                'Permission API Status',
                perms.error != null
                    ? 'Error: ${perms.error}'
                    : (perms.isInitialized ? 'Loaded (200 OK)' : 'Loading...'),
              ),
              _buildDiagRow(
                'Permission Count',
                perms.permissions.length.toString(),
              ),
              _buildDiagRow(
                'Manager Initialized',
                perms.isInitialized.toString(),
              ),
              _buildDiagRow(
                'Cache Timestamp',
                perms.lastFetchedAt?.toLocal().toString() ?? 'Not fetched yet',
              ),
              const SizedBox(height: 8),
              Text(
                'Permission Keys (${perms.permissions.length}):',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  perms.permissions.isEmpty
                      ? 'None'
                      : perms.permissions
                            .map((p) => '${p.module}:${p.action}')
                            .join(', '),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(loginStateProvider.notifier).refreshPermissions();
            },
            child: const Text('Refresh Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MY WORK CARD
  // ===========================================================================

  // ===========================================================================
  // LEAD PIPELINE CARD
  // ===========================================================================
  Widget _buildLeadPipelineCard(BuildContext context) {
    return Container(
      key: const ValueKey('home_lead_pipeline_card'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Remix.user_search_line,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lead Pipeline',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Manage & track your leads',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('btn_view_all_leads'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    if (widget.onNavigateToTab != null) {
                      widget.onNavigateToTab!('Leads');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LeadsView()),
                      );
                    }
                  },
                  icon: const Icon(
                    Remix.user_add_line,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    'View All Leads',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // FOLLOW-UPS CARD
  // ===========================================================================
  Widget _buildFollowUpsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Remix.phone_line,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Follow-ups',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "Manage and track today's follow-ups",
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. ATTENDANCE CARD
  // ===========================================================================
  Widget _buildAttendanceCard(
    BuildContext context,
    AttendanceState state,
    String dateStr,
  ) {
    final isWorking =
        state.isPunchedIn && !state.isOnBreak && !state.isCompleted;
    final isOnBreak = state.isOnBreak;
    final isCompleted = state.isCompleted;

    // Status Badge config
    Color badgeBg;
    Color badgeText;
    Color badgeDot;
    String statusLabel;

    if (isWorking) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF166534);
      badgeDot = AppColors.primary;
      statusLabel = 'Working';
    } else if (isOnBreak) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFF92400E);
      badgeDot = AppColors.warning;
      statusLabel = 'On Break';
    } else if (isCompleted) {
      badgeBg = const Color(0xFFE2E8F0);
      badgeText = const Color(0xFF334155);
      badgeDot = const Color(0xFF64748B);
      statusLabel = 'Completed';
    } else {
      badgeBg = const Color(0xFFF1F5F9);
      badgeText = const Color(0xFF64748B);
      badgeDot = const Color(0xFF94A3B8);
      statusLabel = 'Not Checked In';
    }

    final officeName = state.status.assignedOffice?.name ?? 'Head Office';
    final distMeters = state.distanceToOfficeMeters;
    final isInside = state.isInsideOfficeRadius;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title, Date & Live Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Attendance",
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: badgeDot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2x2 Key Metrics Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.pillBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                // Metric 1: Check In
                Expanded(
                  child: _buildAttendanceMetricItem(
                    icon: Remix.login_circle_line,
                    iconColor: AppColors.primary,
                    label: 'Check In',
                    value: state.punchInTimeFormatted,
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.border),
                // Metric 2: Check Out
                Expanded(
                  child: _buildAttendanceMetricItem(
                    icon: Remix.logout_circle_r_line,
                    iconColor: const Color(0xFFEF4444),
                    label: 'Check Out',
                    value: state.punchOutTimeFormatted,
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.border),
                // Metric 3: Working Hours
                Expanded(
                  child: _buildAttendanceMetricItem(
                    icon: Remix.time_line,
                    iconColor: const Color(0xFF3B82F6),
                    label: 'Working Hours',
                    value: state.workingHoursFormatted,
                    isHighlight: isWorking,
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.border),
                // Metric 4: Break Taken
                Expanded(
                  child: _buildAttendanceMetricItem(
                    icon: Remix.cup_line,
                    iconColor: AppColors.warning,
                    label: 'Break Taken',
                    value: state.breakDurationFormatted,
                    isHighlight: isOnBreak,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Geofence & Location Info Line
          Row(
            children: [
              Icon(
                Remix.map_pin_2_line,
                size: 14,
                color: state.isRemoteWork
                    ? AppColors.purple
                    : (isInside ? AppColors.primary : AppColors.textSecondary),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  state.isRemoteWork
                      ? 'Approved Remote Work Mode'
                      : '$officeName • ${distMeters != null ? (isInside ? "Inside Office (${distMeters.round()}m)" : "Outside Radius (${distMeters.round()}m)") : "GPS Locating..."}',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: state.isRemoteWork
                        ? AppColors.purple
                        : (isInside
                              ? AppColors.primaryDark
                              : AppColors.textSecondary),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => ref
                    .read(employeeAttendanceProvider.notifier)
                    .checkLocation(forceFresh: true),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.isLocating
                            ? Remix.loader_4_line
                            : Remix.refresh_line,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Refresh GPS',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Dynamic Attendance Action Button (Punch In / Punch Out / Break / Completed)
          _buildAttendanceActionButtons(context, state),
          const OvertimeHomeButton(),
        ],
      ),
    );
  }

  /// Dynamic Attendance Action Buttons strictly driven by current backend state
  Widget _buildAttendanceActionButtons(
    BuildContext context,
    AttendanceState state,
  ) {
    // 1. Initial API Loading state
    if (state.isLoading &&
        state.status.status.punchInTime == null &&
        !state.status.status.isPunchedIn) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF1F5F9),
            disabledBackgroundColor: const Color(0xFFF1F5F9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Checking attendance...',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Action currently running (Biometric verification, GPS resolving, API call)
    if (state.isActionRunning) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryLight,
            disabledBackgroundColor: AppColors.primaryLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                state.actionFeedback ?? 'Processing...',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Shift Completed (both check-in and check-out exist)
    if (state.isCompleted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Remix.checkbox_circle_fill,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Attendance Completed',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
              ),
            ),
          ],
        ),
      );
    }

    // 4. On Break state
    if (state.isOnBreak) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _handleEndBreak(context),
                icon: const Icon(
                  Remix.play_circle_line,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  'End Break',
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  AppToast.info(
                    context,
                    'Please end your break before punching out.',
                  );
                },
                icon: const Icon(
                  Remix.logout_box_r_line,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  'PUNCH OUT',
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF94A3B8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 5. Punched In / Working state
    if (state.isPunchedIn) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _handleStartBreak(context),
                icon: const Icon(
                  Remix.cup_line,
                  size: 18,
                  color: AppColors.warning,
                ),
                label: Text(
                  'Start Break',
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.warning, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showPunchOutConfirmationDialog(context),
                icon: const Icon(
                  Remix.logout_box_r_line,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  'PUNCH OUT',
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 6. Not Checked In -> Show PUNCH IN
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () => _handlePunchIn(context),
        icon: const Icon(Remix.fingerprint_line, size: 20, color: Colors.white),
        label: Text(
          'PUNCH IN',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  /// Handler for Punch In with validation and feedback
  Future<void> _handlePunchIn(BuildContext context) async {
    final success = await ref
        .read(employeeAttendanceProvider.notifier)
        .punchIn();
    if (!context.mounted) return;
    if (success) {
      AppToast.success(context, 'Punched in successfully! Have a great shift.');
    } else {
      final err =
          ref.read(employeeAttendanceProvider).actionError ??
          ref.read(employeeAttendanceProvider).errorMessage;
      if (err != null && err.isNotEmpty) {
        AppToast.error(context, err);
      }
    }
  }

  /// Handler for Start Break
  Future<void> _handleStartBreak(BuildContext context) async {
    final success = await ref
        .read(employeeAttendanceProvider.notifier)
        .startBreak();
    if (!context.mounted) return;
    if (success) {
      AppToast.success(context, 'Break started.');
    } else {
      final err =
          ref.read(employeeAttendanceProvider).actionError ??
          ref.read(employeeAttendanceProvider).errorMessage;
      if (err != null && err.isNotEmpty) {
        AppToast.error(context, err);
      }
    }
  }

  /// Handler for End Break
  Future<void> _handleEndBreak(BuildContext context) async {
    final success = await ref
        .read(employeeAttendanceProvider.notifier)
        .endBreak();
    if (!context.mounted) return;
    if (success) {
      AppToast.success(context, 'Break ended. Welcome back!');
    } else {
      final err =
          ref.read(employeeAttendanceProvider).actionError ??
          ref.read(employeeAttendanceProvider).errorMessage;
      if (err != null && err.isNotEmpty) {
        AppToast.error(context, err);
      }
    }
  }

  /// Punch Out confirmation bottom sheet before calling punchOut
  Future<void> _showPunchOutConfirmationDialog(BuildContext context) async {
    final shouldPunchOut = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Remix.logout_box_r_line,
                        color: Color(0xFFEF4444),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confirm Punch Out',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Finalize your attendance for today',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Are you sure you want to punch out? This will finalize your shift and record your check-out timestamp.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(modalCtx, false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(modalCtx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Yes, Punch Out',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldPunchOut == true && context.mounted) {
      final success = await ref
          .read(employeeAttendanceProvider.notifier)
          .punchOut();
      if (!context.mounted) return;
      if (success) {
        AppToast.success(context, 'Punched out successfully. Shift completed!');
      } else {
        final err =
            ref.read(employeeAttendanceProvider).actionError ??
            ref.read(employeeAttendanceProvider).errorMessage;
        if (err != null && err.isNotEmpty) {
          AppToast.error(context, err);
        }
      }
    }
  }

  Widget _buildAttendanceMetricItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isHighlight ? AppColors.primary : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

typedef HomeView = EmployeeHomeView;
