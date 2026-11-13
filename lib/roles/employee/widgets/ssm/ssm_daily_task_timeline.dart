import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/employee/models/employee_ssm_work_model.dart';

class SSMDailyTaskTimeline extends StatelessWidget {
  final SSMWorkSchedule work;
  final DateTime targetDate;
  final Function(int dayNumber)? onCompleteDayTask;

  const SSMDailyTaskTimeline({
    super.key,
    required this.work,
    required this.targetDate,
    this.onCompleteDayTask,
  });


  @override
  Widget build(BuildContext context) {
    final currentActiveDay = work.getCurrentDayNumber(targetDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(work.dailyTasks.length, (index) {
        final task = work.dailyTasks[index];
        final isLast = index == work.dailyTasks.length - 1;
        final isCurrent = task.dayNumber == currentActiveDay;
        final isCompleted =
            task.isCompleted || work.status == SSMWorkStatus.completed;

        Widget indicator;

        if (isCompleted) {
          indicator = Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 14, color: Colors.white),
          );
        } else if (isCurrent) {
          indicator = Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        } else {
          indicator = Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicator column with connecting vertical line
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    indicator,
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isCompleted
                              ? AppColors.primary
                              : AppColors.borderLight,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Task Content Box
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCurrent ? AppColors.subtleGreenBg : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.borderLight,
                        width: isCurrent ? 1.2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            
                            const SizedBox(width: 6),
                            if (isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'COMPLETED',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              )
                            else if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF0C7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'ACTIVE TODAY',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFB54708),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.title,
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          task.description,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (!isCompleted &&
                            work.status == SSMWorkStatus.inProgress &&
                            onCompleteDayTask != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  onCompleteDayTask!(task.dayNumber),
                              icon: const Icon(Remix.check_line, size: 14),
                              label: Text(
                                'Mark Day ${task.dayNumber} Complete',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                minimumSize: const Size(0, 32),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
