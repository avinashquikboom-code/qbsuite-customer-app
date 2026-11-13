import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/constants/constants.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_attendance_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_profile_viewmodel.dart';

class Sidebar extends ConsumerWidget {
  final SidebarItem currentSelection;
  final Function(SidebarItem) onItemSelected;
  final VoidCallback onLogout;

  const Sidebar({
    super.key,
    required this.currentSelection,
    required this.onItemSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final profilePhoto = profile?.profilePhoto ?? empInfo?.profilePhoto;

    final initials = empName
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .take(2)
        .join('')
        .toUpperCase();

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Logo Section
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset('assets/images/app_logo.png', width: 44, height: 44, fit: BoxFit.contain),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QB Suite Customer',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'BUSINESS SUITE',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Navigation Items (Non-duplicate)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildSectionHeader('CRM WORKFLOW'),
                _buildNavItem(
                  Remix.phone_find_line,
                  'Follow-ups',
                  SidebarItem.followUps,
                ),
                _buildNavItem(
                  Remix.file_paper_2_line,
                  'Proposals',
                  SidebarItem.proposals,
                ),
                _buildNavItem(
                  Remix.secure_payment_line,
                  'Payments',
                  SidebarItem.payments,
                ),
                _buildNavItem(Remix.rocket_2_line, 'Work', SidebarItem.work),

                const SizedBox(height: 20),
                _buildSectionHeader('HRM / MY WORK'),
                _buildNavItem(
                  Remix.fingerprint_line,
                  'Attendance',
                  SidebarItem.attendance,
                ),
                _buildNavItem(
                  Remix.file_list_3_line,
                  'Requests',
                  SidebarItem.requests,
                ),

                const SizedBox(height: 20),
                _buildSectionHeader('SYSTEM'),
                // Notifications accessible via AppBar bell icon only
                _buildNavItem(
                  Remix.settings_3_line,
                  'Settings',
                  SidebarItem.settings,
                ),
              ],
            ),
          ),

          // User Profile Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Row(
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
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              if (empCode.isNotEmpty) ...[
                                Text(
                                  empCode,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                if (designation.isNotEmpty &&
                                    designation.toLowerCase() != 'staff') ...[
                                  Text(
                                    ' • ',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                              if (designation.isNotEmpty &&
                                  designation.toLowerCase() != 'staff')
                                Expanded(
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
                  ],
                ),
                const SizedBox(height: 14),
                _buildLogoutButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8, top: 4),
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

  Widget _buildNavItem(IconData icon, String label, SidebarItem item) {
    final bool isActive = currentSelection == item;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemSelected(item),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: isActive
                        ? AppColors.primaryDark
                        : AppColors.textPrimary,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                if (isActive) ...[
                  const Spacer(),
                  const Icon(
                    Remix.arrow_right_s_line,
                    color: AppColors.primaryDark,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onLogout,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Remix.logout_box_r_line,
                size: 16,
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Logout',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
