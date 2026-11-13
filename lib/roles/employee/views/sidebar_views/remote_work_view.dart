import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/models/permission_model.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/roles/employee/models/employee_leave_model.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_leave_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/shared/widgets/empty_state_card.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';

class RemoteWorkView extends ConsumerStatefulWidget {
  const RemoteWorkView({super.key});

  @override
  ConsumerState<RemoteWorkView> createState() => _RemoteWorkViewState();
}

class _RemoteWorkViewState extends ConsumerState<RemoteWorkView> {
  String _selectedFilter = 'ACTIVE'; // ACTIVE, APPROVED, PENDING, HISTORY

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(employeeLeaveProvider.notifier).loadAll();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return AppColors.primary;
      case 'PENDING':
        return AppColors.warning;
      case 'REJECTED':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  void _showApplyModal() {
    final reasonCtrl = TextEditingController();
    DateTime fromDate = DateTime.now();
    DateTime toDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);

    String formatTimeOfDay(TimeOfDay tod) {
      final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
      final minute = tod.minute.toString().padLeft(2, '0');
      final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
      return '${hour.toString().padLeft(2, '0')}:$minute $period';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          final bottomInset = MediaQuery.of(modalContext).viewInsets.bottom;
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Apply for Remote Work (WFH)',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Remix.close_line),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'From Date',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: fromDate,
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 7),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 90),
                                  ),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    fromDate = picked;
                                    if (toDate.isBefore(fromDate)) {
                                      toDate = fromDate;
                                    }
                                  });
                                }
                              },
                              icon: const Icon(Remix.calendar_line, size: 15),
                              label: Text(
                                '${fromDate.day}/${fromDate.month}/${fromDate.year}',
                                style: GoogleFonts.outfit(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'To Date',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: toDate,
                                  firstDate: fromDate,
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 90),
                                  ),
                                );
                                if (picked != null) {
                                  setModalState(() => toDate = picked);
                                }
                              },
                              icon: const Icon(
                                Remix.calendar_check_line,
                                size: 15,
                              ),
                              label: Text(
                                '${toDate.day}/${toDate.month}/${toDate.year}',
                                style: GoogleFonts.outfit(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Time',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: startTime,
                                );
                                if (picked != null) {
                                  setModalState(() => startTime = picked);
                                }
                              },
                              icon: const Icon(Remix.time_line, size: 15),
                              label: Text(
                                formatTimeOfDay(startTime),
                                style: GoogleFonts.outfit(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Time',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: endTime,
                                );
                                if (picked != null) {
                                  setModalState(() => endTime = picked);
                                }
                              },
                              icon: const Icon(Remix.time_fill, size: 15),
                              label: Text(
                                formatTimeOfDay(endTime),
                                style: GoogleFonts.outfit(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Reason & Deliverables Plan *',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'Explain reason and planned deliverables during remote work...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (reasonCtrl.text.trim().isEmpty) {
                          AppToast.error(context, 'Please enter a reason.');
                          return;
                        }
                        Navigator.pop(ctx);
                        final fromStr = fromDate.toIso8601String().split(
                          'T',
                        )[0];
                        final toStr = toDate.toIso8601String().split('T')[0];
                        final startStr = formatTimeOfDay(startTime);
                        final endStr = formatTimeOfDay(endTime);

                        final currentContext = context;
                        final success = await ref
                            .read(employeeLeaveProvider.notifier)
                            .applyRemoteWork(
                              fromDate: fromStr,
                              toDate: toStr,
                              startTime: startStr,
                              endTime: endStr,
                              reason: reasonCtrl.text.trim(),
                            );
                        if (!currentContext.mounted) return;
                        if (success) {
                          AppToast.success(
                            currentContext,
                            'Remote work application submitted for approval!',
                          );
                        } else {
                          final err = ref
                              .read(employeeLeaveProvider)
                              .errorMessage;
                          if (err != null) AppToast.error(currentContext, err);
                        }
                      },
                      child: Text(
                        'SUBMIT APPLICATION',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaveState = ref.watch(employeeLeaveProvider);
    final allRequests = leaveState.remoteRequests;

    final filteredList = allRequests.where((r) {
      if (_selectedFilter == 'ACTIVE') return r.isApproved || r.isPending;
      if (_selectedFilter == 'APPROVED') return r.isApproved;
      if (_selectedFilter == 'PENDING') return r.isPending;
      return true;
    }).toList();

    final rbac = ref.watch(permissionManagerProvider);
    final canCreate = rbac.canCreate(AppModule.remoteWork);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: 'Remote Work (WFH)'),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: _showApplyModal,
              icon: const Icon(Remix.add_line),
              label: Text(
                'Apply WFH',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(employeeLeaveProvider.notifier).loadAll(),
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip('Active', 'ACTIVE'),
                    _buildFilterChip('Approved', 'APPROVED'),
                    _buildFilterChip('Pending', 'PENDING'),
                    _buildFilterChip('All History', 'HISTORY'),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: leaveState.isLoading && allRequests.isEmpty
                  ? const SkeletonList(count: 4)
                  : filteredList.isEmpty
                  ? const Center(
                      child: EmptyStateCard(
                        title: 'No Remote Work Requests',
                        description:
                            'Apply for remote work days and track approval status.',
                        icon: Remix.home_wifi_line,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final item = filteredList[index];
                        return _buildApplicationCard(item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primaryLight,
        checkmarkColor: AppColors.primaryDark,
        labelStyle: GoogleFonts.outfit(
          color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (selected) {
          if (selected) setState(() => _selectedFilter = value);
        },
      ),
    );
  }

  Widget _buildApplicationCard(RemoteRequestItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
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
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Remix.calendar_event_line,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${item.fromDate} - ${item.toDate}',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(item.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(item.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Remix.time_line,
                size: 13,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${item.startTime} – ${item.endTime}',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.reason,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Duration: ${item.days} ${item.days == 1 ? 'day' : 'days'}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
