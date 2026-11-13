import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/company_admin_models.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/employee_activity_detail_sheet.dart';

/// Formats date to '08 Sep 2026' style
String formatActivityDate(DateTime dt) {
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
  final day = dt.day.toString().padLeft(2, '0');
  final month = months[(dt.month - 1).clamp(0, 11)];
  return '$day $month ${dt.year}';
}

/// Resolves real backend activity type title (e.g. REEL EDIT, POST DESIGN, REEL SHOOT)
String resolveActivityTypeTitle(CustomerCalendarActivity activity) {
  final category = resolveTaskCategory(activity);
  if (category != TaskCategory.unknown) {
    return category.label.toUpperCase();
  }

  final rawType = activity.type.trim();
  if (rawType.isNotEmpty &&
      rawType.toLowerCase() != 'task' &&
      rawType.toLowerCase() != 'schedule') {
    return rawType.replaceAll('_', ' ').toUpperCase();
  }

  final title = (activity.title ?? '').trim();
  if (title.isNotEmpty &&
      title.toLowerCase() != 'task' &&
      title.toLowerCase() != 'schedule') {
    if (title.startsWith('Task / ') || title.startsWith('Task - ')) {
      return title.substring(7).trim().toUpperCase();
    }
    return title.toUpperCase();
  }

  return 'SCHEDULED ACTIVITY';
}

class EmployeeMyWorkCard extends StatelessWidget {
  final CustomerCalendarActivity activity;
  final bool isActionLoading;
  final VoidCallback? onStartWork;
  final VoidCallback? onCompleteWork;
  final VoidCallback? onTap;

  const EmployeeMyWorkCard({
    super.key,
    required this.activity,
    this.isActionLoading = false,
    this.onStartWork,
    this.onCompleteWork,
    this.onTap,
  });

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'APPROVED':
      case 'DONE':
        return const Color(0xFF16A34A);
      case 'IN_PROGRESS':
      case 'PROCESSING':
        return const Color(0xFF2563EB);
      case 'ON_HOLD':
        return const Color(0xFFD97706);
      case 'CANCELLED':
        return const Color(0xFFDC2626);
      case 'ASSIGNED':
      case 'SCHEDULED':
      case 'PENDING':
      default:
        return const Color(0xFF475569);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'APPROVED':
      case 'DONE':
        return const Color(0xFFDCFCE7);
      case 'IN_PROGRESS':
      case 'PROCESSING':
        return const Color(0xFFDBEAFE);
      case 'ON_HOLD':
        return const Color(0xFFFEF3C7);
      case 'CANCELLED':
        return const Color(0xFFFEE2E2);
      case 'ASSIGNED':
      case 'SCHEDULED':
      case 'PENDING':
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = resolveTaskColor(activity);
    final actTitle = resolveActivityTypeTitle(activity);

    final companyName = activity.businessName.trim();

    final customerDisplayName = activity.customerName.trim().isNotEmpty
        ? activity.customerName.trim()
        : companyName;

    final dateFormatted = formatActivityDate(activity.date);
    final timeStr = activity.time.isNotEmpty ? activity.time : 'Scheduled';
    final normalizedStatus = activity.status.toUpperCase();

    final isCompleted =
        normalizedStatus == 'COMPLETED' ||
        normalizedStatus == 'APPROVED' ||
        normalizedStatus == 'DONE';

    final isInProgress =
        normalizedStatus == 'IN_PROGRESS' || normalizedStatus == 'PROCESSING';

    final assignedRole = resolveAssignedRole(activity);
    final isVideoOrGraphics =
        assignedRole == 'Video Editor' || assignedRole == 'Graphic Designer';
    final isCorrection = normalizedStatus == 'REVISION_REQUESTED';
    final hasRevisions = activity.revisionCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap:
              onTap ??
              () => EmployeeActivityDetailSheet.show(context, activity),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row: Actual Activity Name/Type + Category Color Dot
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        actTitle,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: catColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: catColor.withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (activity.isCarriedForward) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Remix.time_line,
                          size: 12,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'CARRIED FORWARD${activity.originalScheduledDateDisplay != null ? ' • Originally scheduled: ${activity.originalScheduledDateDisplay}' : ''}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                Text(
                  (companyName.isNotEmpty ? companyName : customerDisplayName)
                      .toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 2),

                // 2. Customer Name (Second line)
                Text(
                  customerDisplayName,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                if (companyName.isNotEmpty &&
                    companyName != customerDisplayName) ...[
                  const SizedBox(height: 3),
                  Text(
                    companyName,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // Date & Time Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.calendar_line,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            dateFormatted,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334155),
                            ),
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
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.time_line,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            timeStr,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Assigned Employee, Team & Purchase Row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (activity.assignedEmployee.trim().isNotEmpty &&
                        activity.assignedEmployee.toLowerCase() != 'unassigned')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Remix.user_3_line,
                              size: 12,
                              color: Color(0xFF4F46E5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              activity.assignedEmployee.trim(),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4338CA),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (activity.team != null &&
                        activity.team!.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Remix.team_line,
                              size: 12,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              activity.team!.trim(),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (activity.purchaseId != null &&
                        activity.purchaseId!.trim().isNotEmpty)
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
                          activity.purchaseId!.trim(),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                  ],
                ),

                // Latest Employee Update Note Callout
                if (activity.notes != null &&
                    activity.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Remix.chat_quote_line,
                          size: 13,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            activity.notes!.trim(),
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: const Color(0xFF475569),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),

                // Bottom Status & Action Button Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: activity.isCarriedForward && !isCompleted && !isInProgress
                            ? const Color(0xFFFEF3C7)
                            : _getStatusBgColor(activity.status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCompleted)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Remix.checkbox_circle_fill,
                                size: 13,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          Text(
                            activity.isCarriedForward && !isCompleted && !isInProgress
                                ? 'PENDING / CARRIED FORWARD'
                                : activity.status.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: activity.isCarriedForward && !isCompleted && !isInProgress
                                  ? const Color(0xFFB45309)
                                  : _getStatusColor(activity.status),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action Button
                    if (isActionLoading)
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    else if (isCompleted)
                      // Completed status indicator
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.check_line,
                            size: 16,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      )
                    else if (isInProgress)
                      // Complete Work Button
                      ElevatedButton.icon(
                        onPressed: onCompleteWork,
                        icon: const Icon(
                          Remix.checkbox_circle_line,
                          size: 15,
                          color: Colors.white,
                        ),
                        label: Text(
                          (isVideoOrGraphics && hasRevisions)
                              ? 'Final Complete'
                              : 'Complete Work',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      )
                    else if (isCorrection && isVideoOrGraphics)
                      ElevatedButton.icon(
                        onPressed: onCompleteWork,
                        icon: const Icon(
                          Remix.check_double_line,
                          size: 15,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Final Complete',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      )
                    else
                      // Start Work Button (SCHEDULED, ASSIGNED, PENDING)
                      ElevatedButton.icon(
                        onPressed: onStartWork,
                        icon: const Icon(
                          Remix.play_fill,
                          size: 13,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Start Work',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer/pulse skeleton card matching EmployeeMyWorkCard layout
class EmployeeMyWorkCardSkeleton extends StatefulWidget {
  const EmployeeMyWorkCardSkeleton({super.key});

  @override
  State<EmployeeMyWorkCardSkeleton> createState() =>
      _EmployeeMyWorkCardSkeletonState();
}

class _EmployeeMyWorkCardSkeletonState extends State<EmployeeMyWorkCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.75,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildPlaceholder({
    required double width,
    required double height,
    double radius = 6,
  }) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0).withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPlaceholder(width: 110, height: 14, radius: 4),
              _buildPlaceholder(width: 10, height: 10, radius: 5),
            ],
          ),
          const SizedBox(height: 12),
          // Customer name skeleton
          _buildPlaceholder(width: 180, height: 18, radius: 5),
          const SizedBox(height: 6),
          // Subtitle skeleton
          _buildPlaceholder(width: 130, height: 13, radius: 4),
          const SizedBox(height: 14),
          // Date / Time row skeleton
          Row(
            children: [
              _buildPlaceholder(width: 95, height: 26, radius: 8),
              const SizedBox(width: 8),
              _buildPlaceholder(width: 80, height: 26, radius: 8),
            ],
          ),
          const SizedBox(height: 12),
          // Purchase tag skeleton
          _buildPlaceholder(width: 120, height: 20, radius: 6),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          // Status and Button row skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPlaceholder(width: 85, height: 24, radius: 8),
              _buildPlaceholder(width: 100, height: 32, radius: 10),
            ],
          ),
        ],
      ),
    );
  }
}
