import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/employee/models/employee_ssm_work_model.dart';

class SSMWorkCard extends StatelessWidget {
  final SSMWorkSchedule work;
  final DateTime targetDate;
  final VoidCallback? onTap;
  final VoidCallback? onStartWork;
  final VoidCallback? onCompleteTask;
  final bool isCompact;

  const SSMWorkCard({
    super.key,
    required this.work,
    required this.targetDate,
    this.onTap,
    this.onStartWork,
    this.onCompleteTask,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentDayNumber = work.getCurrentDayNumber(targetDate);
    final taskForDay = work.getTaskForDay(currentDayNumber);

    Color statusBgColor;
    Color statusTextColor;
    switch (work.status) {
      case SSMWorkStatus.inProgress:
        statusBgColor = AppColors.primaryLight;
        statusTextColor = AppColors.primaryDark;
        break;
      case SSMWorkStatus.completed:
        statusBgColor = const Color(0xFFEFF8FF);
        statusTextColor = const Color(0xFF175CD3);
        break;
      case SSMWorkStatus.cancelled:
        statusBgColor = const Color(0xFFFEF3F2);
        statusTextColor = AppColors.error;
        break;
      case SSMWorkStatus.scheduled:
        statusBgColor = const Color(0xFFFEF0C7);
        statusTextColor = const Color(0xFFB54708);
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badges: Work Type, Team Badge & Status Badge
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pillBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _getWorkTypeIcon(work.workType, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${work.workType.displayName} Shoot',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    work.status.displayName.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: statusTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Customer Name
            Text(
              work.customerName,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            // Account & Platform
            Row(
              children: [
                _getPlatformIcon(work.platform, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    work.socialMediaAccount,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 12),

            // Current Day & Task Snippet
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Day $currentDayNumber of ${work.durationDays}',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    taskForDay?.title ?? 'Scheduled Task',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Bottom Action Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Remix.user_3_line,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          work.assignedEmployees.join(', '),
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (work.status == SSMWorkStatus.scheduled &&
                    onStartWork != null)
                  ElevatedButton(
                    onPressed: onStartWork,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 34),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'START WORK',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(
                      Remix.arrow_right_line,
                      size: 14,
                      color: AppColors.primaryDark,
                    ),
                    label: Text(
                      'View Work',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getWorkTypeIcon(SSMWorkType type, {double size = 14}) {
    switch (type) {
      case SSMWorkType.reel:
        return Icon(Remix.video_line, color: AppColors.primaryDark, size: size);
      case SSMWorkType.shoot:
        return Icon(
          Remix.camera_3_line,
          color: const Color(0xFF9E77ED),
          size: size,
        );
      case SSMWorkType.post:
        return Icon(
          Remix.image_line,
          color: const Color(0xFF2E90FA),
          size: size,
        );
    }
  }

  Widget _getPlatformIcon(String platform, {double size = 14}) {
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
