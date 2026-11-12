import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/utils/app_date_formatter.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import '../../models/employee_attendance_model.dart';
import '../../viewmodels/employee_attendance_viewmodel.dart';
import '../../widgets/overtime_panel.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';

/// Redesigned modern, clean & production-ready Attendance Log screen
/// for Employee Mobile with real data, filters, and summary metrics.
class AttendanceView extends ConsumerStatefulWidget {
  final bool? showBackButton;

  const AttendanceView({super.key, this.showBackButton});

  @override
  ConsumerState<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends ConsumerState<AttendanceView> {
  static const List<String> _months = [
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

  late int _selectedMonth;
  late int _selectedYear;
  String _selectedStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(employeeAttendanceProvider.notifier).loadHistory();
      ref.read(employeeAttendanceProvider.notifier).loadStatus();
    });
  }

  bool get _isFilterActive {
    final now = DateTime.now();
    return _selectedMonth != now.month ||
        _selectedYear != now.year ||
        _selectedStatus != 'ALL';
  }

  void _resetFilters() {
    final now = DateTime.now();
    setState(() {
      _selectedMonth = now.month;
      _selectedYear = now.year;
      _selectedStatus = 'ALL';
    });
  }

  /// Match log against selected month and year
  bool _matchesMonthYear(AttendanceLogItem log, int month, int year) {
    if (log.parsedDate != null) {
      return log.parsedDate!.month == month && log.parsedDate!.year == year;
    }
    final parsed = DateTime.tryParse(log.date);
    if (parsed != null) {
      return parsed.month == month && parsed.year == year;
    }
    const shortMonths = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    final lower = log.date.toLowerCase();
    if (lower.contains(shortMonths[month - 1]) && lower.contains('$year')) {
      return true;
    }
    return false;
  }

  /// Calculate working days in a month (Mon-Sat, excluding Sundays)
  int _calculateWorkingDays(int year, int month) {
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    int workingDays = 0;
    for (int day = 1; day <= daysInMonth; day++) {
      final dt = DateTime(year, month, day);
      if (dt.weekday != DateTime.sunday) {
        workingDays++;
      }
    }
    return workingDays;
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(employeeAttendanceProvider);
    final allLogs = AttendanceLogItem.consolidateDaily(
      attendanceState.historyLogs,
    );

    // Filter logs by selected Month & Year
    final monthLogs = allLogs.where((log) {
      return _matchesMonthYear(log, _selectedMonth, _selectedYear);
    }).toList();

    // Summary calculations from real attendance data for the selected month
    final presentCount = monthLogs.where((l) {
      final s = l.status.toUpperCase();
      return (s == 'PRESENT' || s == 'ON_TIME') && !l.isLate;
    }).length;

    final lateCount = monthLogs.where((l) {
      return l.isLate || l.status.toUpperCase() == 'LATE';
    }).length;

    final halfDayCount = monthLogs.where((l) {
      final s = l.status.toUpperCase();
      return s.contains('HALF');
    }).length;

    final absentCount = monthLogs.where((l) {
      return l.status.toUpperCase() == 'ABSENT';
    }).length;

    final int calculatedMonthWorkingDays = _calculateWorkingDays(
      _selectedYear,
      _selectedMonth,
    );
    final int totalWorkingDays = monthLogs.length > calculatedMonthWorkingDays
        ? monthLogs.length
        : calculatedMonthWorkingDays;

    // Filter by selected Status
    final filteredLogs = monthLogs.where((log) {
      if (_selectedStatus == 'ALL') return true;
      final s = log.status.toUpperCase();
      if (_selectedStatus == 'PRESENT') {
        return (s == 'PRESENT' || s == 'ON_TIME') && !log.isLate;
      }
      if (_selectedStatus == 'LATE') {
        return log.isLate || s == 'LATE';
      }
      if (_selectedStatus == 'HALF_DAY') {
        return s.contains('HALF');
      }
      if (_selectedStatus == 'ABSENT') {
        return s == 'ABSENT';
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppAppBar(
        title: 'Attendance Log',
        showBackButton: widget.showBackButton ?? true,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await ref.read(employeeAttendanceProvider.notifier).loadHistory();
          await ref.read(employeeAttendanceProvider.notifier).loadStatus();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Attendance Summary Cards (Real Data)
              _buildAttendanceSummary(
                present: presentCount,
                absent: absentCount,
                late: lateCount,
                halfDay: halfDayCount,
                totalWorkingDays: totalWorkingDays,
              ),
              const SizedBox(height: 16),
              const OvertimeLogSection(),

              // 3. Modern Filter Section (Month, Year, Status & Reset)
              _buildFilterSection(
                allCount: monthLogs.length,
                presentCount: presentCount,
                lateCount: lateCount,
                halfDayCount: halfDayCount,
                absentCount: absentCount,
              ),
              const SizedBox(height: 16),

              // 4. Section Title & Results Count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attendance Records',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${filteredLogs.length} ${filteredLogs.length == 1 ? "Record" : "Records"}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 5. Attendance Log List with Loading / Error / Empty State
              if (attendanceState.isHistoryLoading && allLogs.isEmpty)
                _buildLoadingState()
              else if (attendanceState.pageError != null && allLogs.isEmpty)
                _buildErrorState(attendanceState.pageError!)
              else if (filteredLogs.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredLogs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildLogCard(filteredLogs[index]);
                  },
                ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. ATTENDANCE SUMMARY METRICS ──────────────────────────────────────────
  Widget _buildAttendanceSummary({
    required int present,
    required int absent,
    required int late,
    required int halfDay,
    required int totalWorkingDays,
  }) {
    return Column(
      children: [
        // Row 1: Total Working Days & Present
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Total Working Days',
                value: '$totalWorkingDays',
                unit: 'Days',
                icon: Remix.calendar_check_line,
                color: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFEFF6FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                title: 'Present',
                value: '$present',
                unit: 'Days',
                icon: Remix.checkbox_circle_line,
                color: AppColors.primary,
                bgColor: AppColors.primaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Row 2: Late, Half Day & Absent
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Late',
                value: '$late',
                unit: 'Days',
                icon: Remix.time_line,
                color: AppColors.warning,
                bgColor: const Color(0xFFFEF3C7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                title: 'Half Day',
                value: '$halfDay',
                unit: 'Days',
                icon: Remix.contrast_drop_2_line,
                color: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF3E8FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                title: 'Absent',
                value: '$absent',
                unit: 'Days',
                icon: Remix.close_circle_line,
                color: AppColors.error,
                bgColor: const Color(0xFFFEE2E2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. FILTER SECTION (Month, Year, Status & Reset) ─────────────────────────
  Widget _buildFilterSection({
    required int allCount,
    required int presentCount,
    required int lateCount,
    required int halfDayCount,
    required int absentCount,
  }) {
    final now = DateTime.now();
    final List<int> years = [
      now.year - 2,
      now.year - 1,
      now.year,
      now.year + 1,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
          // Filter Controls: Month Dropdown, Year Dropdown & Reset Action
          Row(
            children: [
              // Month Selector Dropdown
              Expanded(
                flex: 3,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedMonth,
                      isExpanded: true,
                      icon: const Icon(
                        Remix.arrow_down_s_line,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedMonth = val);
                        }
                      },
                      items: List.generate(12, (index) {
                        final mNum = index + 1;
                        return DropdownMenuItem<int>(
                          value: mNum,
                          child: Text(
                            _months[index],
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Year Selector Dropdown
              Expanded(
                flex: 2,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      isExpanded: true,
                      icon: const Icon(
                        Remix.arrow_down_s_line,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedYear = val);
                        }
                      },
                      items: years.map((y) {
                        return DropdownMenuItem<int>(
                          value: y,
                          child: Text('$y'),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Reset / Clear Filters Action
              Tooltip(
                message: 'Reset Filters',
                child: InkWell(
                  onTap: _isFilterActive ? _resetFilters : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: _isFilterActive
                          ? AppColors.primaryLight
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isFilterActive
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Remix.refresh_line,
                          size: 14,
                          color: _isFilterActive
                              ? AppColors.primaryDark
                              : AppColors.textPlaceholder,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Reset',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isFilterActive
                                ? AppColors.primaryDark
                                : AppColors.textPlaceholder,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStatusChip(label: 'All', value: 'ALL', count: allCount),
                const SizedBox(width: 6),
                _buildStatusChip(
                  label: 'Present',
                  value: 'PRESENT',
                  count: presentCount,
                  dotColor: AppColors.primary,
                ),
                const SizedBox(width: 6),
                _buildStatusChip(
                  label: 'Late',
                  value: 'LATE',
                  count: lateCount,
                  dotColor: AppColors.warning,
                ),
                const SizedBox(width: 6),
                _buildStatusChip(
                  label: 'Half Day',
                  value: 'HALF_DAY',
                  count: halfDayCount,
                  dotColor: const Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 6),
                _buildStatusChip(
                  label: 'Absent',
                  value: 'ABSENT',
                  count: absentCount,
                  dotColor: AppColors.error,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required String value,
    required int count,
    Color? dotColor,
  }) {
    final isSelected = _selectedStatus == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null && !isSelected) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textDarkSlate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4. ATTENDANCE LOG CARD ────────────────────────────────────────────────
  Widget _buildLogCard(AttendanceLogItem log) {
    final statusUpper = log.status.toUpperCase();
    final bool isLate = log.isLate || statusUpper == 'LATE';
    final bool isHalfDay = statusUpper.contains('HALF');
    final bool isAbsent = statusUpper == 'ABSENT';
    final bool isLeave = statusUpper.contains('LEAVE');
    final bool isRemote = statusUpper.contains('REMOTE');

    Color badgeBg;
    Color badgeText;
    IconData badgeIcon;
    String badgeLabel;

    if (isAbsent) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFDC2626);
      badgeIcon = Remix.close_circle_fill;
      badgeLabel = 'ABSENT';
    } else if (isLate) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFFD97706);
      badgeIcon = Remix.time_fill;
      badgeLabel = 'LATE';
    } else if (isHalfDay) {
      badgeBg = const Color(0xFFF3E8FF);
      badgeText = const Color(0xFF7C3AED);
      badgeIcon = Remix.contrast_drop_2_fill;
      badgeLabel = 'HALF DAY';
    } else if (isLeave) {
      badgeBg = const Color(0xFFE0F2FE);
      badgeText = const Color(0xFF0369A1);
      badgeIcon = Remix.flight_takeoff_fill;
      badgeLabel = 'ON LEAVE';
    } else if (isRemote) {
      badgeBg = const Color(0xFFCCFBF1);
      badgeText = const Color(0xFF0F766E);
      badgeIcon = Remix.home_wifi_fill;
      badgeLabel = 'REMOTE';
    } else {
      badgeBg = AppColors.primaryLight;
      badgeText = AppColors.primaryDark;
      badgeIcon = Remix.checkbox_circle_fill;
      badgeLabel = 'PRESENT';
    }

    final formattedDate = AppDateFormatter.formatAttendanceDate(log.date);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
          // Header: Date, Day & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Remix.calendar_event_line,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        formattedDate,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (log.day.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          log.day,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDarkSlate,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 11, color: badgeText),
                    const SizedBox(width: 4),
                    Text(
                      badgeLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3-Column Metrics: Check In, Check Out, Work Hours
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                // Check In
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Remix.login_box_line,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'CHECK IN',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        log.checkIn,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 8),

                // Check Out
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Remix.logout_box_line,
                            size: 12,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'CHECK OUT',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (log.checkOut.isEmpty ||
                                log.checkOut == '—' ||
                                log.checkOut == 'null')
                            ? '--:--'
                            : log.checkOut,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 8),

                // Working Hours
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Remix.timer_line,
                            size: 12,
                            color: Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'WORK HOURS',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        log.workingHours,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Secondary Details: Break Duration & Location
          if (log.location.isNotEmpty ||
              (log.breakDuration.isNotEmpty && log.breakDuration != '—')) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (log.location.isNotEmpty)
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Remix.map_pin_2_line,
                          size: 12,
                          color: AppColors.textPlaceholder,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            log.location,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Remix.cup_line,
                        size: 11,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Break: ${(log.breakDuration.isEmpty || log.breakDuration == '—') ? "0h 0m" : log.breakDuration}',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── 5. EMPTY STATE ────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Remix.calendar_close_line,
              size: 36,
              color: AppColors.textPlaceholder,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Attendance Records',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No logs found for ${_months[_selectedMonth - 1]} $_selectedYear${_selectedStatus != "ALL" ? " with status '$_selectedStatus'" : ""}.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (_isFilterActive)
            OutlinedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Remix.filter_off_line, size: 14),
              label: Text(
                'Clear Filters',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () {
                ref.read(employeeAttendanceProvider.notifier).loadHistory();
              },
              icon: const Icon(Remix.refresh_line, size: 14),
              label: Text(
                'Refresh',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── 6. LOADING STATE ──────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return const SkeletonList(count: 4, padding: EdgeInsets.zero);
  }

  // ── 7. ERROR STATE ────────────────────────────────────────────────────────
  Widget _buildErrorState(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Remix.error_warning_line,
              size: 32,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Unable to Load Attendance',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(employeeAttendanceProvider.notifier).loadHistory();
            },
            icon: const Icon(Remix.refresh_line, size: 14),
            label: Text(
              'Retry',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
