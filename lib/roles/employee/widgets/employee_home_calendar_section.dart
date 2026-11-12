import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/company_admin_models.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_calendar_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/employee_activity_detail_sheet.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';

class EmployeeHomeCalendarSection extends ConsumerStatefulWidget {
  final VoidCallback? onViewAll;

  const EmployeeHomeCalendarSection({super.key, this.onViewAll});

  @override
  ConsumerState<EmployeeHomeCalendarSection> createState() =>
      _EmployeeHomeCalendarSectionState();
}

class _EmployeeHomeCalendarSectionState
    extends ConsumerState<EmployeeHomeCalendarSection> {
  late DateTime _selectedDate;

  static const List<String> _weekdays = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  static String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  bool _matchesFilter(CustomerCalendarActivity activity, String filter) {
    if (filter == 'All') return true;
    final taskCat = resolveTaskCategory(activity);

    if (filter == 'Reel Shoot') {
      return taskCat == TaskCategory.reelShoot ||
          taskCat == TaskCategory.videoShoot;
    } else if (filter == 'Video Editing') {
      return taskCat == TaskCategory.videoEditing ||
          taskCat == TaskCategory.reelEdit;
    } else if (filter == 'Post Design') {
      return taskCat == TaskCategory.postDesign;
    } else if (filter == 'Story Design') {
      return taskCat == TaskCategory.storyDesign;
    } else if (filter == 'Posting') {
      return taskCat == TaskCategory.reelPost ||
          taskCat == TaskCategory.storyPost ||
          taskCat == TaskCategory.postPublish;
    }

    final notes = (activity.notes ?? '').toLowerCase();
    final label = activity.activityType.label.toLowerCase();
    final title = (activity.title ?? '').toLowerCase();
    final service = (activity.serviceName ?? '').toLowerCase();
    final filterLower = filter.toLowerCase();

    return notes.contains(filterLower) ||
        label.contains(filterLower) ||
        title.contains(filterLower) ||
        service.contains(filterLower);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final globalSelectedDate = ref.watch(employeeCalendarSelectedDateProvider);
    _selectedDate = globalSelectedDate;

    final selectedFilter = ref.watch(employeeCalendarFilterProvider);
    final monthStr =
        '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}';
    final monthSummary = ref.watch(
      employeeCalendarPlanSummaryProvider(monthStr),
    );

    final totalWork = monthSummary.total;
    final completedWork = monthSummary.completed;
    final remainingWork = monthSummary.remaining;

    final mediaQuery = MediaQuery.maybeOf(context);
    final screenWidth = mediaQuery?.size.width ?? 0;
    final screenHeight = mediaQuery?.size.height ?? 0;
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    final rbac = ref.watch(permissionManagerProvider);

    debugPrint(
      '[CALENDAR_VISIBILITY_DEBUG]\n'
      'widget: EmployeeHomeCalendarSection\n'
      'employeeId: ${rbac.employeeId ?? "N/A"}\n'
      'roleId: ${rbac.role ?? "N/A"}\n'
      'permissionsCount: ${rbac.permissions.length}\n'
      'calendarPermission: ${rbac.canViewCalendar}\n'
      'isCalendarEnabled: ${rbac.canViewCalendar}\n'
      'currentRoute: /employee/home\n'
      'device width: $screenWidth\n'
      'device height: $screenHeight\n'
      'device pixel ratio: $devicePixelRatio\n'
      'timezone: ${DateTime.now().timeZoneName} (offset: ${DateTime.now().timeZoneOffset})',
    );

    final selectedNormalized = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final dates = List.generate(
      7,
      (index) => DateTime(
        selectedNormalized.year,
        selectedNormalized.month,
        selectedNormalized.day - 3 + index,
      ),
    );
    final startDate = dates.first;

    final startDateStr =
        '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final selectedDateStr = normalizeDate(_selectedDate);

    final live7DayAsync = ref.watch(
      employeeCalendarActivitiesFor7DayWindowProvider(startDateStr),
    );
    final liveDateAsync = ref.watch(
      employeeCalendarActivitiesForDateProvider(selectedDateStr),
    );
    final liveMonthAsync = ref.watch(
      employeeCalendarActivitiesForMonthProvider(monthStr),
    );
    final isMonthLoading = liveMonthAsync.isLoading && !liveMonthAsync.hasValue;

    final raw7DayActivities =
        live7DayAsync.asData?.value ?? const <CustomerCalendarActivity>[];
    final rawDateActivities =
        liveDateAsync.asData?.value ?? const <CustomerCalendarActivity>[];
    final rawMonthActivities =
        liveMonthAsync.asData?.value ?? const <CustomerCalendarActivity>[];

    // Build complete date-to-activities mapping for calendar strip dots
    final Map<String, List<CustomerCalendarActivity>> dateActivityMap = {};
    for (final a in rawMonthActivities) {
      final key = getScheduledDateString(a);
      dateActivityMap.putIfAbsent(key, () => []).add(a);
    }
    for (final a in raw7DayActivities) {
      final key = getScheduledDateString(a);
      final list = dateActivityMap.putIfAbsent(key, () => []);
      if (!list.any((existing) => existing.id == a.id && existing.type == a.type)) {
        list.add(a);
      }
    }
    for (final a in rawDateActivities) {
      final key = getScheduledDateString(a);
      final list = dateActivityMap.putIfAbsent(key, () => []);
      if (!list.any((existing) => existing.id == a.id && existing.type == a.type)) {
        list.add(a);
      }
    }

    // Selected date activities
    final List<CustomerCalendarActivity> rawMatchingDateActivities =
        rawDateActivities.isNotEmpty
        ? rawDateActivities
        : (liveDateAsync.hasError
              ? const <CustomerCalendarActivity>[]
              : (dateActivityMap[selectedDateStr] ??
                    const <CustomerCalendarActivity>[]));

    final matchingSelectedDateActivities = deduplicateCustomerActivities(
      rawMatchingDateActivities,
    );

    final selectedDateActivities = matchingSelectedDateActivities
        .where((a) => _matchesFilter(a, selectedFilter))
        .toList();

    final scheduledDates = ref.watch(
      employeeCalendarScheduledDatesForMonthProvider(monthStr),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Section Header & View All
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'EMPLOYEE CALENDAR',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  letterSpacing: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (widget.onViewAll != null)
              InkWell(
                onTap: widget.onViewAll,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Remix.arrow_right_s_line,
                        size: 14,
                        color: AppColors.primaryDark,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        // 2. Monthly Task Summary & Progress Card (Matching Customer Plan Card Style)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 10,
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
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.briefcase_4_fill,
                            size: 13,
                            color: AppColors.primaryDark,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${_getMonthName(_selectedDate.month)} Work Overview',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      totalWork == 0
                          ? (isMonthLoading ? 'Loading' : 'No Tasks')
                          : remainingWork > 0
                          ? '$remainingWork Remaining'
                          : 'All Completed',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: remainingWork > 0 || totalWork == 0
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      totalWork > 0
                          ? '$completedWork/$totalWork Tasks Completed'
                          : isMonthLoading
                          ? 'Loading this month\'s tasks'
                          : 'No tasks scheduled this month',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalWork > 0
                      ? (completedWork / totalWork).clamp(0.0, 1.0)
                      : 0.0,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    remainingWork > 0
                        ? AppColors.primary
                        : const Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 3. Horizontal 7-Day Date Strip with Multi-Category Indicators
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: dates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final date = dates[index];
              final isSelected =
                  date.year == _selectedDate.year &&
                  date.month == _selectedDate.month &&
                  date.day == _selectedDate.day;

              final isToday =
                  date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final normalizedDate = DateTime(date.year, date.month, date.day);
              final dateKey = normalizeDate(date);
              final matchingDateActivities =
                  dateActivityMap[dateKey] ??
                  const <CustomerCalendarActivity>[];

              // Extract unique customer colors for this date
              final uniqueColors = <Color>[];
              final seenCustomerKeys = <String>{};
              for (final act in matchingDateActivities) {
                final custKey = act.customerId.trim().isNotEmpty &&
                        act.customerId.trim() != '0'
                    ? act.customerId.trim()
                    : (act.businessName.trim().isNotEmpty
                        ? act.businessName.trim().toLowerCase()
                        : act.customerName.trim().toLowerCase());
                if (seenCustomerKeys.add(custKey)) {
                  uniqueColors.add(resolveCustomerColor(act));
                }
              }
              final int extraCount = uniqueColors.length > 3
                  ? uniqueColors.length - 3
                  : 0;
              final displayedColors = uniqueColors.take(3).toList();

              final weekdayName = _weekdays[date.weekday - 1];
              final cardWidth = screenWidth < 360 ? 52.0 : 58.0;

              return InkWell(
                onTap: () {
                  ref
                      .read(employeeCalendarSelectedDateProvider.notifier)
                      .setDate(date);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: cardWidth,
                  padding: const EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryDark
                          : isToday
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : const Color(0xFFE2E8F0),
                      width: isToday && !isSelected ? 1.5 : 1,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: AppColors.primaryDark.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      else
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        weekdayName,
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${date.day}',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (displayedColors.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...displayedColors.map((color) {
                              return Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: Colors.white,
                                          width: 0.5,
                                        )
                                      : null,
                                ),
                              );
                            }),
                            if (extraCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: 1),
                                child: Text(
                                  '+$extraCount',
                                  style: TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    height: 1,
                                  ),
                                ),
                              ),
                          ],
                        )
                      else if (scheduledDates.contains(normalizedDate))
                        Container(
                          width: 4.5,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 0.5)
                                : null,
                          ),
                        )
                      else
                        const SizedBox(height: 5),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Selected Date Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${_selectedDate.day} ${_getMonthName(_selectedDate.month).toUpperCase()} ${_selectedDate.year}',
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (_selectedDate.year == today.year &&
                _selectedDate.month == today.month &&
                _selectedDate.day == today.day)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'TODAY',
                  style: GoogleFonts.outfit(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // 5. Selected Date Activities List (4 Distinct UI States)
        if (liveDateAsync.isLoading)
          Column(
            children: const [
              SkeletonCard(),
              SkeletonCard(),
            ],
          )
        else if (liveDateAsync.hasError)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Unable to load activities.',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    ref.invalidate(
                      employeeCalendarActivitiesForDateProvider(
                        selectedDateStr,
                      ),
                    );
                    ref.invalidate(
                      employeeCalendarActivitiesFor7DayWindowProvider(
                        startDateStr,
                      ),
                    );
                    ref.invalidate(
                      employeeCalendarActivitiesForMonthProvider(monthStr),
                    );
                  },
                  icon: const Icon(
                    Remix.refresh_line,
                    size: 14,
                    color: AppColors.primaryDark,
                  ),
                  label: Text(
                    'Retry',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (selectedDateActivities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                'No activities scheduled for this date.',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: selectedDateActivities.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final act = selectedDateActivities[idx];

              return InkWell(
                key: ValueKey('emp_home_act_${act.id}_$idx'),
                onTap: () => EmployeeActivityDetailSheet.show(context, act),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.015),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: resolveTaskBgColor(act),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            resolveTaskCategory(act).icon,
                            color: resolveTaskColor(act),
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resolveActivityDisplayName(act),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Builder(
                              builder: (context) {
                                final custName = act.businessName.trim().isNotEmpty
                                    ? act.businessName.trim()
                                    : act.customerName.trim();
                                final customerColor = resolveCustomerColor(act);
                                return Row(
                                  children: [
                                    if (custName.isNotEmpty) ...[
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(right: 5),
                                        decoration: BoxDecoration(
                                          color: customerColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                    Expanded(
                                      child: Text(
                                        custName.isNotEmpty
                                            ? '$custName • ${act.time}'
                                            : act.time,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );
                              },
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
                          color: act.statusBgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          act.status,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: act.statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
