import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/core/models/permission_model.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import '../models/employee_payroll_model.dart';
import '../viewmodels/employee_attendance_viewmodel.dart';
import '../viewmodels/employee_payroll_viewmodel.dart';
import '../viewmodels/employee_profile_viewmodel.dart';
import 'edit_profile_view.dart';
import 'requests_view.dart';
import 'salary_slip_view.dart';
import 'salary_summary_view.dart';
import 'team_attendance_leaves_view.dart';
import 'commission_view.dart';
import 'settings_view.dart';
import 'sidebar_views/attendance_view.dart';

import 'package:quickboom_crm_customer/shared/widgets/permission_guarded_view.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';

class ProfileView extends ConsumerWidget {
  final Function(int)? onNavigateToTab;

  const ProfileView({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(loginStateProvider);
    final attendanceState = ref.watch(employeeAttendanceProvider);
    final profileAsync = ref.watch(employeeProfileProvider);
    final profileData = profileAsync.asData?.value;
    final empInfo = attendanceState.status.employee;

    String empName = '';
    if (profileData != null &&
        profileData.name.trim().isNotEmpty &&
        profileData.name.trim().toLowerCase() != 'employee') {
      empName = profileData.name.trim();
    } else if (empInfo != null &&
        empInfo.name.trim().isNotEmpty &&
        empInfo.name.trim().toLowerCase() != 'employee') {
      empName = empInfo.name.trim();
    } else if (authState.userName != null &&
        authState.userName!.trim().isNotEmpty) {
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

    final designation =
        (profileData != null &&
            profileData.designation.isNotEmpty &&
            profileData.designation.toLowerCase() != 'staff')
        ? profileData.designation
        : (empInfo?.designation.isNotEmpty == true
              ? empInfo!.designation
              : (authState.userRole?.isNotEmpty == true
                    ? authState.userRole!
                    : 'Staff'));

    final department =
        (profileData != null &&
            profileData.department.isNotEmpty &&
            profileData.department.toLowerCase() != 'general')
        ? profileData.department
        : (empInfo?.department.isNotEmpty == true
              ? empInfo!.department
              : 'General');

    final empCode =
        (profileData != null &&
            profileData.employeeCode.isNotEmpty &&
            profileData.employeeCode != 'EMP-001')
        ? profileData.employeeCode
        : (empInfo?.employeeCode.isNotEmpty == true
              ? empInfo!.employeeCode
              : (authState.employeeCode?.isNotEmpty == true
                    ? authState.employeeCode!
                    : 'EMP-001'));

    final email = (profileData != null && profileData.email.isNotEmpty)
        ? profileData.email
        : (empInfo?.email.isNotEmpty == true
              ? empInfo!.email
              : (authState.userEmail ?? 'employee@quikboom.com'));

    final officeName = (profileData != null && profileData.branch.isNotEmpty)
        ? profileData.branch
        : (attendanceState.status.assignedOffice?.name ?? 'Head Office');

    final profilePhoto = profileData?.profilePhoto ?? empInfo?.profilePhoto;

    final initials = empName
        .split(' ')
        .map((p) => p.isNotEmpty ? p[0] : '')
        .take(2)
        .join('')
        .toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text("My Profile")),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              // Employee Profile Card
              _buildProfileHeaderCard(
                context,
                empName,
                designation,
                empCode,
                email,
                department,
                officeName,
                initials,
                profilePhoto,
              ),
              const SizedBox(height: 20),

              // Navigation & Shortcut Menu Section
              _buildMenuSection(context, ref),
              const SizedBox(height: 20),

              // Salary Slips Download Section
              _buildPayrollSection(context, ref),
              const SizedBox(height: 24),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _handleLogout(context, ref),
                  icon: const Icon(
                    Remix.logout_box_r_line,
                    color: AppColors.error,
                    size: 20,
                  ),
                  label: Text(
                    'Sign Out Account',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'QB Suite Employee Mobile v1.0.0',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    bool isLoggingOut = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Sign Out',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to end your current session?',
            style: GoogleFonts.outfit(),
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
              onPressed: isLoggingOut
                  ? null
                  : () async {
                      setDialogState(() => isLoggingOut = true);
                      if (ctx.mounted && Navigator.canPop(ctx)) {
                        Navigator.pop(ctx);
                      }
                      await ref.read(loginStateProvider.notifier).logout();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: isLoggingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard(
    BuildContext context,
    String name,
    String designation,
    String empCode,
    String email,
    String department,
    String branch,
    String initials,
    String? profilePhoto,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar + Edit button row
          Stack(
            alignment: Alignment.topRight,
            children: [
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF1AA14D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: ClipOval(
                    child:
                        (profilePhoto != null && profilePhoto.trim().isNotEmpty)
                        ? Image.network(
                            profilePhoto,
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                                  child: Text(
                                    initials.isNotEmpty ? initials : 'EM',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 26,
                                    ),
                                  ),
                                ),
                          )
                        : Center(
                            child: Text(
                              initials.isNotEmpty ? initials : 'EM',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 26,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              // Edit profile chip
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileView()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Remix.pencil_line,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Employee Name
          Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          // Designation badge & Employee code pill
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  designation,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  empCode,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          _buildProfileDetailRow(
            Remix.briefcase_line,
            'Designation',
            designation,
          ),
          const SizedBox(height: 10),
          _buildProfileDetailRow(Remix.building_line, 'Department', department),
          const SizedBox(height: 10),
          _buildProfileDetailRow(Remix.id_card_line, 'Employee Code', empCode),
          const SizedBox(height: 10),
          _buildProfileDetailRow(
            Remix.map_pin_2_line,
            'Assigned Branch',
            branch,
          ),
          const SizedBox(height: 10),
          _buildProfileDetailRow(Remix.mail_line, 'Email', email),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppColors.textSecondary,
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
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionManagerProvider);
    final canViewAttendance = perms.canView(AppModule.attendance);

    final canViewLeave = perms.canView(AppModule.leave);
    final canViewSalary = perms.canView(AppModule.salary);
    final canViewSettings = perms.canView(AppModule.settings);

    // Build only the tiles the user is permitted to see
    final List<Widget> tiles = [];

    // Edit Profile — always available (universal)
    tiles.add(
      _buildMenuTile(
        icon: Remix.pencil_line,
        title: 'Edit Profile',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EditProfileView()),
        ),
      ),
    );

    // Attendance — gated
    if (canViewAttendance) {
      tiles.add(const Divider(height: 1));
      tiles.add(
        _buildMenuTile(
          icon: Remix.fingerprint_line,
          title: 'My Attendance Logs',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AttendanceView()),
          ),
        ),
      );
    }

    // Leave & Remote — gated
    if (canViewLeave) {
      tiles.add(const Divider(height: 1));
      tiles.add(
        _buildMenuTile(
          icon: Remix.calendar_check_line,
          title: 'Leave & Remote Applications',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PermissionGuardedView(
                moduleKey: AppModule.leave,
                moduleTitle: 'Requests & Leaves',
                child: RequestsView(),
              ),
            ),
          ),
        ),
      );
    }

    // Salary Slips — gated
    if (canViewSalary) {
      tiles.add(const Divider(height: 1));
      tiles.add(
        _buildMenuTile(
          icon: Remix.receipt_line,
          title: 'Salary Slips & Payslips',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PermissionGuardedView(
                moduleKey: AppModule.salary,
                moduleTitle: 'Salary Slips',
                child: SalarySlipView(),
              ),
            ),
          ),
        ),
      );
      tiles.add(const Divider(height: 1));
      tiles.add(
        _buildMenuTile(
          icon: Remix.file_chart_line,
          title: 'Monthly Salary Summary',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SalarySummaryView(),
            ),
          ),
        ),
      );
    }

    // Team Attendance & Leaves — for team managers
    if (canViewAttendance) {
      tiles.add(const Divider(height: 1));
      tiles.add(
        _buildMenuTile(
          icon: Remix.team_line,
          title: 'Team Attendance & Leaves',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TeamAttendanceLeavesView(),
            ),
          ),
        ),
      );
    }

    // Commission — gated
    final canViewCommission = perms.canViewCommission;
    if (canViewCommission) {
      tiles.add(const Divider(height: 1));
      tiles.add(
        _buildMenuTile(
          icon: Remix.coins_line,
          title: 'My Commissions',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PermissionGuardedView(
                moduleKey: AppModule.commission,
                moduleTitle: 'My Commissions',
                child: EmployeeCommissionView(),
              ),
            ),
          ),
        ),
      );
    }

    // Account Settings — gated
    if (canViewSettings) {
      tiles.add(const Divider(height: 1));
      tiles.add(
        _buildMenuTile(
          icon: Remix.settings_3_line,
          title: 'Account Settings',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsView()),
          ),
        ),
      );
    }

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: tiles),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(
        Remix.arrow_right_s_line,
        size: 18,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }

  Widget _buildPayrollSection(BuildContext context, WidgetRef ref) {
    final canViewSalary = ref
        .watch(permissionManagerProvider)
        .canView(AppModule.salary);
    if (!canViewSalary) return const SizedBox.shrink();

    final payrollState = ref.watch(employeePayrollProvider);

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Payslips',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (!payrollState.isLoading && payrollState.slips.isNotEmpty)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SalarySlipView()),
                    ),
                    child: Text(
                      'View All',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (payrollState.isLoading) ...[
              _buildShimmerTile(),
              const Divider(height: 1),
              _buildShimmerTile(),
            ] else if (payrollState.errorMessage != null &&
                payrollState.slips.isEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Remix.error_warning_line,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unable to load payslips',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(employeePayrollProvider.notifier)
                        .loadSalarySlips(),
                    child: Text(
                      'Retry',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (payrollState.slips.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Remix.receipt_line,
                      size: 32,
                      color: AppColors.textPlaceholder,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No payslips available yet.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your generated payslips will appear here.',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: AppColors.textPlaceholder,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              for (int i = 0; i < payrollState.slips.take(2).length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _buildRealPayslipTile(context, payrollState.slips[i]),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SkeletonBox(width: 40, height: 40, borderRadius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 120, height: 14, borderRadius: 4),
                SizedBox(height: 6),
                SkeletonBox(width: 180, height: 11, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SkeletonBox(width: 24, height: 24, borderRadius: 6),
        ],
      ),
    );
  }

  String _formatPaidDate(String rawDate) {
    if (rawDate.isEmpty) return 'Recent';
    try {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        const months = [
          '',
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
        final day = parsed.day.toString().padLeft(2, '0');
        final month = months[parsed.month];
        return '$day $month';
      }
    } catch (_) {}
    return rawDate;
  }

  Widget _buildRealPayslipTile(BuildContext context, SalarySlipItem slip) {
    final paidDateText = _formatPaidDate(slip.date);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SalarySlipView()),
      ),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Remix.receipt_line,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        slip.month,
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        '₹ ${slip.netSalary.toStringAsFixed(0)} Net • Paid on $paidDateText',
        style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(
          Remix.download_2_line,
          color: AppColors.primary,
          size: 20,
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SalarySlipView()),
        ),
      ),
    );
  }
}
