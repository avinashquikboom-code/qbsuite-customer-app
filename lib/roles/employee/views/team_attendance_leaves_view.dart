import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import '../services/employee_api_service.dart';

class TeamAttendanceLeavesView extends ConsumerStatefulWidget {
  const TeamAttendanceLeavesView({super.key});

  @override
  ConsumerState<TeamAttendanceLeavesView> createState() => _TeamAttendanceLeavesViewState();
}

class _TeamAttendanceLeavesViewState extends ConsumerState<TeamAttendanceLeavesView> {
  late int _selectedYear;
  late int _selectedMonth;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _members = [];

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(employeeApiServiceProvider).getTeamAttendanceLeaves(
        year: _selectedYear,
        month: _selectedMonth,
      );
      if (mounted) {
        setState(() {
          _members = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load team attendance and leave reports.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Team Attendance & Leaves',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: AppColors.textPrimary),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Remix.refresh_line, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner note regarding Manager permission
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Remix.shield_user_line, size: 20, color: Color(0xFF475569)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Manager View: Attendance and leave balances for your direct reports. Financial & salary records are restricted to HR/Payroll.',
                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Month / Year Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Remix.calendar_2_line, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Period:',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      DropdownButton<int>(
                        value: _selectedMonth,
                        underline: const SizedBox(),
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        items: List.generate(12, (index) {
                          return DropdownMenuItem(value: index + 1, child: Text(_months[index]));
                        }),
                        onChanged: (val) {
                          if (val != null && val != _selectedMonth) {
                            setState(() => _selectedMonth = val);
                            _loadData();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _selectedYear,
                        underline: const SizedBox(),
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        items: [2025, 2026, 2027].map((y) {
                          return DropdownMenuItem(value: y, child: Text('$y'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null && val != _selectedYear) {
                            setState(() => _selectedYear = val);
                            _loadData();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error!, style: GoogleFonts.outfit(color: Colors.red.shade800)),
                  )
                else if (_members.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: Text(
                      'No team members reporting under you for this period.',
                      style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF64748B)),
                    ),
                  )
                else
                  ..._members.map((mem) {
                    final attSummary = mem['attendanceSummary'] as Map<String, dynamic>?;
                    final attStatus = mem['attendanceStatus']?.toString() ?? 'PENDING';
                    final lveStatus = mem['leaveStatus']?.toString() ?? 'PENDING';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mem['employeeName'] ?? 'Employee',
                                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    '${mem['employeeCode']} · ${mem['designation']}',
                                    style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  mem['department'] ?? '—',
                                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _attBadge('Attendance', attStatus, Remix.calendar_check_line),
                              const SizedBox(width: 8),
                              _attBadge('Leave Ledger', lveStatus, Remix.file_list_3_line),
                            ],
                          ),
                          if (attSummary != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _subMetric('Present', '${attSummary['presentDays'] ?? 0}d'),
                                _subMetric('Absent', '${attSummary['absentDays'] ?? 0}d'),
                                _subMetric('Half Days', '${attSummary['halfDays'] ?? 0}d'),
                                _subMetric('Leaves', '${attSummary['leaveDays'] ?? 0}d'),
                                _subMetric('OT Hours', '${attSummary['approvedOvertimeHours'] ?? 0}h'),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _attBadge(String label, String status, IconData icon) {
    final isDone = status == 'GENERATED' || status == 'COMPLETED';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isDone ? const Color(0xFF15803D) : const Color(0xFFB45309)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$label: $status',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDone ? const Color(0xFF15803D) : const Color(0xFFB45309),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subMetric(String label, String val) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(val, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}

