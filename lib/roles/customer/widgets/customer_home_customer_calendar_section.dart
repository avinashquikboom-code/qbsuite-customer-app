import 'package:material_ui/material_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/company_admin_models.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/current_customer_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_subscription_viewmodel.dart';
import 'package:quickboom_company_admin/roles/company_admin/views/calendar/admin_customer_calendar_view.dart';
import 'customer_activity_detail_sheet.dart';

class CustomerHomeCustomerCalendarSection extends ConsumerStatefulWidget {
  const CustomerHomeCustomerCalendarSection({super.key});

  @override
  ConsumerState<CustomerHomeCustomerCalendarSection> createState() =>
      _CustomerHomeCustomerCalendarSectionState();
}

class _CustomerHomeCustomerCalendarSectionState
    extends ConsumerState<CustomerHomeCustomerCalendarSection> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  static const List<String> _filterOptions = [
    'All',
    'Reels Shoot',
    'Video Editing',
    'Post Design',
    'Story Design',
    'Posting',
  ];

  static const List<String> _weekdays = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  bool _matchesFilter(CustomerCalendarActivity activity, String filter) {
    if (!activity.isValidCustomerFacingSchedule) return false;
    if (filter == 'All') return true;
    final taskCat = resolveTaskCategory(activity);

    if (filter == 'Reels Shoot') {
      return taskCat == TaskCategory.reelShoot ||
          taskCat == TaskCategory.videoShoot;
    } else if (filter == 'Video Editing') {
      return taskCat == TaskCategory.videoEditing;
    } else if (filter == 'Post Design') {
      return taskCat == TaskCategory.postDesign;
    } else if (filter == 'Story Design') {
      return taskCat == TaskCategory.storyDesign;
    } else if (filter == 'Posting' || filter == 'Uploading') {
      return taskCat == TaskCategory.reelPost ||
          taskCat == TaskCategory.storyPost ||
          taskCat == TaskCategory.postPublish;
    }

    final notes = (activity.notes ?? '').toLowerCase();
    final label = activity.activityType.label.toLowerCase();
    final title = (activity.title ?? '').toLowerCase();
    final planName = (activity.planName ?? '').toLowerCase();
    final filterLower = filter.toLowerCase();

    return notes.contains(filterLower) ||
        label.contains(filterLower) ||
        title.contains(filterLower) ||
        planName.contains(filterLower);
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

  Widget _buildFilterChip(
    String filter,
    bool isSelected, {
    bool isTablet = false,
  }) {
    return InkWell(
      onTap: () {
        ref.read(customerSelectedWorkFilterProvider.notifier).setFilter(filter);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 32 : 14,
          vertical: isTablet ? 8 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            filter,
            style: GoogleFonts.outfit(
              fontSize: isTablet ? 15 : 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateCard(
    DateTime date,
    bool isSelected,
    bool isToday,
    List<Color> displayedColors,
    int extraCount,
    String weekdayName,
  ) {
    return InkWell(
      onTap: () {
        ref.read(customerCalendarSelectedDateProvider.notifier).setDate(date);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
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
                color: isSelected ? Colors.white : AppColors.textPrimary,
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
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 0.5)
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
            else
              const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  String _getCalendarErrorMessage(dynamic error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 403) {
        final data = error.response?.data;
        if (data is Map && data['message'] != null) {
          return data['message'].toString();
        }
        return 'Cross-customer access forbidden';
      }
      if (statusCode == 401) {
        return 'Session expired. Please log in again.';
      }
      final msg = error.response?.data is Map
          ? error.response?.data['message']?.toString()
          : null;
      if (msg != null && msg.isNotEmpty) {
        return msg;
      }
    }
    final errStr = error?.toString() ?? '';
    if (errStr.contains('403') || errStr.toLowerCase().contains('forbidden')) {
      if (errStr.contains('Cross-customer access forbidden')) {
        return 'Cross-customer access forbidden';
      }
      return 'Access forbidden: You do not have permission to view this calendar.';
    }
    return 'Unable to load activities.';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final globalSelectedDate = ref.watch(customerCalendarSelectedDateProvider);
    _selectedDate = globalSelectedDate;

    final customerIdAsync = ref.watch(currentCustomerIdProvider);
    final customerId =
        customerIdAsync.asData?.value ?? customerIdAsync.value ?? '';
    final selectedFilter = ref.watch(customerSelectedWorkFilterProvider);

    final effectivePlanAsync = ref.watch(customerEffectivePlanProvider);
    final effectivePlan = effectivePlanAsync.asData?.value;
    final currentSubAsync = ref.watch(currentSubscriptionProvider);
    final currentSub = currentSubAsync.asData?.value;

    final monthStr =
        '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}';
    final monthSummary = ref.watch(
      customerCalendarPlanSummaryProvider(monthStr),
    );

    final isPlanLoading =
        (effectivePlanAsync.isLoading || currentSubAsync.isLoading) &&
        effectivePlan == null &&
        currentSub == null;

    final int totalWork;
    final int completedWork;
    final int remainingWork;

    if (monthSummary.total > 0) {
      totalWork = monthSummary.total;
      completedWork = monthSummary.completed;
      remainingWork = monthSummary.remaining;
    } else if (effectivePlan != null &&
        ((effectivePlan.quotas['scheduleLimit'] as num?)?.toInt() ?? 0) > 0) {
      totalWork = (effectivePlan.quotas['scheduleLimit'] as num).toInt();
      completedWork =
          (effectivePlan.quotas['usedSchedules'] as num?)?.toInt() ?? 0;
      remainingWork =
          (effectivePlan.quotas['remainingSchedules'] as num?)?.toInt() ??
          (totalWork > completedWork ? totalWork - completedWork : 0);
    } else {
      totalWork = 0;
      completedWork = 0;
      remainingWork = 0;
    }

    final String planName;
    if (isPlanLoading) {
      planName = 'Loading Plan...';
    } else if (effectivePlan != null && effectivePlan.name.isNotEmpty) {
      planName = effectivePlan.name;
    } else if (currentSub != null &&
        currentSub.isPurchasedPlanVisible &&
        currentSub.planName.isNotEmpty) {
      planName = currentSub.planName;
    } else {
      planName = 'No Active Plan';
    }

    final selectedNormalized = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final startDate = selectedNormalized.subtract(const Duration(days: 3));
    final dates = List.generate(
      7,
      (index) => startDate.add(Duration(days: index)),
    );

    final startDateStr =
        '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final selectedDateStr = normalizeDate(_selectedDate);

    final live7DayAsync = ref.watch(
      customerCalendarActivitiesFor7DayWindowProvider(startDateStr),
    );
    final liveDateAsync = ref.watch(
      customerCalendarActivitiesForDateProvider(selectedDateStr),
    );
    final liveMonthAsync = ref.watch(
      customerCalendarActivitiesForMonthProvider(monthStr),
    );

    final raw7DayActivities =
        live7DayAsync.asData?.value ?? const <CustomerCalendarActivity>[];
    final rawDateActivities =
        liveDateAsync.asData?.value ?? const <CustomerCalendarActivity>[];
    final rawMonthActivities =
        liveMonthAsync.asData?.value ?? const <CustomerCalendarActivity>[];

    // Use each parsed activity date as the single source for calendar dots.
    final Map<String, List<CustomerCalendarActivity>> dateActivityMap = {};
    for (final a in rawMonthActivities) {
      if (a.isValidCustomerFacingSchedule) {
        final key = normalizeDate(a.date);
        dateActivityMap.putIfAbsent(key, () => []).add(a);
      }
    }
    for (final a in raw7DayActivities) {
      if (a.isValidCustomerFacingSchedule) {
        final key = normalizeDate(a.date);
        final list = dateActivityMap.putIfAbsent(key, () => []);
        if (!list.any((existing) => existing.id == a.id)) {
          list.add(a);
        }
      }
    }
    for (final a in rawDateActivities) {
      if (a.isValidCustomerFacingSchedule) {
        final key = normalizeDate(a.date);
        final list = dateActivityMap.putIfAbsent(key, () => []);
        if (!list.any((existing) => existing.id == a.id)) {
          list.add(a);
        }
      }
    }

    // Selected date activities: strictly for selectedDateStr
    final List<CustomerCalendarActivity> rawMatchingDateActivities =
        rawDateActivities.isNotEmpty
        ? rawDateActivities
        : (liveDateAsync.hasError
              ? const <CustomerCalendarActivity>[]
              : (dateActivityMap[selectedDateStr] ??
                    const <CustomerCalendarActivity>[]));

    // Deduplicate safety layer
    final matchingSelectedDateActivities = deduplicateCustomerActivities(
      rawMatchingDateActivities,
    );

    final selectedDateActivities = matchingSelectedDateActivities
        .where((a) => _matchesFilter(a, selectedFilter))
        .toList();

    debugPrint(
      '[CALENDAR] Selected date: $selectedDateStr | Activities count: ${selectedDateActivities.length}',
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
                'CUSTOMER CALENDAR',
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
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminCustomerCalendarView(
                      initialDate: _selectedDate,
                      isCustomerScope: true,
                      customerId: customerId,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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

        // 2. Plan-based Schedule Usage & Limit Quota Card
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
                            Remix.vip_crown_fill,
                            size: 13,
                            color: AppColors.primaryDark,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              planName,
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
                      '$remainingWork Remaining',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: remainingWork > 0
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
                      '$completedWork/$totalWork Schedules Done',
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
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 3. Horizontal 7-Day Date Strip with Multi-Category Indicators
        SizedBox(
          height: 74,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth >= 550;

              List<Widget> dateWidgets = List.generate(dates.length, (index) {
                final date = dates[index];
                final isSelected =
                    date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;

                final isToday =
                    date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final dateKey = normalizeDate(date);
                final matchingDateActivities =
                    dateActivityMap[dateKey] ??
                    const <CustomerCalendarActivity>[];

                // Extract unique activity category colors for this date (up to 3 + overflow indicator)
                final uniqueColors = <Color>[];
                final seenCategories = <TaskCategory>{};
                for (final act in matchingDateActivities) {
                  final cat = resolveTaskCategory(act);
                  if (seenCategories.add(cat)) {
                    uniqueColors.add(resolveTaskColor(act));
                  }
                }
                final int extraCount = uniqueColors.length > 3
                    ? uniqueColors.length - 3
                    : 0;
                final displayedColors = uniqueColors.take(3).toList();
                final weekdayName = _weekdays[date.weekday - 1];

                return _buildDateCard(
                  date,
                  isSelected,
                  isToday,
                  displayedColors,
                  extraCount,
                  weekdayName,
                );
              });

              if (isTablet) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: dateWidgets,
                );
              }

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: dateWidgets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => dateWidgets[index],
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // 4. Activity Filter Chip List:
        // Tablet+ wraps responsively across the calendar content width;
        // mobile keeps the horizontal scrolling strip.
        LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 550;
            if (isTablet) {
              return Wrap(
                spacing: 8,
                runSpacing: 10,
                children: List.generate(_filterOptions.length, (index) {
                  final filter = _filterOptions[index];
                  final isSelected = selectedFilter == filter;
                  return _buildFilterChip(filter, isSelected, isTablet: true);
                }),
              );
            }

            return SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _filterOptions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filterOptions[index];
                  final isSelected = selectedFilter == filter;
                  return _buildFilterChip(filter, isSelected);
                },
              ),
            );
          },
        ),

        const SizedBox(height: 12),

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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Loading activities...',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
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
                  _getCalendarErrorMessage(liveDateAsync.error),
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    ref.invalidate(
                      customerCalendarActivitiesForDateProvider(
                        selectedDateStr,
                      ),
                    );
                    ref.invalidate(
                      customerCalendarActivitiesFor7DayWindowProvider(
                        startDateStr,
                      ),
                    );
                    ref.invalidate(
                      customerCalendarActivitiesForMonthProvider(monthStr),
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
                'No customer activities scheduled for this date.',
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
              final category = resolveTaskCategory(act);
              final taskColor = resolveTaskColor(act);
              final actDateNormalized =
                  '${act.date.year.toString().padLeft(4, '0')}-${act.date.month.toString().padLeft(2, '0')}-${act.date.day.toString().padLeft(2, '0')}';

              debugPrint('[CUSTOMER_TASK_RENDER]');
              debugPrint('id: ${act.id}');
              debugPrint('title: ${act.title ?? act.notes}');
              debugPrint('type: ${act.type}');
              debugPrint('date: $actDateNormalized');
              debugPrint('selectedDate: $selectedDateStr');
              debugPrint('matched: true');
              debugPrint('category: ${category.key}');
              debugPrint('color: $taskColor');

              final isLocked =
                  act.status.toUpperCase() == 'LOCKED' ||
                  (act.notes ?? '').contains(
                    'second installation schedule will be available',
                  ) ||
                  (act.notes ?? '').contains('Schedule Locked');

              if (isLocked) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(
                                Remix.lock_2_fill,
                                size: 16,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Schedule Locked',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        act.notes?.isNotEmpty == true &&
                                !act.notes!.contains('Schedule Locked')
                            ? act.notes!
                            : 'Complete the remaining 50% payment for the upcoming second installation.',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: const Color(0xFFB45309),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return InkWell(
                key: ValueKey(
                  'home_cal_act_${act.id.isNotEmpty ? act.id : "${actDateNormalized}_${act.title}"}',
                ),
                onTap: () => CustomerActivityDetailSheet.show(context, act),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            Text(
                              act.time.isEmpty ? 'Time not set' : act.time,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              calendarAssigneeLabel(act),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              softWrap: true,
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
