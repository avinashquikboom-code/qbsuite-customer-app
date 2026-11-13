import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/employee/models/employee_ssm_work_model.dart';

class ClientCard extends StatelessWidget {
  final SSMClientSummary client;
  final DateTime targetDate;
  final VoidCallback? onTap;

  const ClientCard({
    super.key,
    required this.client,
    required this.targetDate,
    this.onTap,
  });

  static String _formatDateRange(DateTime start, DateTime end) {
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
    if (start.month == end.month && start.year == end.year) {
      return '${start.day} — ${end.day} ${months[start.month - 1]} ${start.year}';
    }
    return '${start.day} ${months[start.month - 1]} — ${end.day} ${months[end.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final work = client.primaryWork;
    final currentDay = work.getCurrentDayNumber(targetDate);
    final taskForDay = work.getTaskForDay(currentDay);

    final status = client.clientStatus;
    Color statusBgColor;
    Color statusTextColor;
    if (status == 'ACTIVE') {
      statusBgColor = AppColors.primaryLight;
      statusTextColor = AppColors.primaryDark;
    } else if (status == 'COMPLETED') {
      statusBgColor = const Color(0xFFEFF8FF);
      statusTextColor = const Color(0xFF175CD3);
    } else {
      statusBgColor = const Color(0xFFFEF0C7);
      statusTextColor = const Color(0xFFB54708);
    }

    final initial = client.customerName.isNotEmpty
        ? client.customerName[0].toUpperCase()
        : 'C';

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
            // ── Top Row: Logo/Initial + Name + Status ──
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.subtleGreenBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.customerName,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        client.customerBusiness,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Social Media Account ──
            Row(
              children: [
                _getPlatformIcon(client.platform, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    client.socialMediaAccount,
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

            // ── Current Work Specifications ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${work.workType.displayName} Shoot • ${work.assignedTeam}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDateRange(work.startDate, work.endDate),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Day Stage & Task ──
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
                  Text(
                    'Day $currentDay of ${work.durationDays}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    taskForDay?.title ?? 'Deliverable Stage',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Bottom Row: Works Count & View Client Link ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.pillBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${client.allWorks.length} Campaigns',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Client',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Remix.arrow_right_line,
                        size: 14,
                        color: AppColors.primaryDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
