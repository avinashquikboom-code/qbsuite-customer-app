import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/company_admin_models.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_calendar_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/employee_activity_detail_sheet.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/employee_my_work_card.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';

/// Employee Calendar Screen.
/// Displays work and tasks scheduled for the authenticated employee,
/// matching the Customer Calendar UI and behavior.
class EmployeeScheduleView extends ConsumerStatefulWidget {
  final bool showBackButton;
  final VoidCallback? onBack;

  const EmployeeScheduleView({
    super.key,
    this.showBackButton = true,
    this.onBack,
  });

  @override
  ConsumerState<EmployeeScheduleView> createState() =>
      _EmployeeScheduleViewState();
}

class _EmployeeScheduleViewState extends ConsumerState<EmployeeScheduleView> {
  late DateTime _displayedMonth;
  bool _isWeekView = false;
  final TextEditingController _searchCtrl = TextEditingController();

  static const List<String> _weekdays = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Schedules can be created by the customer calendar after our previous visit.
      // Reuse the existing refresh path instead of displaying its cached empty result.
      _refreshData().catchError((Object error) {
        // Provider error states are rendered by the existing calendar error UI.
        debugPrint('[EMPLOYEE_CALENDAR] Entry refresh failed: $error');
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        1,
      );
    });
  }

  void _previousWeek() {
    final selectedDate = ref.read(employeeCalendarSelectedDateProvider);
    final newDate = selectedDate.subtract(const Duration(days: 7));
    ref.read(employeeCalendarSelectedDateProvider.notifier).setDate(newDate);
    if (newDate.month != _displayedMonth.month ||
        newDate.year != _displayedMonth.year) {
      setState(() {
        _displayedMonth = DateTime(newDate.year, newDate.month, 1);
      });
    }
  }

  void _nextWeek() {
    final selectedDate = ref.read(employeeCalendarSelectedDateProvider);
    final newDate = selectedDate.add(const Duration(days: 7));
    ref.read(employeeCalendarSelectedDateProvider.notifier).setDate(newDate);
    if (newDate.month != _displayedMonth.month ||
        newDate.year != _displayedMonth.year) {
      setState(() {
        _displayedMonth = DateTime(newDate.year, newDate.month, 1);
      });
    }
  }

  Future<void> _refreshData() async {
    final selectedDate = ref.read(employeeCalendarSelectedDateProvider);
    final dateStr = normalizeDate(selectedDate);
    final monthStr =
        '${_displayedMonth.year.toString().padLeft(4, '0')}-${_displayedMonth.month.toString().padLeft(2, '0')}';

    ref.invalidate(employeeCalendarActivitiesForDateProvider(dateStr));
    ref.invalidate(employeeCalendarActivitiesForMonthProvider(monthStr));
    final weekStart = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day - (selectedDate.weekday - 1),
    );
    ref.invalidate(
      employeeCalendarActivitiesFor7DayWindowProvider(normalizeDate(weekStart)),
    );
    await Future.wait([
      ref.read(employeeCalendarActivitiesForDateProvider(dateStr).future),
      ref.read(employeeCalendarActivitiesForMonthProvider(monthStr).future),
      if (_isWeekView)
        ref.read(
          employeeCalendarActivitiesFor7DayWindowProvider(
            normalizeDate(weekStart),
          ).future,
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(employeeCalendarSelectedDateProvider);
    final rbacPerms = ref.watch(permissionManagerProvider);

    final mediaQuery = MediaQuery.maybeOf(context);
    final devWidth = mediaQuery?.size.width ?? 0;
    final devHeight = mediaQuery?.size.height ?? 0;
    final devPixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    final devTimezone = DateTime.now().timeZoneName;

    debugPrint(
      '[CALENDAR_VISIBILITY_DEBUG] EmployeeScheduleView -> '
      'deviceWidth: $devWidth, '
      'deviceHeight: $devHeight, '
      'pixelRatio: $devPixelRatio, '
      'timezone: $devTimezone, '
      'canViewCalendar: ${rbacPerms.canViewCalendar}, '
      'role: ${rbacPerms.role}',
    );

    final selectedDateStr = normalizeDate(selectedDate);
    final displayedMonthStr =
        '${_displayedMonth.year.toString().padLeft(4, '0')}-${_displayedMonth.month.toString().padLeft(2, '0')}';

    final startOfWeek = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day - (selectedDate.weekday - 1),
    );
    final weekActivitiesAsync = _isWeekView
        ? ref.watch(
            employeeCalendarActivitiesFor7DayWindowProvider(
              normalizeDate(startOfWeek),
            ),
          )
        : null;

    // Watch month activities for calendar dots and dateActivityMap
    final monthActivitiesAsync = ref.watch(
      employeeCalendarActivitiesForMonthProvider(displayedMonthStr),
    );
    final dateActivitiesAsync = ref.watch(
      employeeCalendarActivitiesForDateProvider(selectedDateStr),
    );

    final rawMonthActivities =
        monthActivitiesAsync.asData?.value ??
        const <CustomerCalendarActivity>[];
    final rawDateActivities =
        dateActivitiesAsync.asData?.value ?? const <CustomerCalendarActivity>[];

    // Build map for calendar dots: YYYY-MM-DD -> List<CustomerCalendarActivity>
    final Map<String, List<CustomerCalendarActivity>> dateActivityMap = {};
    for (final a in rawMonthActivities) {
      final key = getScheduledDateString(a);
      dateActivityMap.putIfAbsent(key, () => []).add(a);
    }
    final rawWeekActivities =
        weekActivitiesAsync?.asData?.value ??
        const <CustomerCalendarActivity>[];
    for (final a in [...rawWeekActivities, ...rawDateActivities]) {
      final key = getScheduledDateString(a);
      final list = dateActivityMap.putIfAbsent(key, () => []);
      if (!list.any((existing) => existing.id == a.id && existing.type == a.type)) {
        list.add(a);
      }
    }

    // Determine activities for selected date, merging month, week, and date-specific fetches
    final List<CustomerCalendarActivity> rawSelectedActivities =
        deduplicateCustomerActivities([
          ...?dateActivityMap[selectedDateStr],
          ...rawDateActivities,
        ]);

    // Apply search query filter
    final searchQuery = _searchCtrl.text.trim().toLowerCase();
    final filteredActivities = rawSelectedActivities.where((activity) {
      if (searchQuery.isEmpty) return true;

      final title = (activity.title ?? '').toLowerCase();
      final customer = activity.customerName.toLowerCase();
      final business = activity.businessName.toLowerCase();
      final notes = (activity.notes ?? '').toLowerCase();
      final service = (activity.serviceName ?? '').toLowerCase();
      final location = (activity.location ?? '').toLowerCase();
      final team = (activity.team ?? '').toLowerCase();
      final category = resolveTaskCategory(activity).label.toLowerCase();

      return title.contains(searchQuery) ||
          customer.contains(searchQuery) ||
          business.contains(searchQuery) ||
          notes.contains(searchQuery) ||
          service.contains(searchQuery) ||
          location.contains(searchQuery) ||
          team.contains(searchQuery) ||
          category.contains(searchQuery);
    }).toList();

    debugPrint(
      '[EMPLOYEE_CALENDAR_VIEW_DEBUG] '
      'selectedDate: $selectedDateStr, '
      'month: $displayedMonthStr, '
      'monthCount: ${rawMonthActivities.length}, '
      'dateCount: ${rawDateActivities.length}, '
      'weekCount: ${rawWeekActivities.length}, '
      'selectedCount: ${rawSelectedActivities.length}, '
      'filteredCount: ${filteredActivities.length}, '
      'isWeekView: $_isWeekView',
    );

    final weekDays = List.generate(
      7,
      (i) => DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i),
    );

    // Calendar grid calculations
    final firstDayOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    // Monday = 1, Sunday = 7 -> Monday offset = 0
    final firstDayOffset = (firstDayOfMonth.weekday - 1) % 7;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isSelectedDateToday =
        selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppAppBar(
        title: 'My Calendar',
        showBackButton: widget.showBackButton,
        onBack: widget.onBack,
        actions: [
          IconButton(
            icon: const Icon(Remix.refresh_line, color: AppColors.textPrimary),
            tooltip: 'Refresh Calendar',
            onPressed: _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search customer, task, service, location...',
                    hintStyle: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Remix.search_2_line,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Remix.close_circle_fill,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Month / Week Calendar Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Navigator Header with Month/Week View Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: _isWeekView
                                  ? _previousWeek
                                  : _previousMonth,
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Remix.arrow_left_s_line,
                                  size: 20,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _isWeekView
                                  ? '${_getMonthName(weekDays.first.month).substring(0, 3)} ${weekDays.first.day} – ${_getMonthName(weekDays.last.month).substring(0, 3)} ${weekDays.last.day}'
                                  : '${_getMonthName(_displayedMonth.month)} ${_displayedMonth.year}',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 2),
                            InkWell(
                              onTap: _isWeekView ? _nextWeek : _nextMonth,
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Remix.arrow_right_s_line,
                                  size: 20,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Month / Week Segmented Switch
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildViewPill('Month', !_isWeekView, () {
                                if (_isWeekView) {
                                  setState(() => _isWeekView = false);
                                }
                              }),
                              _buildViewPill('Week', _isWeekView, () {
                                if (!_isWeekView) {
                                  setState(() => _isWeekView = true);
                                }
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),

                    // Weekday Header
                    Row(
                      children: _weekdays.asMap().entries.map((entry) {
                        final dayIndex = entry.key + 1; // 1 = MON, 7 = SUN
                        final isSelectedWeekday =
                            selectedDate.weekday == dayIndex;
                        return Expanded(
                          child: Center(
                            child: Text(
                              entry.value,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelectedWeekday
                                    ? AppColors.primary
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 8),

                    // 7-Column Days Grid (Month or Week)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _isWeekView
                          ? 7
                          : (daysInMonth + firstDayOffset),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: devWidth < 360 ? 0.85 : 0.95,
                      ),
                      itemBuilder: (context, index) {
                        if (!_isWeekView && index < firstDayOffset) {
                          return const SizedBox();
                        }
                        final date = _isWeekView
                            ? weekDays[index]
                            : DateTime(
                                _displayedMonth.year,
                                _displayedMonth.month,
                                index - firstDayOffset + 1,
                              );
                        final dayNum = date.day;

                        final isSelected =
                            date.year == selectedDate.year &&
                            date.month == selectedDate.month &&
                            date.day == selectedDate.day;

                        final isDayToday =
                            date.year == today.year &&
                            date.month == today.month &&
                            date.day == today.day;

                        final dateKey = normalizeDate(date);
                        final matchingActs =
                            dateActivityMap[dateKey] ??
                            const <CustomerCalendarActivity>[];

                        // Extract unique customer colors for indicator dots (up to 3 + overflow indicator)
                        final uniqueColors = <Color>[];
                        final seenCustomerKeys = <String>{};
                        for (final act in matchingActs) {
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

                        return InkWell(
                          onTap: () {
                            ref
                                .read(
                                  employeeCalendarSelectedDateProvider.notifier,
                                )
                                .setDate(date);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDayToday
                                          ? AppColors.primary.withValues(
                                              alpha: 0.5,
                                            )
                                          : Colors.transparent),
                                width: isDayToday && !isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$dayNum',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : (isDayToday
                                              ? FontWeight.w700
                                              : FontWeight.w500),
                                    color: isSelected
                                        ? Colors.white
                                        : (isDayToday
                                              ? AppColors.primaryDark
                                              : AppColors.textPrimary),
                                  ),
                                ),
                                const SizedBox(height: 3),
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
                                          padding: const EdgeInsets.only(
                                            left: 1,
                                          ),
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
                                  const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '${selectedDate.day} ${_getMonthName(selectedDate.month).toUpperCase()} ${selectedDate.year} · ',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'ASSIGNED TASKS (${filteredActivities.length})',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelectedDateToday)
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
                        'TODAY',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // 5. Scheduled Activities List
              if (dateActivitiesAsync.isLoading && filteredActivities.isEmpty)
                _buildLoadingSkeletons()
              else if (dateActivitiesAsync.hasError &&
                  filteredActivities.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Remix.error_warning_line,
                        size: 36,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dateActivitiesAsync.error?.toString().contains('403') ==
                                true
                            ? 'Calendar Access Restricted (403)'
                            : (dateActivitiesAsync.error?.toString().contains(
                                        '401',
                                      ) ==
                                      true
                                  ? 'Session Expired (401)'
                                  : 'Unable to load your schedule'),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dateActivitiesAsync.error?.toString().contains('403') ==
                                true
                            ? 'Your current role or permissions do not allow viewing this calendar. Please contact your administrator.'
                            : (dateActivitiesAsync.error?.toString().contains(
                                        '401',
                                      ) ==
                                      true
                                  ? 'Please log out and log in again to refresh your session.'
                                  : 'Check your internet connection and try again.'),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      if (dateActivitiesAsync.error?.toString().contains(
                            '403',
                          ) !=
                          true)
                        TextButton(
                          onPressed: _refreshData,
                          child: Text(
                            'Retry',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else if (filteredActivities.isEmpty)
                searchQuery.isNotEmpty
                    ? _buildSearchEmptyState()
                    : _buildDateEmptyState(selectedDate)
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredActivities.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final activity = filteredActivities[index];
                    return _buildEmployeeActivityCard(context, activity);
                  },
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeletons() {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          margin: EdgeInsets.only(bottom: index == 2 ? 0 : 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSearchEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Remix.search_2_line, size: 40, color: Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(
            'No matching tasks',
            style: GoogleFonts.outfit(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search or category for this date.',
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDateEmptyState(DateTime selectedDate) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(
            Remix.calendar_check_line,
            size: 44,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 10),
          Text(
            'No assigned work for this date',
            style: GoogleFonts.outfit(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'When you are scheduled or assigned work, it will appear here.',
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _taskTimeRange(CustomerCalendarActivity activity) {
    final start = (activity.startTime ?? activity.time).trim();
    final end = (activity.endTime ?? '').trim();
    if (start.isNotEmpty && end.isNotEmpty && start != end) {
      return '$start – $end';
    }
    if (start.isNotEmpty) return start;
    return 'Scheduled';
  }

  ({Color color, Color bg}) _statusStyle(CustomerCalendarActivity activity) {
    final status = activity.status.toUpperCase();
    if (activity.isCarriedForward &&
        status != 'COMPLETED' &&
        status != 'APPROVED') {
      return (color: const Color(0xFFD97706), bg: const Color(0xFFFEF3C7));
    }
    if (status.contains('PROGRESS')) {
      return (color: const Color(0xFF16A34A), bg: const Color(0xFFDCFCE7));
    }
    if (status.contains('ASSIGN')) {
      return (color: const Color(0xFF2563EB), bg: const Color(0xFFDBEAFE));
    }
    if (status.contains('REVIEW') || status.contains('REVISION')) {
      return (color: const Color(0xFF9333EA), bg: const Color(0xFFF3E8FF));
    }
    if (status.contains('COMPLETE') ||
        status.contains('APPROVE') ||
        status == 'DONE') {
      return (color: const Color(0xFF166534), bg: const Color(0xFFDCFCE7));
    }
    if (status.contains('PEND') || status.contains('SCHEDULE')) {
      return (color: const Color(0xFFD97706), bg: const Color(0xFFFEF3C7));
    }
    return (color: activity.statusColor, bg: activity.statusBgColor);
  }

  Widget _buildEmployeeActivityCard(
    BuildContext context,
    CustomerCalendarActivity activity,
  ) {
    final catColor = resolveTaskColor(activity);
    final catBgColor = resolveTaskBgColor(activity);
    final category = resolveTaskCategory(activity);
    final displayName = resolveActivityDisplayName(activity);
    final customerColor = resolveCustomerColor(activity);
    final customerName = activity.businessName.trim().isNotEmpty
        ? activity.businessName.trim()
        : activity.customerName.trim();
    final location = activity.location?.trim() ?? '';
    final statusStyle = _statusStyle(activity);
    final statusLabel =
        activity.isCarriedForward &&
            activity.status.toUpperCase() != 'COMPLETED' &&
            activity.status.toUpperCase() != 'APPROVED'
        ? 'CARRIED FORWARD'
        : activity.status.toUpperCase();

    return Material(
      key: ValueKey('activity_${activity.id}'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => EmployeeActivityDetailSheet.show(context, activity),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: catBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, size: 20, color: catColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (customerName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: customerColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              customerName,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Remix.calendar_event_line,
                          size: 13,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${formatActivityDate(activity.date)} • ${_taskTimeRange(activity)}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (activity.team != null &&
                        activity.team!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Remix.team_line,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Team: ${activity.team!.trim()}',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF475569),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ] else if (activity.assignedEmployee.trim().isNotEmpty &&
                        activity.assignedEmployee.trim() != '—' &&
                        activity.assignedEmployee.trim().toLowerCase() !=
                            'not assigned' &&
                        activity.assignedEmployee.trim().toLowerCase() !=
                            'unassigned') ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Remix.user_3_line,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Assigned: ${activity.assignedEmployee.trim()}',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF475569),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Remix.map_pin_2_line,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (activity.notes != null &&
                        activity.notes!.trim().isNotEmpty &&
                        activity.notes!.trim().toLowerCase() !=
                            displayName.toLowerCase()) ...[
                      const SizedBox(height: 5),
                      Text(
                        activity.notes!.trim(),
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: catBgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category.label,
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: catColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusStyle.bg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: statusStyle.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(
                  Remix.arrow_right_s_line,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewPill(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
