import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import '../services/employee_api_service.dart';

class SalarySummaryView extends ConsumerStatefulWidget {
  const SalarySummaryView({super.key});

  @override
  ConsumerState<SalarySummaryView> createState() => _SalarySummaryViewState();
}

class _SalarySummaryViewState extends ConsumerState<SalarySummaryView> {
  late int _selectedYear;
  late int _selectedMonth;
  bool _loading = true;
  bool _downloading = false;
  String? _error;
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _history = [];

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
    _loadHistory();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(employeeApiServiceProvider).getMySalarySummary(
        year: _selectedYear,
        month: _selectedMonth,
      );
      if (mounted) {
        setState(() {
          _data = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load salary summary. Please try again.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    try {
      final hist = await ref.read(employeeApiServiceProvider).getMySalaryHistory();
      if (mounted) setState(() => _history = hist);
    } catch (_) {}
  }

  String _formatCur(dynamic amount) {
    final num val = (amount is num) ? amount : (num.tryParse(amount?.toString() ?? '0') ?? 0);
    final parts = val.toStringAsFixed(0);
    return '₹${parts.replaceAllMapped(RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))'), (m) => '${m[1]},')}';
  }

  Future<void> _downloadPdf() async {
    final reportId = _data?['reportId'];
    final summary = _data?['summary'] as Map<String, dynamic>?;
    final fileName = summary?['fileName']?.toString() ??
        'Salary_Summary_${_selectedMonth}_$_selectedYear.pdf';

    setState(() => _downloading = true);
    AppToast.info(context, 'Downloading Salary Summary PDF...');

    try {
      final apiClient = ref.read(apiClientProvider);
      List<int>? bytes;

      if (reportId != null) {
        try {
          final url = await ref.read(employeeApiServiceProvider).monthlyReportUrl(reportId as int);
          if (url.isNotEmpty) {
            bytes = await apiClient.downloadFileBytes(
              url,
              documentType: 'SALARY_SUMMARY',
              documentId: reportId.toString(),
            );
          }
        } catch (_) {}
      }

      if (bytes == null || bytes.isEmpty) {
        if (reportId != null) {
          bytes = await apiClient.downloadFileBytes(
            '/hrm/my-reports/$reportId/download',
            documentType: 'SALARY_SUMMARY',
            documentId: reportId.toString(),
          );
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await OpenFilex.open(file.path);
        if (mounted) {
          AppToast.success(context, 'Salary Summary PDF downloaded.', title: 'Downloaded');
        }
      } else {
        if (mounted) {
          AppToast.error(context, 'PDF is not available for this month yet.');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to download PDF.');
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _data?['summary'] as Map<String, dynamic>?;
    final isProvisional = _data?['isProvisional'] == true || summary?['isProvisional'] == true;
    final payrollStatus = _data?['payrollStatus']?.toString() ?? summary?['payrollStatus']?.toString() ?? (isProvisional ? 'PROVISIONAL' : 'FINAL');
    final att = summary?['attendance'] as Map<String, dynamic>?;
    final earnings = summary?['earnings'] as Map<String, dynamic>?;
    final deductions = summary?['deductions'] as Map<String, dynamic>?;
    final netPayable = summary?['netPayable'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Monthly Salary Summary',
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
            onPressed: () {
              _loadData();
              _loadHistory();
            },
            icon: const Icon(Remix.refresh_line, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadData();
            await _loadHistory();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Month / Year Selector Card
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
                          return DropdownMenuItem(
                            value: index + 1,
                            child: Text(_months[index]),
                          );
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
                          return DropdownMenuItem(
                            value: y,
                            child: Text('$y'),
                          );
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
                const SizedBox(height: 14),

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
                else ...[
                  // 2. Status Banner (Finalized vs Provisional)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isProvisional ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isProvisional ? const Color(0xFFF59E0B) : const Color(0xFF16A34A),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isProvisional ? Remix.information_line : Remix.checkbox_circle_line,
                          color: isProvisional ? const Color(0xFFB45309) : const Color(0xFF15803D),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isProvisional ? 'PROVISIONAL STATEMENT' : 'FINALIZED PAYROLL STATEMENT',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isProvisional ? const Color(0xFF92400E) : const Color(0xFF166534),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isProvisional
                                    ? 'Attendance-based calculation pending monthly payroll finalization. Subject to change.'
                                    : 'Reconciled with official Salary Slip · Status: $payrollStatus',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: isProvisional ? const Color(0xFFB45309) : const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Hero Net Payable Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF163A2E), Color(0xFF0D5E42)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF163A2E).withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'NET PAYABLE SALARY',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_months[_selectedMonth - 1]} $_selectedYear',
                                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatCur(netPayable),
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _miniMetric('Registered Salary', _formatCur(earnings?['registeredSalary'])),
                            _miniMetric('Gross Earnings', _formatCur(earnings?['grossSalary'])),
                            _miniMetric('Total Deductions', _formatCur(deductions?['totalDeductions'])),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Download PDF Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _downloading ? null : _downloadPdf,
                      icon: _downloading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Remix.download_2_line, size: 20),
                      label: Text(
                        _downloading ? 'Downloading...' : 'Download Salary Summary PDF',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Attendance & Time Tracking Summary Card
                  _sectionHeader('Attendance & Time Tracking', Remix.time_line),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _statBox('Scheduled', '${att?['scheduledDays'] ?? 0}d', const Color(0xFF3B82F6)),
                            const SizedBox(width: 8),
                            _statBox('Present', '${att?['presentDays'] ?? 0}d', const Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            _statBox('Paid Leaves', '${att?['paidLeaveDays'] ?? 0}d', const Color(0xFF6366F1)),
                            const SizedBox(width: 8),
                            _statBox('Unpaid / LOP', '${att?['unpaidLeaveDays'] ?? 0}d', const Color(0xFFEF4444)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _statBox('Half Days', '${att?['halfDays'] ?? 0}d', const Color(0xFFF59E0B)),
                            const SizedBox(width: 8),
                            _statBox('Late Marks', '${att?['lateArrivals'] ?? 0}', const Color(0xFFEC4899)),
                            const SizedBox(width: 8),
                            _statBox('Work Hours', '${att?['totalWorkingHours'] ?? 0}h', const Color(0xFF0D9488)),
                            const SizedBox(width: 8),
                            _statBox('OT Hours', '${att?['approvedOvertimeHours'] ?? 0}h', const Color(0xFF8B5CF6)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Earnings Breakdown
                  _sectionHeader('Earnings Breakdown', Remix.wallet_3_line),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _breakdownRow('Basic Salary', _formatCur(earnings?['basicSalary'])),
                        _breakdownRow('House Rent Allowance (HRA)', _formatCur(earnings?['hra'])),
                        _breakdownRow('Special & Other Allowances', _formatCur(earnings?['allowances'])),
                        if ((earnings?['overtime'] ?? 0) > 0)
                          _breakdownRow('Approved Overtime Pay', _formatCur(earnings?['overtime']), isHighlight: true),
                        if ((earnings?['reimbursement'] ?? 0) > 0)
                          _breakdownRow('Approved Claims / Reimbursements', _formatCur(earnings?['reimbursement']), isHighlight: true),
                        if ((earnings?['commission'] ?? 0) > 0)
                          _breakdownRow('Performance Commission', _formatCur(earnings?['commission']), isHighlight: true),
                        const Divider(height: 20),
                        _breakdownRow('Gross Earnings', _formatCur(earnings?['grossSalary']), isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 6. Deductions Breakdown
                  _sectionHeader('Deductions Breakdown', Remix.scissors_cut_line),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _breakdownRow('Loss of Pay (LOP) Deductions', _formatCur(deductions?['lopDeduction']), isWarning: (deductions?['lopDeduction'] ?? 0) > 0),
                        _breakdownRow('Late Arrival Deductions', _formatCur(deductions?['lateDeductions']), isWarning: (deductions?['lateDeductions'] ?? 0) > 0),
                        _breakdownRow('Provident Fund (PF)', _formatCur(deductions?['pf'])),
                        _breakdownRow('Employee State Insurance (ESI)', _formatCur(deductions?['esi'])),
                        _breakdownRow('Professional Tax (PT)', _formatCur(deductions?['professionalTax'])),
                        _breakdownRow('TDS / Tax Deductions', _formatCur(deductions?['tds'])),
                        const Divider(height: 20),
                        _breakdownRow('Total Deductions', _formatCur(deductions?['totalDeductions']), isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 7. Statement History
                  if (_history.isNotEmpty) ...[
                    _sectionHeader('Statement History', Remix.history_line),
                    const SizedBox(height: 10),
                    ..._history.map((hist) {
                      final hSummary = hist['summary'] as Map<String, dynamic>?;
                      final hYear = hist['year'] ?? 0;
                      final hMonth = hist['month'] ?? 1;
                      final hNet = hSummary?['netPayable'] ?? 0;
                      final hProvisional = hist['isProvisional'] == true || hSummary?['isProvisional'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: (_selectedMonth == hMonth && _selectedYear == hYear)
                                ? AppColors.primary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_months[(hMonth - 1) % 12]} $hYear',
                                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hProvisional ? 'Provisional' : 'Finalized',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: hProvisional ? const Color(0xFFB45309) : const Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  _formatCur(hNet),
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedMonth = hMonth;
                                      _selectedYear = hYear;
                                    });
                                    _loadData();
                                  },
                                  icon: const Icon(Remix.arrow_right_s_line, size: 20, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _miniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 10, color: Colors.white60)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _statBox(String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF64748B)), textAlign: TextAlign.center, maxLines: 1),
            const SizedBox(height: 4),
            Text(val, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, String amount, {bool isBold = false, bool isHighlight = false, bool isWarning = false}) {
    Color textColor = AppColors.textPrimary;
    if (isHighlight) textColor = const Color(0xFF10B981);
    if (isWarning) textColor = const Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? AppColors.textPrimary : const Color(0xFF475569),
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
