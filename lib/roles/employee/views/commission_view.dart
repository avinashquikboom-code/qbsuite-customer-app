import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import '../models/commission_model.dart';
import '../viewmodels/commission_viewmodel.dart';
import 'monthly_reports_view.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';

class EmployeeCommissionView extends ConsumerStatefulWidget {
  const EmployeeCommissionView({super.key});

  @override
  ConsumerState<EmployeeCommissionView> createState() =>
      _EmployeeCommissionViewState();
}

class _EmployeeCommissionViewState
    extends ConsumerState<EmployeeCommissionView> {
  static const List<String> _months = [
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

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final formatted = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '₹$formatted${parts[1] == '00' ? '' : '.${parts[1]}'}';
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      final day = dt.day.toString().padLeft(2, '0');
      final month = _months[dt.month - 1];
      return '$day $month ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(employeeCommissionProvider.notifier).loadCommissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeCommissionProvider);
    final summary = state.summary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppAppBar(
        title: 'My Commissions',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Remix.file_pdf_line, color: AppColors.textPrimary),
            tooltip: 'Monthly reports',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MonthlyReportsView())),
          ),
          IconButton(
            icon: const Icon(Remix.refresh_line, color: AppColors.textPrimary),
            tooltip: 'Refresh Commissions',
            onPressed: () =>
                ref.read(employeeCommissionProvider.notifier).refresh(),
          ),
        ],
      ),
      body: state.isLoading && state.items.isEmpty
          ? _buildCommissionSkeleton()
          : state.errorMessage != null && state.items.isEmpty
          ? _buildErrorView(state.errorMessage!)
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(employeeCommissionProvider.notifier).refresh(),
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Employee Header & Total Hero Banner
                    _buildHeroTotalCard(summary, state.employee),

                    const SizedBox(height: 16),

                    // 2. Summary Breakdown Cards (Earned, Paid, Pending)
                    _buildSummaryMetricsGrid(summary),

                    const SizedBox(height: 20),

                    // 3. Status Filter Chips
                    _buildFilterChips(state.selectedStatus),

                    const SizedBox(height: 16),

                    // 4. Commission Items Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Commission History',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${state.items.length} records',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 5. Commission Items List
                    if (state.items.isEmpty)
                      _buildEmptyState(state.selectedStatus)
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = state.items[index];
                          return _buildCommissionCard(item);
                        },
                      ),

                    const SizedBox(height: 24),
                    if (state.items.length < state.total)
                      TextButton(
                        onPressed: state.isLoading
                            ? null
                            : () => ref
                                  .read(employeeCommissionProvider.notifier)
                                  .loadMore(),
                        child: Text(
                          state.isLoading
                              ? 'Loading...'
                              : 'Load more commissions',
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  // Hero Card with Total Commission & Employee Badge
  Widget _buildHeroTotalCard(
    CommissionSummary summary,
    CommissionEmployeeInfo? emp,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0x3310B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Remix.coins_line,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TOTAL COMMISSION',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              if (emp != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    emp.designation,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatCurrency(summary.totalCommission),
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${summary.totalCount} successful lead conversions',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // Summary Metrics Grid (Earned, Paid, Pending)
  Widget _buildSummaryMetricsGrid(CommissionSummary summary) {
    return Row(
      children: [
        // Earned / Approved
        Expanded(
          child: _buildMetricMiniCard(
            title: 'Earned',
            amount: summary.approvedCommission,
            count: summary.approvedCount,
            icon: Remix.arrow_up_circle_line,
            color: const Color(0xFF10B981),
            bg: const Color(0xFFECFDF5),
          ),
        ),
        const SizedBox(width: 8),

        // Paid
        Expanded(
          child: _buildMetricMiniCard(
            title: 'Paid',
            amount: summary.paidCommission,
            count: summary.paidCount,
            icon: Remix.check_double_line,
            color: const Color(0xFF3B82F6),
            bg: const Color(0xFFEFF6FF),
          ),
        ),
        const SizedBox(width: 8),

        // Pending
        Expanded(
          child: _buildMetricMiniCard(
            title: 'Pending',
            amount: summary.pendingCommission,
            count: summary.pendingCount,
            icon: Remix.time_line,
            color: const Color(0xFFF59E0B),
            bg: const Color(0xFFFFFBEB),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricMiniCard({
    required String title,
    required double amount,
    required int count,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatCurrency(amount),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count deals',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // Filter Chips Bar
  Widget _buildFilterChips(String selectedStatus) {
    final filters = [
      {'key': 'ALL', 'label': 'All'},
      {'key': 'APPROVED', 'label': 'Earned'},
      {'key': 'PAID', 'label': 'Paid'},
      {'key': 'PENDING', 'label': 'Pending'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final isSelected = selectedStatus == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                f['label']!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF0F172A),
              backgroundColor: Colors.white,
              elevation: 0,
              pressElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : AppColors.borderLight,
                ),
              ),
              onSelected: (_) {
                ref
                    .read(employeeCommissionProvider.notifier)
                    .setStatusFilter(f['key']!);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // Individual Commission Card
  Widget _buildCommissionCard(CommissionItem item) {
    final custName = item.customer?.displayName ?? 'Customer';
    final leadTitle = item.lead?.displayName ?? 'Lead';
    final planName = item.plan?.name ?? 'Plan Purchase';

    Color statusColor;
    Color statusBg;
    String statusLabel;
    IconData statusIcon;

    if (item.isPaid) {
      statusColor = const Color(0xFF2563EB);
      statusBg = const Color(0xFFEFF6FF);
      statusLabel = 'Paid';
      statusIcon = Remix.checkbox_circle_line;
    } else if (item.isEarned) {
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFECFDF5);
      statusLabel = 'Earned';
      statusIcon = Remix.check_line;
    } else if (item.isPending) {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFFFBEB);
      statusLabel = 'Pending';
      statusIcon = Remix.time_line;
    } else {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEF2F2);
      statusLabel = 'Cancelled';
      statusIcon = Remix.close_circle_line;
    }

    final earnedDateStr = _formatDate(item.qualifyingAt ?? item.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Customer Name & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$custName · #${item.customerId}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lead: $leadTitle',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),

          // Plan & Rate details
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      planName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    'Base: ${_formatCurrency(item.purchaseAmount)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                'Your share: ${item.commissionRate}${item.commissionType == 'PERCENTAGE' ? '%' : '₹'}'
                '${item.originalCommissionRate != null ? ' of ${item.originalCommissionRate}${item.commissionType == 'PERCENTAGE' ? '%' : '₹'} total' : ''}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Bottom Row: Commission Amount (Large) & Date
          Text(
            'Transaction: ${_formatCurrency(item.purchase?.totalAmount ?? item.purchaseAmount)} · ${item.orderId ?? item.purchase?.orderNumber ?? '#${item.purchaseId ?? item.id}'}',
          ),
          if (item.recipientRole == 'LEADER')
            Text(
              'Team leader share · Sale by ${item.sourceEmployeeName ?? 'BPO employee'}\n'
              'Employee: ${_formatCurrency(item.employeeShareAmount ?? 0)} (${item.employeeShareStatus ?? ''}) · Leader: ${_formatCurrency(item.leaderShareAmount ?? 0)}',
            ),
          if (item.payrollPeriod != null)
            Text('Payroll: ${item.payrollPeriod}'),
          if (item.customerCommissionTotal != null)
            Text(
              'Your customer total: ${_formatCurrency(item.customerCommissionTotal!)}',
            ),
          if (item.reviewReason != null)
            const Text('Requires commission review'),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMMISSION EARNED',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(item.commissionAmount),
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Remix.calendar_line,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        earnedDateStr,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (item.paidAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Paid: ${_formatDate(item.paidAt!)}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Empty State View
  Widget _buildEmptyState(String filter) {
    final label = filter == 'ALL'
        ? 'No commissions recorded'
        : 'No $filter commissions';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Remix.coins_line, size: 36, color: Colors.grey),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When you convert a lead into a paying customer, your commission will appear here automatically.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 120, borderRadius: 16),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: SkeletonStatCard()),
              SizedBox(width: 12),
              Expanded(child: SkeletonStatCard()),
            ],
          ),
          const SizedBox(height: 16),
          const SkeletonCard(),
          const SkeletonCard(),
          const SkeletonCard(),
        ],
      ),
    );
  }

  // Error State View
  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Remix.error_warning_line,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 14),
            Text(
              'Unable to Load Commissions',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(employeeCommissionProvider.notifier).refresh(),
              icon: const Icon(Remix.refresh_line, size: 16),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
