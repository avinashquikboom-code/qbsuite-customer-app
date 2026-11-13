import 'dart:io';
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import '../models/employee_payroll_model.dart';
import '../services/employee_api_service.dart';
import '../viewmodels/employee_payroll_viewmodel.dart';
import '../viewmodels/employee_profile_viewmodel.dart';
import 'salary_summary_view.dart';

class SalarySlipView extends ConsumerStatefulWidget {
  const SalarySlipView({super.key});

  @override
  ConsumerState<SalarySlipView> createState() => _SalarySlipViewState();
}

class _SalarySlipViewState extends ConsumerState<SalarySlipView> with WidgetsBindingObserver {
  bool _isEmployeeInfoExpanded = true;
  bool _isBankDetailsExpanded = true;
  bool _showAllHistory = false;
  Map<String, dynamic>? _target;

  Future<void> _loadTarget() async {
    try {
      final target = await ref.read(employeeApiServiceProvider).getSalaryTarget();
      if (mounted) setState(() => _target = target);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(employeeProfileProvider);
      ref.read(employeePayrollProvider.notifier).loadSalarySlips();
      _loadTarget();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(employeeProfileProvider);
      ref.read(employeePayrollProvider.notifier).loadSalarySlips();
      _loadTarget();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Formatters ─────────────────────────────────────────────────────────────

  static String formatDisplayDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    try {
      final dt = DateTime.tryParse(raw.trim());
      if (dt != null) {
        const months = [
          '',
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
        return '${dt.day} ${months[dt.month]} ${dt.year}';
      }
    } catch (_) {}
    return raw;
  }

  static String formatCurrency(num amount) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final parts = absAmount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '00';
    if (intPart.length <= 3) {
      return '${isNegative ? "- " : ""}₹$intPart.$decPart';
    }
    final lastThree = intPart.substring(intPart.length - 3);
    final rest = intPart.substring(0, intPart.length - 3);
    final buffer = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(rest[i]);
    }
    buffer.write(',');
    buffer.write(lastThree);
    return '${isNegative ? "- " : ""}₹${buffer.toString()}.$decPart';
  }

  Widget _buildLiveTargetCard(Map<String, dynamic> target) {
    final met = target['targetStatus'] == 'ACHIEVED';
    String money(dynamic value) => formatCurrency(double.tryParse('${value ?? 0}') ?? 0);
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
          Text(value, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TARGET SALARY', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
          const SizedBox(height: 8),
          line('Monthly target', money(target['monthlyTarget'])),
          line('Achieved', money(target['achievedAmount'])),
          line('Remaining', money(target['remainingAmount'])),
          line('Achievement', '${target['achievementPercent'] ?? 0}%'),
          line('Status', met ? 'Achieved' : 'Not achieved'),
          line('Eligible salary', money(target['eligibleSalary'])),
          Text(
            'Full target pays ${money(target['fullSalary'])}. Below target pays ${money(target['belowTargetSalary'])}. Attendance loss of pay is then applied to the eligible salary.',
            style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  static String maskAccountNumber(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    final clean = raw.trim();
    if (clean.length <= 4) return clean;
    final last4 = clean.substring(clean.length - 4);
    return 'XXXX XXXX $last4';
  }

  // ── PDF Download Handler ───────────────────────────────────────────────────

  Future<void> _handleDownloadPdf(BuildContext context, SalarySlipItem slip) async {
    try {
      AppToast.info(context, 'Downloading salary slip for ${slip.month}...');
      final apiClient = ref.read(apiClientProvider);

      Uint8List? bytes;

      // 1. Direct stream from backend official PDF endpoint
      try {
        bytes = await apiClient.downloadFileBytes(
          '/admin/payroll/slips/${slip.id}/pdf',
          documentType: 'SALARY_SLIP',
          documentId: slip.id,
        );
      } catch (e) {
        debugPrint('[SALARY_DOWNLOAD] /pdf stream failed: $e, trying fallbacks');
        // 2. Check direct URL if available
        if (slip.downloadUrl != null &&
            slip.downloadUrl!.isNotEmpty &&
            slip.downloadUrl!.startsWith('http')) {
          try {
            bytes = await apiClient.downloadFileBytes(
              slip.downloadUrl!,
              documentType: 'SALARY_SLIP',
              documentId: slip.id,
            );
          } catch (_) {}
        }
        // 3. Fallback to /download endpoint
        if (bytes == null || bytes.isEmpty) {
          try {
            final res = await apiClient.get('/admin/payroll/slips/${slip.id}/download');
            final url = res.data?['downloadUrl']?.toString();
            if (url != null && url.isNotEmpty && url.startsWith('http')) {
              bytes = await apiClient.downloadFileBytes(
                url,
                documentType: 'SALARY_SLIP',
                documentId: slip.id,
              );
            }
          } catch (_) {}
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        final dir = await getApplicationDocumentsDirectory();
        final safeName =
            'salary_slip_${slip.month.replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_')}.pdf';
        final file = File('${dir.path}/$safeName');
        await file.writeAsBytes(bytes);
        await OpenFilex.open(file.path);
        if (context.mounted) {
          AppToast.success(
            context,
            'Salary slip downloaded successfully.',
            title: 'Downloaded',
          );
        }
        return;
      }

      if (context.mounted) {
        AppToast.error(context, 'Unable to download PDF. Please try again.');
      }
    } catch (e) {
      debugPrint('[SALARY_DOWNLOAD] Error: $e');
      if (context.mounted) {
        AppToast.error(context, 'Unable to download PDF. Please try again.');
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final payrollState = ref.watch(employeePayrollProvider);
    final profileAsync = ref.watch(employeeProfileProvider);
    final profile = profileAsync.asData?.value;

    final slips = payrollState.slips;
    final latest = payrollState.latestSlip;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppAppBar(
        title: 'Salary Slips & Payroll',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Remix.refresh_line),
            tooltip: 'Refresh Payroll',
            onPressed: () {
              ref.invalidate(employeeProfileProvider);
              ref.read(employeePayrollProvider.notifier).loadSalarySlips();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: payrollState.isLoading
            ? _buildLoadingSkeleton()
            : (payrollState.errorMessage != null && slips.isEmpty)
                ? _buildErrorState(payrollState.errorMessage!)
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      ref.invalidate(employeeProfileProvider);
                      await ref
                          .read(employeePayrollProvider.notifier)
                          .loadSalarySlips();
                      await _loadTarget();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Latest Salary Slip Summary Card, then its actions
                          if (latest != null) ...[
                            _buildLatestSalaryCard(latest),
                            const SizedBox(height: 14),
                            _buildActionButtons(latest),
                            const SizedBox(height: 14),
                          ],
                          if (_target?['assigned'] == true) ...[
                            _buildLiveTargetCard(_target!),
                            const SizedBox(height: 18),
                          ] else if (latest != null)
                            const SizedBox(height: 4),

                          // Attendance-Based Salary Summary Card
                          InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SalarySummaryView()),
                            ),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF163A2E), Color(0xFF0F766E)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF163A2E).withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Remix.calculator_line, color: Colors.white, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Monthly Attendance & Salary Summary',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'View attendance-based calculations, hours, LOP & download PDF',
                                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Remix.arrow_right_s_line, color: Colors.white, size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 3. Collapsible Card: Employee Information
                          _buildEmployeeInfoCard(profile, latest),
                          const SizedBox(height: 14),

                          // 4. Collapsible Card: Bank & Payment Details
                          _buildBankPaymentCard(profile, latest),
                          const SizedBox(height: 24),

                          // 5. Section: Payslip History
                          _buildHistoryHeader(slips.length),
                          const SizedBox(height: 12),

                          if (slips.isEmpty)
                            _buildEmptyState()
                          else
                            _buildHistoryList(slips),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  // ── 1. Latest Salary Card ──────────────────────────────────────────────────

  Widget _buildLatestSalaryCard(SalarySlipItem slip) {
    final statusText = (slip.status ?? 'GENERATED').toUpperCase();
    final disbursedDate = formatDisplayDate(slip.date);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F763E), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: LATEST SALARY SLIP • Month Year • Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LATEST SALARY SLIP',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      slip.month,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  '[$statusText]',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Main Net Payable & Disbursement Date
          Text(
            'Net Payable',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatCurrency(slip.netSalary),
              style: GoogleFonts.outfit(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Remix.calendar_check_line,
                size: 13,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 5),
              Text(
                'Disbursed on: $disbursedDate',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.22), height: 1),
          const SizedBox(height: 14),

          // Salary Breakdown Row (Basic | Allowances | Reimbursement | Deductions)
          Row(
            children: [
              Expanded(
                child: _buildBreakdownBox(
                  'Basic',
                  formatCurrency(slip.basicSalary),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildBreakdownBox(
                  'Allowances',
                  formatCurrency(slip.allowances),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildBreakdownBox(
                  'Reimbursement',
                  formatCurrency(slip.reimbursement),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildBreakdownBox(
                  'Total Deductions',
                  formatCurrency(slip.deductions),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Action Buttons ──────────────────────────────────────────────────────

  Widget _buildActionButtons(SalarySlipItem slip) {
    return Row(
      children: [
        // View Salary Slip (Green Primary Button)
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _showSlipDetailsModal(context, slip),
              icon: const Icon(Remix.eye_line, size: 17, color: Colors.white),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'View Salary Slip',
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Download PDF (Green Outline Button)
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _handleDownloadPdf(context, slip),
              icon: const Icon(
                Remix.download_2_line,
                size: 17,
                color: AppColors.primary,
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Download PDF',
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 3. Collapsible Card: Employee Information ──────────────────────────────

  Widget _buildEmployeeInfoCard(
    EmployeeProfileData? profile,
    SalarySlipItem? latest,
  ) {
    final emp = latest?.employeeDetails;

    final empName = (profile?.name != null && profile!.name.trim().isNotEmpty)
        ? profile.name
        : (emp?['name'] ??
            '${emp?['firstName'] ?? ''} ${emp?['lastName'] ?? ''}'.trim());
    final employeeId = (profile?.employeeCode != null &&
            profile!.employeeCode.trim().isNotEmpty)
        ? profile.employeeCode
        : (emp?['employeeCode'] ?? '—');
    final designation = (profile?.designation != null &&
            profile!.designation.trim().isNotEmpty)
        ? profile.designation
        : (emp?['designation'] is Map
            ? emp!['designation']['name']
            : (emp?['designation'] ?? '—'));
    final department = (profile?.department != null &&
            profile!.department.trim().isNotEmpty)
        ? profile.department
        : (emp?['department'] is Map
            ? emp!['department']['name']
            : (emp?['department'] ?? '—'));
    final joiningDate = formatDisplayDate(
      profile?.joiningDate.isNotEmpty == true
          ? profile!.joiningDate
          : emp?['joiningDate']?.toString(),
    );
    final employmentType = (profile?.employmentType != null &&
            profile!.employmentType.trim().isNotEmpty)
        ? profile.employmentType
        : (emp?['employmentType'] ?? 'Full-Time');
    final location = (profile?.branch != null && profile!.branch.trim().isNotEmpty)
        ? profile.branch
        : (emp?['branch'] ?? 'Head Office');
    final reportingManager = (profile?.manager != null &&
            profile!.manager.trim().isNotEmpty)
        ? profile.manager
        : (emp?['manager'] ?? 'Direct Reporting');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() {
              _isEmployeeInfoExpanded = !_isEmployeeInfoExpanded;
            }),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Remix.user_3_line,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Employee Information',
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _isEmployeeInfoExpanded
                        ? Remix.arrow_up_s_line
                        : Remix.arrow_down_s_line,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Content
          if (_isEmployeeInfoExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTwoColumnRow(
                    leftLabel: 'EMPLOYEE NAME',
                    leftValue: empName.isNotEmpty ? empName : '—',
                    rightLabel: 'JOINING DATE',
                    rightValue: joiningDate,
                  ),
                  const SizedBox(height: 12),
                  _buildTwoColumnRow(
                    leftLabel: 'EMPLOYEE ID',
                    leftValue: employeeId.isNotEmpty ? employeeId : '—',
                    rightLabel: 'EMPLOYMENT TYPE',
                    rightValue: employmentType.toString(),
                  ),
                  const SizedBox(height: 12),
                  _buildTwoColumnRow(
                    leftLabel: 'DESIGNATION',
                    leftValue: designation.toString(),
                    rightLabel: 'LOCATION',
                    rightValue: location.toString(),
                  ),
                  const SizedBox(height: 12),
                  _buildTwoColumnRow(
                    leftLabel: 'DEPARTMENT',
                    leftValue: department.toString(),
                    rightLabel: 'REPORTING MANAGER',
                    rightValue: reportingManager.toString(),
                  ),
                  if (profile?.salaryStructure != null) ...[
                    const SizedBox(height: 12),
                    _buildTwoColumnRow(
                      leftLabel: 'CURRENT BASIC SALARY',
                      leftValue: formatCurrency(num.tryParse(profile!.salaryStructure!['basicSalary'].toString()) ?? 0),
                      rightLabel: 'CURRENT GROSS SALARY',
                      rightValue: formatCurrency(num.tryParse(profile.salaryStructure!['grossSalary'].toString()) ?? 0),
                    ),
                    const SizedBox(height: 12),
                    _buildTwoColumnRow(
                      leftLabel: 'CURRENT HRA',
                      leftValue: formatCurrency(num.tryParse(profile.salaryStructure!['hra'].toString()) ?? 0),
                      rightLabel: 'CURRENT ALLOWANCES',
                      rightValue: formatCurrency(num.tryParse(profile.salaryStructure!['allowances'].toString()) ?? 0),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 4. Collapsible Card: Bank & Payment Details ────────────────────────────

  Widget _buildBankPaymentCard(
    EmployeeProfileData? profile,
    SalarySlipItem? latest,
  ) {
    final bDetails = latest?.bankDetails ?? profile?.bankDetails;

    final paymentMode = (latest?.paymentMode != null &&
            latest!.paymentMode!.trim().isNotEmpty)
        ? latest.paymentMode!
        : (bDetails?['paymentMethod'] ?? bDetails?['paymentMode'] ?? 'Bank Transfer');
    final bankName = bDetails?['bankName']?.toString() ?? '—';
    final accountNumber = maskAccountNumber(bDetails?['accountNumber']?.toString());
    final ifscCode = bDetails?['ifscCode']?.toString() ?? '—';
    final paymentReference = (latest?.paymentReference != null &&
            latest!.paymentReference!.trim().isNotEmpty)
        ? latest.paymentReference!
        : (latest?.slipNumber?.isNotEmpty == true ? latest!.slipNumber! : '—');
    final disbursementDate = formatDisplayDate(latest?.date);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() {
              _isBankDetailsExpanded = !_isBankDetailsExpanded;
            }),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Remix.bank_card_line,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bank & Payment Details',
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _isBankDetailsExpanded
                        ? Remix.arrow_up_s_line
                        : Remix.arrow_down_s_line,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Content
          if (_isBankDetailsExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTwoColumnRow(
                    leftLabel: 'PAYMENT MODE',
                    leftValue: paymentMode.toString(),
                    rightLabel: 'BANK NAME',
                    rightValue: bankName.isNotEmpty ? bankName : '—',
                  ),
                  const SizedBox(height: 12),
                  _buildTwoColumnRow(
                    leftLabel: 'ACCOUNT NUMBER',
                    leftValue: accountNumber,
                    rightLabel: 'IFSC CODE',
                    rightValue: ifscCode.isNotEmpty ? ifscCode : '—',
                  ),
                  const SizedBox(height: 12),
                  _buildTwoColumnRow(
                    leftLabel: 'PAYMENT REFERENCE',
                    leftValue: paymentReference,
                    rightLabel: 'DISBURSEMENT DATE',
                    rightValue: disbursementDate,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTwoColumnRow({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                leftLabel,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                leftValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rightLabel,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rightValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 5. Payslip History ─────────────────────────────────────────────────────

  Widget _buildHistoryHeader(int totalCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payslip History',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'View and download your monthly salary slips',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (totalCount > 4)
          GestureDetector(
            onTap: () => setState(() {
              _showAllHistory = !_showAllHistory;
            }),
            child: Text(
              _showAllHistory ? 'Show Less' : 'View All >',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryList(List<SalarySlipItem> slips) {
    final displaySlips = _showAllHistory ? slips : slips.take(4).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displaySlips.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final slip = displaySlips[index];
        return _buildHistoryCard(slip);
      },
    );
  }

  Widget _buildHistoryCard(SalarySlipItem slip) {
    final disbursedDate = formatDisplayDate(slip.date);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Salary Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Remix.file_list_3_line,
              color: AppColors.primary,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          // Month & Disbursed Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slip.month,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Disbursed on $disbursedDate',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Amount & View / More Action Row
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(slip.netSalary),
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showSlipDetailsModal(context, slip),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.eye_line,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'View',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Remix.more_2_line,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    onSelected: (val) {
                      if (val == 'view') {
                        _showSlipDetailsModal(context, slip);
                      } else if (val == 'download') {
                        _handleDownloadPdf(context, slip);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            const Icon(
                              Remix.file_info_line,
                              size: 16,
                              color: AppColors.textPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'View Breakdown',
                              style: GoogleFonts.outfit(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            const Icon(
                              Remix.download_2_line,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Download PDF',
                              style: GoogleFonts.outfit(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 6. Breakdown Details Modal ─────────────────────────────────────────────

  void _showSlipDetailsModal(BuildContext context, SalarySlipItem slip) {
    final isBpo = RegExp(r'bpo|telecall|telesales', caseSensitive: false).hasMatch(
      '${slip.employeeDetails?['designation'] ?? ''} ${slip.employeeDetails?['department'] ?? ''}',
    );
    final commissionLabel = isBpo ? 'Approved BPO Commission' : 'Commission';

    final earningsRows = <MapEntry<String, num>>[
      MapEntry('Basic Salary', slip.basicSalary),
      MapEntry('HRA Allowance', slip.hra),
      MapEntry('Allowances & Special', slip.allowances + slip.specialAllowance),
    ];
    if (slip.extraWorkingPay > 0) {
      earningsRows.add(MapEntry('Extra Working Pay', slip.extraWorkingPay));
    }
    if (slip.commission > 0) {
      earningsRows.add(MapEntry(commissionLabel, slip.commission));
    }
    if (slip.reimbursement > 0) {
      earningsRows.add(MapEntry('Expense Reimbursement', slip.reimbursement));
    }

    final deductionRows = <MapEntry<String, num>>[
      MapEntry('Provident Fund (PF)', slip.pf),
      MapEntry('ESI Contribution', slip.esi),
      MapEntry('TDS / Income Tax', slip.tds + slip.professionalTax),
    ];
    if (slip.loanDeduction > 0) {
      deductionRows.add(MapEntry('Loan Deduction (EMI)', slip.loanDeduction));
    }
    if (slip.unpaidLeaveDeduction > 0) {
      deductionRows.add(MapEntry('Loss of Pay (Unpaid Leave)', slip.unpaidLeaveDeduction));
    }

    final maxRowCount = earningsRows.length > deductionRows.length
        ? earningsRows.length
        : deductionRows.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetCtx, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Salary Slip Breakdown',
                            style: GoogleFonts.outfit(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pay Period: ${slip.month}',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F763E),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Remix.close_line, size: 22),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Attendance Summary Section
                  Text(
                    'ATTENDANCE SUMMARY',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header (Dark Green)
                        Container(
                          color: const Color(0xFF0F763E),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9.5),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'ATTENDANCE DETAIL',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Text(
                                'VALUE',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._buildAttendanceSummaryRows(slip),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    'SALARY BREAKDOWN',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Monthly & Attendance-based Payable Salary Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (slip.registeredSalary > 0) ...[
                              Text(
                                'REGISTERED MONTHLY SALARY',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatCurrency(slip.registeredSalary),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              'MONTHLY SALARY',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatCurrency(slip.monthlySalary > 0
                                  ? slip.monthlySalary
                                  : (slip.basicSalary + slip.hra + slip.allowances + slip.specialAllowance)),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'ATTENDANCE-BASED PAYABLE',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatCurrency(slip.attendanceSalary > 0
                                  ? slip.attendanceSalary
                                  : slip.grossSalary),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F763E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (slip.compensationMode == 'TARGET') ...[
                    const SizedBox(height: 8),
                    _buildLiveTargetCard({
                      'targetStatus': slip.targetStatus,
                      'monthlyTarget': slip.monthlyTarget,
                      'achievedAmount': slip.achievedAmount,
                      'remainingAmount': slip.remainingAmount,
                      'achievementPercent': slip.achievementPercent,
                      'eligibleSalary': slip.eligibleSalary,
                      'fullSalary': slip.registeredSalary > 0 ? slip.registeredSalary : slip.eligibleSalary,
                      'belowTargetSalary': slip.belowTargetSalary,
                    }),
                  ],

                  // 4-Column Structured Table with Horizontal Scroll for Small Screens
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 520),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Table Header (Dark Green)
                          Container(
                            color: const Color(0xFF0F763E),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 155,
                                  child: Text(
                                    'EARNINGS',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    'AMOUNT',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 165,
                                  child: Text(
                                    'DEDUCTIONS',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    'AMOUNT',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Table Rows
                          for (int i = 0; i < maxRowCount; i++)
                            Container(
                              decoration: BoxDecoration(
                                color: i % 2 == 1 ? const Color(0xFFF8FAFC) : Colors.white,
                                border: const Border(
                                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9.5),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 155,
                                    child: Text(
                                      i < earningsRows.length ? earningsRows[i].key : '—',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        color: i < earningsRows.length
                                            ? AppColors.textPrimary
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      i < earningsRows.length
                                          ? formatCurrency(earningsRows[i].value)
                                          : '—',
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: i < earningsRows.length
                                            ? AppColors.textPrimary
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 165,
                                    child: Text(
                                      i < deductionRows.length ? deductionRows[i].key : '—',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        color: i < deductionRows.length
                                            ? AppColors.textPrimary
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      i < deductionRows.length
                                          ? formatCurrency(deductionRows[i].value)
                                          : '—',
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: i < deductionRows.length
                                            ? const Color(0xFFDC2626)
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Distinguishable Totals Row
                          Container(
                            color: const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 155,
                                  child: Text(
                                    'Total Gross Salary',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    formatCurrency(slip.grossSalary),
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F763E),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 165,
                                  child: Text(
                                    'Total Deductions',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    formatCurrency(slip.deductions),
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Net Payable Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F9EE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'NET PAYABLE (TAKE HOME SALARY)',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                      color: const Color(0xFF0F763E),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatCurrency(slip.netSalary),
                                    style: GoogleFonts.outfit(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F763E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _handleDownloadPdf(context, slip),
                              icon: const Icon(Remix.download_2_line, size: 16, color: Colors.white),
                              label: Text(
                                'Download PDF',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F763E),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFF86EFAC)),
                        const SizedBox(height: 8),
                        Text(
                          'Confidential Document — Generated electronically by QB Suite',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildAttendanceSummaryRows(SalarySlipItem slip) {
    String formatDays(double val) {
      return val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
    }

    final totalCalDays = slip.calendarDays > 0
        ? slip.calendarDays
        : (slip.workingDays + slip.weeklyOffDays + slip.holidayDays);

    final rows = <MapEntry<String, String>>[
      MapEntry('Total Calendar Days', formatDays(totalCalDays)),
      MapEntry('Total Working Days', formatDays(slip.workingDays)),
      MapEntry('Present Days', formatDays(slip.presentDays)),
      MapEntry('Half Days', formatDays(slip.halfDays)),
      MapEntry('Absent Days', formatDays(slip.absentDays)),
      MapEntry('Paid Leave Days', formatDays(slip.paidLeaveDays)),
      MapEntry('Unpaid Leave Days', formatDays(slip.unpaidLeaveDays)),
      MapEntry('Weekly Offs', formatDays(slip.weeklyOffDays)),
      MapEntry('Holidays', formatDays(slip.holidayDays)),
      MapEntry('Extra Working Days', formatDays(slip.extraWorkingDays)),
      MapEntry('Payable Attendance Days', formatDays(slip.payableDays)),
      MapEntry('Overtime Hours', slip.overtimeHours.isNotEmpty ? slip.overtimeHours : '0h 0m'),
      MapEntry('OT Actual Hours', '${slip.otActualHours}h'),
      MapEntry('OT Payable Hours', '${slip.otPayableHours}h'),
      MapEntry('OT Payout', formatCurrency(slip.otPayout)),
      MapEntry('Late Marks', formatDays(slip.lateMarks)),
      MapEntry('Late Deduction', formatCurrency(slip.lateDeduction)),
    ];

    final widgets = rows.asMap().entries.map((entry) {
      final idx = entry.key;
      final row = entry.value;
      final isEven = idx % 2 == 0;
      return Container(
        decoration: BoxDecoration(
          color: isEven ? Colors.white : const Color(0xFFF8FAFC),
          border: idx < rows.length - 1
              ? const Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                row.key,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
            Text(
              row.value,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      );
    }).toList();

    if (slip.extraWorkingDates.isNotEmpty) {
      widgets.add(
        Container(
          color: const Color(0xFFECFDF5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Approved Extra Working Dates',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF047857),
                  ),
                ),
              ),
              Text(
                slip.extraWorkingDates.join(', '),
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF047857),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  // ── States: Loading, Error, Empty ──────────────────────────────────────────

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        children: [
          const SkeletonBox(height: 210, borderRadius: 22),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(child: SkeletonBox(height: 48, borderRadius: 14)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 48, borderRadius: 14)),
            ],
          ),
          const SizedBox(height: 18),
          const SkeletonBox(height: 130, borderRadius: 18),
          const SizedBox(height: 14),
          const SkeletonBox(height: 130, borderRadius: 18),
          const SizedBox(height: 24),
          const SkeletonCard(),
          const SkeletonCard(),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Remix.error_warning_line,
                size: 36,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load salary slips.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(employeeProfileProvider);
                ref.read(employeePayrollProvider.notifier).loadSalarySlips();
              },
              icon: const Icon(Remix.refresh_line, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Remix.receipt_line,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No Salary Slips Yet',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Salary slips will appear here once payroll is processed.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
