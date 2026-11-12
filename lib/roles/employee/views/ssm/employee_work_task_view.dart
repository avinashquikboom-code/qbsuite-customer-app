import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/employee/models/employee_ssm_work_model.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_ssm_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/ssm/ssm_action_dialogs.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/ssm/ssm_daily_task_timeline.dart';

class EmployeeWorkTaskView extends ConsumerWidget {
  final String workId;

  const EmployeeWorkTaskView({super.key, required this.workId});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ssmState = ref.watch(employeeSSMProvider);
    final ssmNotifier = ref.read(employeeSSMProvider.notifier);

    final workList = ssmState.allSchedules
        .where((s) => s.id == workId)
        .toList();
    if (workList.isEmpty) {
      return const Scaffold(
        appBar: AppAppBar(title: 'Work Task'),
        body: Center(child: Text('Task not found.')),
      );
    }

    final work = workList.first;
    final currentDay = work.getCurrentDayNumber(ssmState.todayDate);
    final taskForDay = work.getTaskForDay(currentDay);
    final isTaskCompleted = taskForDay?.isCompleted ?? false;
    final isFinalDay = currentDay >= work.durationDays;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: const AppAppBar(title: 'Work Task', showBackButton: true),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Top Task Header Card ──
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
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
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "TODAY'S TASK • DAY $currentDay OF ${work.durationDays}",
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                                letterSpacing: 0.5,
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
                            color: work.status == SSMWorkStatus.inProgress
                                ? AppColors.primaryLight
                                : const Color(0xFFFEF0C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            work.status.displayName.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: work.status == SSMWorkStatus.inProgress
                                  ? AppColors.primaryDark
                                  : const Color(0xFFB54708),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      taskForDay?.title ?? 'Deliverable Stage',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      taskForDay?.description ??
                          'Production activity in progress.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── 2. Work & Team Specifications ──
              Text(
                'WORK SPECIFICATIONS',
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
                    _buildDetailRow('Customer Name', work.customerName),
                    const Divider(height: 20, color: AppColors.borderLight),
                    _buildDetailRow('Social Account', work.socialMediaAccount),
                    const Divider(height: 20, color: AppColors.borderLight),
                    _buildDetailRow('Platform', work.platform),
                    const Divider(height: 20, color: AppColors.borderLight),
                    _buildDetailRow(
                      'Work Type',
                      '${work.workType.displayName} Shoot',
                    ),
                    const Divider(height: 20, color: AppColors.borderLight),
                    _buildDetailRow(
                      'Team Name',
                      work.assignedTeam,
                    ), // SSM Team A
                    const Divider(height: 20, color: AppColors.borderLight),
                    _buildDetailRow(
                      'Assigned Members',
                      work.assignedEmployees.join(', '),
                    ),
                    const Divider(height: 20, color: AppColors.borderLight),
                    
                    const Divider(height: 20, color: AppColors.borderLight),
                    
                    const Divider(height: 20, color: AppColors.borderLight),
                    _buildDetailRow('Duration', '${work.durationDays} Days'),
                    const Divider(height: 20, color: AppColors.borderLight),
                    _buildDetailRow(
                      'Current Day',
                      'Day $currentDay of ${work.durationDays}',
                    ),
                    const Divider(height: 20, color: AppColors.borderLight),
                    _buildDetailRow('Notes', work.notes),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 3. Multi-Day Task Timeline ──
              Text(
                'MULTI-DAY TASK BREAKDOWN',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),

              SSMDailyTaskTimeline(
                work: work,
                targetDate: ssmState.todayDate,
                onCompleteDayTask: (dayNum) async {
                  final task = work.getTaskForDay(dayNum);
                  final isFinal = dayNum >= work.durationDays;

                  final confirmed = isFinal
                      ? await SSMActionDialogs.showCompleteWorkDialog(
                          context: context,
                          work: work,
                        )
                      : await SSMActionDialogs.showCompleteTaskDialog(
                          context: context,
                          taskTitle: task?.title ?? 'Deliverable',
                          dayNumber: dayNum,
                        );

                  if (confirmed == true && context.mounted) {
                    if (isFinal) {
                      ssmNotifier.completeWork(work.id);
                    } else {
                      ssmNotifier.completeDayTask(work.id, dayNum);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isFinal
                              ? 'All deliverables completed for ${work.customerName}!'
                              : 'Day $dayNum marked completed!',
                        ),
                        backgroundColor: AppColors.primaryDark,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 24),

              // ── 4. Complete Task / Complete Work CTA ──
              if (work.status == SSMWorkStatus.inProgress) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isTaskCompleted
                        ? null
                        : () async {
                            final confirmed = isFinalDay
                                ? await SSMActionDialogs.showCompleteWorkDialog(
                                    context: context,
                                    work: work,
                                  )
                                : await SSMActionDialogs.showCompleteTaskDialog(
                                    context: context,
                                    taskTitle:
                                        taskForDay?.title ?? 'Deliverable',
                                    dayNumber: currentDay,
                                  );

                            if (confirmed == true && context.mounted) {
                              if (isFinalDay) {
                                ssmNotifier.completeWork(work.id);
                              } else {
                                ssmNotifier.completeDayTask(
                                  work.id,
                                  currentDay,
                                );
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isFinalDay
                                        ? 'Work marked COMPLETED!'
                                        : 'Day $currentDay task completed! Next task will unlock on scheduled date.',
                                  ),
                                  backgroundColor: AppColors.primaryDark,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isTaskCompleted
                          ? AppColors.pillBg
                          : AppColors.primary,
                      foregroundColor: isTaskCompleted
                          ? AppColors.textPlaceholder
                          : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isTaskCompleted
                          ? 'Day $currentDay Task Completed ✓'
                          : (isFinalDay
                                ? 'Complete Work'
                                : 'Mark Day $currentDay Task Complete'),
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],

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
          width: 100,
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
}
