import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/company_admin_models.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/team_model.dart';
import 'package:quickboom_crm_customer/roles/employee/models/employee_ssm_work_model.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/team_calendar_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/employee_activity_detail_sheet.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';

class TeamCalendarWidget extends ConsumerStatefulWidget {
  final int? initialTeamId;
  final DateTime? initialDate;
  final Function(SSMWorkSchedule work)? onWorkTap;

  const TeamCalendarWidget({
    super.key,
    this.initialTeamId,
    this.initialDate,
    this.onWorkTap,
  });

  @override
  ConsumerState<TeamCalendarWidget> createState() => _TeamCalendarWidgetState();
}

class _TeamCalendarWidgetState extends ConsumerState<TeamCalendarWidget> {
  final ScrollController _dateScrollController = ScrollController();

  static const List<String> _monthNames = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];

  static String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'MON';
      case 2:
        return 'TUE';
      case 3:
        return 'WED';
      case 4:
        return 'THU';
      case 5:
        return 'FRI';
      case 6:
        return 'SAT';
      case 7:
      default:
        return 'SUN';
    }
  }

  static String _formatDisplayDate(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialTeamId != null || widget.initialDate != null) {
        ref
            .read(teamCalendarProvider.notifier)
            .loadTeams(
              preferredTeamId: widget.initialTeamId,
              initialDate: widget.initialDate,
            );
      }
      _scrollToSelectedDate();
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dateScrollController.hasClients) return;
      final state = ref.read(teamCalendarProvider);
      final dayIndex = state.selectedDate.day - 1;
      const itemWidth = 60.0;
      final targetOffset = (dayIndex * itemWidth) - 100.0;
      _dateScrollController.animateTo(
        targetOffset.clamp(0.0, _dateScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teamCalendarProvider);
    final notifier = ref.read(teamCalendarProvider.notifier);

    final daysInMonth = DateUtils.getDaysInMonth(
      state.currentMonth.year,
      state.currentMonth.month,
    );
    final monthDates = List.generate(
      daysInMonth,
      (i) => DateTime(state.currentMonth.year, state.currentMonth.month, i + 1),
    );

    final activitiesForSelectedDate = state.selectedDateActivities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Team Selector Dropdown / Info Header ──
        _buildTeamSelectorHeader(state, notifier),

        const SizedBox(height: 14),

        // ── 2. Month Calendar Card with Date Strip ──
        Container(
          padding: const EdgeInsets.all(14),
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
              // Month & Year Navigation Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Remix.calendar_event_line,
                        size: 17,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_monthNames[state.currentMonth.month - 1]} ${state.currentMonth.year}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Previous Month Button
                      InkWell(
                        onTap: () {
                          final prevMonth = DateTime(
                            state.currentMonth.year,
                            state.currentMonth.month - 1,
                            1,
                          );
                          notifier.selectMonth(prevMonth);
                          _scrollToSelectedDate();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.pillBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Remix.arrow_left_s_line,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Today Quick Button
                      InkWell(
                        onTap: () {
                          final now = DateTime.now();
                          notifier.selectMonth(
                            DateTime(now.year, now.month, 1),
                          );
                          notifier.selectDate(now);
                          _scrollToSelectedDate();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.subtleGreenBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Today',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Next Month Button
                      InkWell(
                        onTap: () {
                          final nextMonth = DateTime(
                            state.currentMonth.year,
                            state.currentMonth.month + 1,
                            1,
                          );
                          notifier.selectMonth(nextMonth);
                          _scrollToSelectedDate();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.pillBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Remix.arrow_right_s_line,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Horizontal Date Selector Strip
              SingleChildScrollView(
                controller: _dateScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: monthDates.map((date) {
                    final isSelected =
                        state.selectedDate.year == date.year &&
                        state.selectedDate.month == date.month &&
                        state.selectedDate.day == date.day;

                    final dots = state.getDotsForDate(date);
                    final hasWork = dots.isNotEmpty;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          notifier.selectDate(date);
                          _scrollToSelectedDate();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 52,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : (hasWork
                                      ? AppColors.subtleGreenBg
                                      : AppColors.scaffoldBg),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : (hasWork
                                        ? AppColors.primary.withValues(
                                            alpha: 0.3,
                                          )
                                        : AppColors.borderLight),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getDayName(date.weekday),
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white70
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${date.day}',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Multi-Dot Row for Activity Types
                              SizedBox(
                                height: 6,
                                child: dots.isNotEmpty
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: dots.map((dotColor) {
                                          return Container(
                                            width: 5,
                                            height: 5,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.white
                                                  : dotColor,
                                              shape: BoxShape.circle,
                                            ),
                                          );
                                        }).toList(),
                                      )
                                    : const SizedBox(height: 5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── 3. Selected Date Section Header ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Schedule for ${_formatDisplayDate(state.selectedDate)}',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${activitiesForSelectedDate.length} ${activitiesForSelectedDate.length == 1 ? 'activity' : 'activities'} scheduled',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (state.isLoadingCalendar)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // ── 4. Activities List for Selected Date ──
        if (state.isLoadingCalendar && activitiesForSelectedDate.isEmpty)
          _buildLoadingPlaceholder()
        else if (activitiesForSelectedDate.isEmpty)
          _buildEmptyState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activitiesForSelectedDate.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final activity = activitiesForSelectedDate[index];
              return _buildActivityCard(context, activity, notifier);
            },
          ),
      ],
    );
  }

  /// Header showing current team and dropdown to switch if multiple teams exist
  Widget _buildTeamSelectorHeader(
    TeamCalendarState state,
    TeamCalendarNotifier notifier,
  ) {
    if (state.isLoadingTeams) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: const SkeletonBox(height: 16),
      );
    }

    final teams = state.teams;
    final selectedTeam = state.selectedTeam;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Remix.team_line,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedTeam?.name ?? 'My Team',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${selectedTeam?.memberCount ?? 0} team members',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (teams.length > 1)
            PopupMenuButton<TeamItem>(
              tooltip: 'Switch Team',
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.pillBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Change',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Remix.arrow_down_s_line,
                      size: 14,
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
              ),
              onSelected: (team) => notifier.selectTeam(team),
              itemBuilder: (context) {
                return teams.map((t) {
                  final isCurrent = t.id == selectedTeam?.id;
                  return PopupMenuItem<TeamItem>(
                    value: t,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t.name,
                          style: GoogleFonts.outfit(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isCurrent
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (isCurrent)
                          const Icon(
                            Remix.check_line,
                            size: 16,
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
        ],
      ),
    );
  }

  /// Rich activity card matching the exact specifications
  Widget _buildActivityCard(
    BuildContext context,
    CustomerCalendarActivity activity,
    TeamCalendarNotifier notifier,
  ) {
    final actColor = resolveTaskColor(
      activity,
      title: activity.title,
      type: activity.type,
      status: activity.status,
    );
    final actBgColor = resolveTaskBgColor(
      activity,
      title: activity.title,
      type: activity.type,
      status: activity.status,
    );
    final cat = resolveTaskCategory(
      activity,
      title: activity.title,
      type: activity.type,
      status: activity.status,
    );

    final statusStr = activity.status.toUpperCase();
    Color statusBadgeColor;
    Color statusBadgeBgColor;
    if (statusStr == 'COMPLETED' ||
        statusStr == 'DONE' ||
        statusStr == 'APPROVED') {
      statusBadgeColor = const Color(0xFF16A34A);
      statusBadgeBgColor = const Color(0xFFDCFCE7);
    } else if (statusStr == 'IN_PROGRESS' ||
        statusStr == 'PROCESSING' ||
        statusStr == 'REVIEW') {
      statusBadgeColor = const Color(0xFF2563EB);
      statusBadgeBgColor = const Color(0xFFDBEAFE);
    } else {
      statusBadgeColor = const Color(0xFFD97706);
      statusBadgeBgColor = const Color(0xFFFEF3C7);
    }

    final employeeDisplay = activity.assignedEmployee.isNotEmpty
        ? activity.assignedEmployee
        : 'Unassigned';

    return InkWell(
      onTap: () async {
        EmployeeActivityDetailSheet.show(context, activity);
        // Refresh after modal is dismissed in case status updated
        await notifier.refresh();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Activity Type Badge & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: actBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.icon, size: 13, color: actColor),
                      const SizedBox(width: 5),
                      Text(
                        cat.label,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: actColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusBadgeBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    activity.status,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusBadgeColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Title
            Text(
              activity.title ?? cat.label,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 6),

            // Customer Name & Scheduled Time
            Row(
              children: [
                const Icon(
                  Remix.building_line,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    activity.customerName.isNotEmpty
                        ? activity.customerName
                        : 'Customer',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (activity.time.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                const Icon(
                  Remix.time_line,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  activity.time.trim(),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                ],
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 10),

            // Bottom Row: Assigned Employee Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.pillBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Remix.user_3_line,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Employee: $employeeDisplay',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Remix.arrow_right_s_line,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Empty state when genuine zero activities are scheduled
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.pillBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Remix.calendar_close_line,
              size: 24,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No activities scheduled',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No team activities found for this date.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Column(
      children: const [
        SkeletonCard(),
        SkeletonCard(),
      ],
    );
  }
}
