import 'package:quickboom_company_admin/roles/company_admin/views/customers/admin_customers_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';

import 'package:quickboom_crm_customer/core/constants/constants.dart';
import 'package:quickboom_crm_customer/core/providers.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/models/permission_model.dart';
import 'package:quickboom_crm_customer/core/services/crm_access.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_attendance_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_profile_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/views/requests_view.dart';
import 'package:quickboom_crm_customer/roles/employee/views/salary_slip_view.dart';
import 'package:quickboom_crm_customer/roles/employee/views/commission_view.dart';
import 'package:quickboom_crm_customer/roles/employee/views/settings_view.dart';
import 'package:quickboom_crm_customer/roles/employee/views/sidebar_views/attendance_view.dart';

import 'package:quickboom_crm_customer/roles/employee/views/sidebar_views/packages_view.dart';
import 'package:quickboom_crm_customer/roles/employee/views/visits_view.dart';
import 'package:quickboom_crm_customer/roles/employee/views/dashboard_view.dart';

import 'package:quickboom_crm_customer/shared/views/data_capture/data_capture_home_screen.dart';
import 'package:quickboom_crm_customer/shared/views/leads/leads_view.dart';
import 'package:quickboom_crm_customer/shared/widgets/permission_guarded_view.dart';

/// Standardized Employee Drawer for QuikBoom Mobile CRM.
///
/// NOTE: Primary Bottom Navigation tabs: (Home, Data, Leads, Clients, Profile).
/// Sidebar contains dedicated CRM Workflow and complete HRM / Employee modules.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  void _handleLogout(BuildContext context, WidgetRef ref) {
    bool isLoggingOut = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Remix.logout_box_r_line,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Sign Out',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to end your current session and sign out?',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            if (!isLoggingOut)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.outfit(color: AppColors.textSecondary),
                ),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isLoggingOut
                  ? null
                  : () async {
                      setDialogState(() => isLoggingOut = true);
                      debugPrint(
                        '[AUTH_DEBUG] logoutReason: User clicked Employee Logout',
                      );
                      if (ctx.mounted && Navigator.canPop(ctx)) {
                        Navigator.pop(ctx);
                      }
                      await ref.read(loginStateProvider.notifier).logout();
                    },
              child: isLoggingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Logout',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(
    BuildContext context,
    WidgetRef ref,
    SidebarItem item,
    Widget targetScreen,
  ) {
    final currentSelection = ref.read(sidebarSelectionProvider);
    // Update selected item in provider
    ref.read(sidebarSelectionProvider.notifier).select(item);
    // Close Drawer first
    Navigator.pop(context);

    if (currentSelection == item) {
      // Already on this screen
      return;
    }

    if (item == SidebarItem.dashboard) {
      if (Navigator.canPop(context)) {
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardView()),
        );
      }
      return;
    }

    final module = _moduleForItem(item);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => module == null
            ? targetScreen
            : PermissionGuardedView(
                moduleKey: module,
                moduleTitle: item.name,
                child: targetScreen,
              ),
      ),
    );
  }

  String? _moduleForItem(SidebarItem item) => switch (item) {
    SidebarItem.dataCapture => AppModule.dataCapture,
    SidebarItem.leads => AppModule.leads,
    SidebarItem.customers => AppModule.customers,
    SidebarItem.attendance => AppModule.attendance,
    SidebarItem.requests || SidebarItem.leaves => AppModule.leave,
    SidebarItem.expenses => AppModule.expenses,
    SidebarItem.loans => AppModule.loan,
    SidebarItem.remoteWork => AppModule.remoteWork,
    SidebarItem.tasks => AppModule.tasks,
    SidebarItem.salarySlips => AppModule.salary,
    SidebarItem.commissions => AppModule.commission,
    SidebarItem.visits || SidebarItem.visitsHrm => AppModule.visits,
    SidebarItem.settings => AppModule.settings,
    SidebarItem.packages => AppModule.packages,
    _ => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSelection = ref.watch(sidebarSelectionProvider);
    final rbacPerms = ref.watch(permissionManagerProvider);
    final profile = ref.watch(employeeProfileProvider).asData?.value;
    final crmCategory = classifyCrmEmployee(
      department: profile?.department,
      designation: profile?.designation,
      role: rbacPerms.role,
      backendCategory: rbacPerms.crmCategory,
    );
    final isBpoEmployee = crmCategory == CrmEmployeeCategory.bpo;
    final isSalesEmployee = crmCategory == CrmEmployeeCategory.sales;
    final isVisitorEmployee = crmCategory == CrmEmployeeCategory.visitor;

    final hasLeadsAccess = isBpoEmployee || isSalesEmployee || rbacPerms.canViewLeads;
    final hasCustomersAccess = isBpoEmployee;
    final hasPackagesAccess = rbacPerms.canViewPackages;
    final hasAttendanceAccess = rbacPerms.canViewAttendance;
    final hasLeaveAccess = rbacPerms.canViewLeave;
    final hasLoanAccess = rbacPerms.canViewLoan;
    final hasSalaryAccess = rbacPerms.canViewSalary;
    final hasCommissionAccess = rbacPerms.canViewCommission;
    final hasVisitsAccess = isVisitorEmployee;
    final hasSettingsAccess = rbacPerms.canView(AppModule.settings);
    final hasDataCaptureAccess = isBpoEmployee;
    final hasDashboardAccess = rbacPerms.canViewDashboard;
    final hasCrmAccess =
        (hasDataCaptureAccess || hasLeadsAccess || hasCustomersAccess);
    final hasAnyHrm =
        hasAttendanceAccess ||
        hasLeaveAccess ||
        hasLoanAccess ||
        hasSalaryAccess ||
        hasVisitsAccess ||
        hasCommissionAccess;
    // Only count modules that actually have a rendered menu entry.
    final hasWorkflowItems = hasPackagesAccess;

    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = (screenWidth * 0.84).clamp(270.0, 350.0);

    return SizedBox(
      width: drawerWidth,
      child: Drawer(
        backgroundColor: Colors.white,
        elevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // 1. Sidebar Header (Employee Profile & QuikBoom Branding)
              _buildDrawerHeader(context, ref),

              // 2. Navigation Items List
              Expanded(
                child: ListView(
                  key: const PageStorageKey('employee-sidebar-menu'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // 1. PRIMARY STANDALONE DASHBOARD (Directly below profile header, independent of CRM)
                    if (hasDashboardAccess) ...[
                      _buildDrawerItem(
                        context: context,
                        ref: ref,
                        icon: Remix.home_5_line,
                        title: 'Dashboard',
                        item: SidebarItem.dashboard,
                        isSelected: currentSelection == SidebarItem.dashboard,
                        targetScreen: const DashboardView(),
                      ),
                      if (hasCrmAccess ||
                          hasWorkflowItems ||
                          hasAnyHrm ||
                          hasSettingsAccess) ...[
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: AppColors.borderLight),
                        const SizedBox(height: 16),
                      ],
                    ],

                    // 2. CRM: backend eligibility plus effective module permissions.
                    if (hasCrmAccess) ...[
                      _buildSectionHeader('CRM'),
                      if (hasDataCaptureAccess)
                        _buildDrawerItem(
                          context: context,
                          ref: ref,
                          icon: Remix.add_circle_line,
                          title: 'Data Capture',
                          item: SidebarItem.dataCapture,
                          isSelected:
                              currentSelection == SidebarItem.dataCapture,
                          targetScreen: const DataCaptureHomeScreen(),
                        ),
                      if (hasLeadsAccess)
                        _buildDrawerItem(
                          context: context,
                          ref: ref,
                          icon: Remix.user_search_line,
                          title: 'Leads',
                          item: SidebarItem.leads,
                          isSelected: currentSelection == SidebarItem.leads,
                          targetScreen: const LeadsView(),
                        ),
                      if (hasCustomersAccess)
                        _buildDrawerItem(
                          context: context,
                          ref: ref,
                          icon: Remix.building_2_line,
                          title: 'Customers',
                          item: SidebarItem.customers,
                          isSelected: currentSelection == SidebarItem.customers,
                          targetScreen: const AdminCustomersView(),
                        ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.borderLight),
                      const SizedBox(height: 16),
                    ],

                    // CRM WORKFLOW SECTION (Only for roles with CRM workflow permissions)
                    if (hasWorkflowItems) ...[
                      _buildSectionHeader('CRM WORKFLOW'),

                      if (hasPackagesAccess)
                        _buildDrawerItem(
                          context: context,
                          ref: ref,
                          icon: Remix.price_tag_3_line,
                          title: 'Packages',
                          item: SidebarItem.packages,
                          isSelected: currentSelection == SidebarItem.packages,
                          targetScreen: const PackagesView(),
                        ),

                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.borderLight),
                      const SizedBox(height: 16),
                    ],

                    // HRM / EMPLOYEE SUITE SECTION
                    if (hasAnyHrm) ...[
                      _buildSectionHeader('HRM & WORKPLACE'),
                      if (hasAttendanceAccess)
                        _buildDrawerItem(
                          context: context,
                          ref: ref,
                          icon: Remix.fingerprint_line,
                          title: 'Attendance',
                          item: SidebarItem.attendance,
                          isSelected:
                              currentSelection == SidebarItem.attendance,
                          targetScreen: const AttendanceView(),
                        ),
                      if (hasLeaveAccess)
                        _buildDrawerItem(
                          context: context,
                          ref: ref,
                          icon: Remix.calendar_check_line,
                          title: 'Requests & Leaves',
                          item: SidebarItem.requests,
                          isSelected:
                              currentSelection == SidebarItem.requests ||
                              currentSelection == SidebarItem.leaves,
                          targetScreen: const RequestsView(
                            initialTabIndex: 0,
                            initialTabType: 'leaves',
                          ),
                        ),
                      if (hasLoanAccess)
                        _buildDrawerItem(
                          context: context,
                          ref: ref,
                          icon: Remix.bank_line,
                          title: 'Loan Requests',
                          item: SidebarItem.loans,
                          isSelected: currentSelection == SidebarItem.loans,
                          targetScreen: const RequestsView(
                            initialTabIndex: 2,
                            initialTabType: 'loans',
                          ),
                        ),
                      if (hasSalaryAccess)
                        _buildDrawerItem(
                          context: context,
                          ref: ref,
                          icon: Remix.file_paper_2_line,
                          title: 'Salary Slips',
                          item: SidebarItem.salarySlips,
                          isSelected:
                              currentSelection == SidebarItem.salarySlips,
                          targetScreen: const SalarySlipView(),
                        ),
                      if (hasVisitsAccess)
                        _buildDrawerItem(
                          context: context,
                          ref: ref,
                          icon: Remix.map_pin_2_line,
                          title: 'Field Visits',
                          item: SidebarItem.visitsHrm,
                          isSelected:
                              currentSelection == SidebarItem.visitsHrm ||
                              currentSelection == SidebarItem.visits,
                          targetScreen: const VisitsView(),
                        ),
                      if (hasCommissionAccess)
                        _buildDrawerItem(
                          context: context,
                          ref: ref,
                          icon: Remix.coins_line,
                          title: 'My Commissions',
                          item: SidebarItem.commissions,
                          isSelected:
                              currentSelection == SidebarItem.commissions,
                          targetScreen: const EmployeeCommissionView(),
                        ),
                      const SizedBox(height: 16),
                      if (hasSettingsAccess) ...[
                        const Divider(height: 1, color: AppColors.borderLight),
                        const SizedBox(height: 16),
                      ],
                    ],

                    // SYSTEM SECTION
                    if (hasSettingsAccess) ...[
                      _buildSectionHeader('SYSTEM'),
                      _buildDrawerItem(
                        context: context,
                        ref: ref,
                        icon: Remix.settings_3_line,
                        title: 'Settings',
                        item: SidebarItem.settings,
                        isSelected: currentSelection == SidebarItem.settings,
                        targetScreen: const SettingsView(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),

              // 3. Logout Section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: InkWell(
                  onTap: () => _handleLogout(context, ref),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Remix.logout_box_r_line,
                          size: 20,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Remix.arrow_right_s_line,
                          size: 16,
                          color: AppColors.error,
                        ),
                      ],
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

  Widget _buildDrawerHeader(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(loginStateProvider);
    final attendanceState = ref.watch(employeeAttendanceProvider);
    final profile = ref.watch(employeeProfileProvider).asData?.value;
    final empInfo = attendanceState.status.employee;

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

    final empCode =
        (profile != null &&
            profile.employeeCode.isNotEmpty &&
            profile.employeeCode != 'EMP-001')
        ? profile.employeeCode
        : (empInfo?.employeeCode.isNotEmpty == true
              ? empInfo!.employeeCode
              : (authState.employeeCode?.isNotEmpty == true
                    ? authState.employeeCode!
                    : ''));

    final designation =
        (profile != null &&
            profile.designation.isNotEmpty &&
            profile.designation.toLowerCase() != 'staff')
        ? profile.designation
        : (empInfo?.designation.isNotEmpty == true
              ? empInfo!.designation
              : (authState.userRole?.isNotEmpty == true
                    ? authState.userRole!
                    : 'Staff'));

    final status = (profile != null && profile.status.isNotEmpty)
        ? profile.status
        : 'ACTIVE';

    final profilePhoto = profile?.profilePhoto ?? empInfo?.profilePhoto;

    final initials = empName
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .take(2)
        .join('')
        .toUpperCase();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 16,
        16,
        16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(topRight: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset('assets/images/app_logo.png', width: 44, height: 44, fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QB Suite Customer',
                    style: GoogleFonts.outfit(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'BUSINESS SUITE',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage:
                      (profilePhoto != null && profilePhoto.isNotEmpty)
                      ? NetworkImage(profilePhoto)
                      : null,
                  child: (profilePhoto == null || profilePhoto.isEmpty)
                      ? Text(
                          initials.isNotEmpty ? initials : 'EM',
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        empName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          if (empCode.isNotEmpty)
                            Flexible(
                              child: Text(
                                empCode,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (empCode.isNotEmpty &&
                              designation.isNotEmpty &&
                              designation.toLowerCase() != 'staff')
                            Text(
                              ' • ',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          if (designation.isNotEmpty &&
                              designation.toLowerCase() != 'staff')
                            Flexible(
                              child: Text(
                                designation,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary.withValues(alpha: 0.8),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String title,
    required SidebarItem item,
    required bool isSelected,
    required Widget targetScreen,
    String? badge,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateTo(context, ref, item, targetScreen),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  Remix.arrow_right_s_line,
                  size: 16,
                  color: isSelected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
