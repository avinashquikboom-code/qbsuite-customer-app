import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_my_work_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/work_permissions_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/employee_activity_detail_sheet.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/employee_my_work_card.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';

import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';

class EmployeeSSMWorkListView extends ConsumerStatefulWidget {
  const EmployeeSSMWorkListView({super.key});

  @override
  ConsumerState<EmployeeSSMWorkListView> createState() =>
      _EmployeeSSMWorkListViewState();
}

class _EmployeeSSMWorkListViewState
    extends ConsumerState<EmployeeSSMWorkListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(employeeMyWorkProvider.notifier).loadInitial();
      ref.read(workPermissionsProvider.notifier).refresh();
    });
  }

  void _showWorkResultToast(
    BuildContext context, {
    required bool success,
    required String message,
  }) {
    final media = MediaQuery.of(context);
    // The Production Team bar is 62px and sits outside this page scaffold,
    // so a default snackbar paints into that band. Lift it clear of the bar
    // and the system gesture inset.
    final bottom = media.viewPadding.bottom + 62 + 16;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
          padding: EdgeInsets.zero,
          duration: const Duration(seconds: 2),
          content: Align(
            alignment: Alignment.center,
            heightFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: success ? const Color(0xFF16A34A) : AppColors.error,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    success ? Remix.check_line : Remix.error_warning_line,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Future<void> _pickDate(BuildContext context) async {
    final myWorkState = ref.read(employeeMyWorkProvider);
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: myWorkState.selectedDate,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      await ref.read(employeeMyWorkProvider.notifier).setDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myWorkState = ref.watch(employeeMyWorkProvider);
    final myWorkNotifier = ref.read(employeeMyWorkProvider.notifier);
    final permState = ref.watch(workPermissionsProvider);
    final rbac = ref.watch(permissionManagerProvider);
    final isSupervisor =
        permState.permissions.isSupervisor ||
        rbac.canApproveCreativeWork ||
        rbac.canApproveTask;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppAppBar(
        title: isSupervisor ? 'Production Overview' : 'My Work',
        showBackButton: false,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await Future.wait([
              myWorkNotifier.refresh(),
              ref.read(workPermissionsProvider.notifier).refresh(),
            ]);
          },
          child: Column(
            children: [
              // ── 1. Role & Modules Header Banner ──
              _buildRoleHeaderBanner(permState, isSupervisor),

              const Divider(height: 1, color: AppColors.borderLight),

              // ── 2. Summary & Metrics Section ──
              _buildSupervisoryMetricsSection(myWorkState),

              // ── 3. Filters Section ──
              _buildSupervisoryFilterBar(context, myWorkState, myWorkNotifier),

              const Divider(height: 1, color: AppColors.borderLight),

              // ── 4. Main Activities List View ──
              Expanded(
                child: _buildActivitiesContent(
                  context,
                  myWorkState,
                  myWorkNotifier,
                  isSupervisor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleHeaderBanner(
    WorkPermissionsState permState,
    bool isSupervisor,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isSupervisor
                          ? 'Supervisory Access'
                          : 'Authorized Modules',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (permState.permissions.role.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            permState.permissions.role,
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Supervisory Metrics Dashboard Section (Production Manager)
  Widget _buildSupervisoryMetricsSection(EmployeeMyWorkState state) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Remix.dashboard_3_line,
                    size: 15,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Production Metrics',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${state.activities.length} filtered items',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Scrollable Metrics Cards Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildProductionMetricCard(
                  label: 'Total',
                  count: state.prodTotal,
                  color: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFE0F2FE),
                  icon: Remix.task_line,
                ),
                const SizedBox(width: 6),
                _buildProductionMetricCard(
                  label: 'In Progress',
                  count: state.prodInProgress,
                  color: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFDBEAFE),
                  icon: Remix.loader_2_line,
                ),
                const SizedBox(width: 6),
                _buildProductionMetricCard(
                  label: 'Pending',
                  count: state.prodPending,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                  icon: Remix.time_line,
                ),
                const SizedBox(width: 6),
                _buildProductionMetricCard(
                  label: 'Completed',
                  count: state.prodCompleted,
                  color: const Color(0xFF16A34A),
                  bgColor: const Color(0xFFDCFCE7),
                  icon: Remix.checkbox_circle_line,
                ),
                const SizedBox(width: 6),
                _buildProductionMetricCard(
                  label: 'Blocked',
                  count: state.prodBlocked,
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEE2E2),
                  icon: Remix.error_warning_line,
                ),
                const SizedBox(width: 6),
                _buildProductionMetricCard(
                  label: "Today's Work",
                  count: state.prodToday,
                  color: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFEDE9FE),
                  icon: Remix.calendar_check_line,
                ),
                const SizedBox(width: 6),
                _buildProductionMetricCard(
                  label: 'Overdue',
                  count: state.prodOverdue,
                  color: const Color(0xFFEA580C),
                  bgColor: const Color(0xFFFFEDD5),
                  icon: Remix.alarm_warning_line,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductionMetricCard({
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bgColor),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  /// Date filters for the production work list.
  Widget _buildSupervisoryFilterBar(
    BuildContext context,
    EmployeeMyWorkState state,
    EmployeeMyWorkNotifier notifier,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Date Range Pills
                _buildPill(
                  label: 'Today',
                  isSelected: state.selectedDateRange == 'TODAY',
                  onTap: () => notifier.setDateRangeFilter('TODAY'),
                ),
                const SizedBox(width: 6),
                _buildPill(
                  label: 'Tomorrow',
                  isSelected: state.selectedDateRange == 'TOMORROW',
                  onTap: () => notifier.setDateRangeFilter('TOMORROW'),
                ),
                const SizedBox(width: 6),
                _buildPill(
                  label: 'This Week',
                  isSelected: state.selectedDateRange == 'THIS_WEEK',
                  onTap: () => notifier.setDateRangeFilter('THIS_WEEK'),
                ),
                const SizedBox(width: 6),
                _buildPill(
                  label: state.selectedDateRange == 'CUSTOM'
                      ? formatActivityDate(state.selectedDate)
                      : 'Pick Date',
                  isSelected: state.selectedDateRange == 'CUSTOM',
                  onTap: () => _pickDate(context),
                  icon: Remix.calendar_line,
                ),
                const SizedBox(width: 6),
                _buildPill(
                  label: 'All Dates',
                  isSelected: state.selectedDateRange == 'ALL',
                  onTap: () => notifier.setDateRangeFilter('ALL'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// Builds Content: Skeleton (Loading) -> Error -> Empty -> Activity List
  Widget _buildActivitiesContent(
    BuildContext context,
    EmployeeMyWorkState state,
    EmployeeMyWorkNotifier notifier,
    bool isSupervisor,
  ) {
    if (state.isLoading) {
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (context, index) => const EmployeeMyWorkCardSkeleton(),
      );
    }

    if (state.errorMessage != null && state.activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Remix.error_warning_line,
                  size: 40,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load production work',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please check your internet connection or try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => notifier.refresh(),
                icon: const Icon(
                  Remix.refresh_line,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  'Retry',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.activities.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Remix.file_list_3_line,
                  size: 38,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isSupervisor ? 'No production tasks found' : 'No work assigned',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isSupervisor
                    ? 'No production work matches the selected filters for your workspace.'
                    : 'Your assigned activities will appear here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: state.activities.length,
      itemBuilder: (context, index) {
        final activity = state.activities[index];
        final isActionLoading = state.actionLoadingIds.contains(activity.id);

        return EmployeeMyWorkCard(
          activity: activity,
          isActionLoading: isActionLoading,
          onTap: () => EmployeeActivityDetailSheet.show(context, activity),
          onStartWork: () async {
            final success = await notifier.startWork(activity.id);
            if (!context.mounted) return;
            _showWorkResultToast(
              context,
              success: success,
              message: success
                  ? 'Work started successfully'
                  : 'Failed to update status. Please try again.',
            );
          },
          onCompleteWork: () async {
            final success = await notifier.completeWork(activity.id);
            if (!context.mounted) return;
            _showWorkResultToast(
              context,
              success: success,
              message: success
                  ? 'Work completed successfully'
                  : 'Failed to update status. Please try again.',
            );
          },
        );
      },
    );
  }
}
