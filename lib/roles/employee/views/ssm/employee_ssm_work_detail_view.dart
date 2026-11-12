import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/employee/models/employee_ssm_work_model.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_ssm_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/ssm/ssm_action_dialogs.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/ssm/ssm_daily_task_timeline.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/work_permissions_viewmodel.dart';
import 'employee_work_task_view.dart';

class EmployeeSSMWorkDetailView extends ConsumerWidget {
  final String workId;

  const EmployeeSSMWorkDetailView({super.key, required this.workId});


  void _showStartWorkDialog(
    BuildContext context,
    WidgetRef ref,
    SSMWorkSchedule work,
    int currentDay,
  ) async {
    final confirmed = await SSMActionDialogs.showStartWorkDialog(
      context: context,
      work: work,
      currentDay: currentDay,
    );

    if (confirmed == true && context.mounted) {
      ref.read(employeeSSMProvider.notifier).startWork(work.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Work started! Day $currentDay task is now in progress.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCompleteWorkDialog(
    BuildContext context,
    WidgetRef ref,
    SSMWorkSchedule work,
  ) async {
    final confirmed = await SSMActionDialogs.showCompleteWorkDialog(
      context: context,
      work: work,
    );

    if (confirmed == true && context.mounted) {
      ref.read(employeeSSMProvider.notifier).completeWork(work.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Social media work completed successfully!',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ssmState = ref.watch(employeeSSMProvider);
    final workList = ssmState.allSchedules
        .where((w) => w.id == workId)
        .toList();

    if (workList.isEmpty) {
      return const Scaffold(
        appBar: AppAppBar(title: 'Work Details'),
        body: Center(child: Text('Work item not found.')),
      );
    }

    final work = workList.first;
    final currentDay = work.getCurrentDayNumber(ssmState.todayDate);

    final permState = ref.watch(workPermissionsProvider);
    String moduleKey;
    switch (work.workType) {
      case SSMWorkType.reel:
        moduleKey = 'video_edit';
        break;
      case SSMWorkType.post:
        moduleKey = 'post_design';
        break;
      case SSMWorkType.shoot:
        moduleKey = 'reel_shoot';
        break;
    }

    if (!permState.hasWorkPermission(moduleKey)) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: const AppAppBar(title: 'Access Denied'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Remix.lock_2_line, size: 56, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your role does not have permission to access this work module.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),

              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: const AppAppBar(title: 'Work Details'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Card ──
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${work.workType.displayName.toUpperCase()} • ${work.durationDays} DAYS',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: work.assignedTeam.contains('Team A')
                                ? AppColors.primaryLight
                                : const Color(0xFFF9F5FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            work.assignedTeam,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: work.assignedTeam.contains('Team A')
                                  ? AppColors.primaryDark
                                  : const Color(0xFF6941C6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      work.customerName,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      work.customerBusiness,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _getPlatformIcon(work.platform, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            work.socialMediaAccount,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── Key Specifications ──
              Text(
                'SPECIFICATIONS & TIMELINE',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    
                    const Divider(height: 20, color: AppColors.borderLight),
                    
                    const Divider(height: 20, color: AppColors.borderLight),
                    _buildDetailRow(
                      'Duration',
                      '${work.durationDays} Days (Day $currentDay Active)',
                    ),
                    const Divider(height: 20, color: AppColors.borderLight),
                    _buildDetailRow('Priority', work.priority),
                    const Divider(height: 20, color: AppColors.borderLight),
                    _buildDetailRow('Assigned Team', work.assignedTeam),
                    const Divider(height: 20, color: AppColors.borderLight),
                    _buildDetailRow(
                      'Team Members',
                      work.assignedEmployees.join(', '),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Notes Card ──
              if (work.notes.isNotEmpty) ...[
                Text(
                  'CAMPAIGN NOTES',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    work.notes,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Daily Task Breakdown Timeline ──
              Text(
                'DAILY TASK STAGES (${work.durationDays} DAYS)',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              SSMDailyTaskTimeline(
                work: work,
                targetDate: ssmState.todayDate,
                onCompleteDayTask: (dayNum) {
                  ref
                      .read(employeeSSMProvider.notifier)
                      .completeDayTask(work.id, dayNum);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Day $dayNum task marked complete!',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: AppColors.primaryDark,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // ── Bottom Action Button ──
              if (work.status == SSMWorkStatus.scheduled)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showStartWorkDialog(context, ref, work, currentDay),
                    icon: const Icon(Remix.play_fill, size: 18),
                    label: Text(
                      'START WORK',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                )
              else if (work.status == SSMWorkStatus.inProgress)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EmployeeWorkTaskView(workId: work.id),
                            ),
                          );
                        },
                        icon: const Icon(Remix.task_line, size: 18),
                        label: Text(
                          "VIEW TODAY'S TASK",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showCompleteWorkDialog(context, ref, work),
                        icon: const Icon(Remix.check_double_line, size: 18),
                        label: Text(
                          'COMPLETE WORK',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _getPlatformIcon(String platform, {double size = 16}) {
    switch (platform.toLowerCase()) {
      case 'instagram':
        return Icon(
          Remix.instagram_line,
          color: const Color(0xFFE1306C),
          size: size,
        );
      case 'facebook':
        return Icon(
          Remix.facebook_circle_fill,
          color: const Color(0xFF1877F2),
          size: size,
        );
      case 'youtube':
        return Icon(
          Remix.youtube_fill,
          color: const Color(0xFFFF0000),
          size: size,
        );
      case 'linkedin':
        return Icon(
          Remix.linkedin_box_fill,
          color: const Color(0xFF0A66C2),
          size: size,
        );
      default:
        return Icon(Remix.global_line, color: AppColors.primary, size: size);
    }
  }
}
