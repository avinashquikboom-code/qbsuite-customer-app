import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/company_admin_models.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_calendar_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_my_work_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/work_permissions_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/employee_my_work_card.dart';

class EmployeeActivityDetailSheet extends ConsumerStatefulWidget {
  final CustomerCalendarActivity activity;

  const EmployeeActivityDetailSheet({super.key, required this.activity});

  static void show(BuildContext context, CustomerCalendarActivity activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          child: EmployeeActivityDetailSheet(activity: activity),
        ),
      ),
    );
  }

  @override
  ConsumerState<EmployeeActivityDetailSheet> createState() =>
      _EmployeeActivityDetailSheetState();
}

class _EmployeeActivityDetailSheetState
    extends ConsumerState<EmployeeActivityDetailSheet> {
  late String _status;
  String? _notes;
  bool _isLoading = false;
  late final TextEditingController _updateNoteController;

  @override
  void initState() {
    super.initState();
    _status = widget.activity.status;
    _notes = widget.activity.notes;
    _updateNoteController = TextEditingController();
  }

  @override
  void dispose() {
    _updateNoteController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'APPROVED':
        return const Color(0xFF16A34A);
      case 'IN_PROGRESS':
      case 'PROCESSING':
        return const Color(0xFF2563EB);
      case 'BLOCKED':
        return const Color(0xFFDC2626);
      case 'ASSIGNED':
        return const Color(0xFFD97706);
      case 'SCHEDULED':
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'APPROVED':
        return const Color(0xFFDCFCE7);
      case 'IN_PROGRESS':
      case 'PROCESSING':
        return const Color(0xFFDBEAFE);
      case 'BLOCKED':
        return const Color(0xFFFEE2E2);
      case 'ASSIGNED':
        return const Color(0xFFFEF3C7);
      case 'SCHEDULED':
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Future<void> _submitProgressUpdate({
    String? newStatus,
    String? newNotes,
  }) async {
    setState(() => _isLoading = true);

    final targetStatus = newStatus ?? _status;
    final success = await updateEmployeeWorkProgress(
      ref,
      widget.activity.id,
      newStatus: newStatus,
      notes: newNotes,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (success) {
        if (newStatus != null) _status = targetStatus;
        if (newNotes != null && newNotes.trim().isNotEmpty) {
          _notes = newNotes.trim();
          _updateNoteController.clear();
        }
      }
    });

    if (success) {
      ref.read(employeeMyWorkProvider.notifier).refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newNotes != null
                ? 'Work update saved!'
                : (targetStatus == 'COMPLETED'
                      ? 'Work marked as completed!'
                      : (targetStatus == 'BLOCKED'
                            ? 'Work marked as blocked!'
                            : 'Work updated!')),
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: targetStatus == 'COMPLETED'
              ? const Color(0xFF16A34A)
              : (targetStatus == 'BLOCKED'
                    ? const Color(0xFFDC2626)
                    : AppColors.primary),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save update. Please try again.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final catColor = resolveTaskColor(activity);
    final catBgColor = resolveTaskBgColor(activity);
    final displayName = resolveActivityDisplayName(activity);
    final rbac = ref.watch(permissionManagerProvider);
    final canReopen =
        rbac.canReopenWork ||
        rbac.canApproveCreativeWork ||
        rbac.canApproveTask ||
        ref.watch(workPermissionsProvider).permissions.isSupervisor;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top Bar: Category pill + Status badge + Close button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: catBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        activity.activityType.icon,
                        size: 14,
                        color: catColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        activity.activityType.label,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: catColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(_status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _status.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(_status),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Remix.close_line,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Task / Service Name
            Text(
              displayName,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),

            if (activity.isCarriedForward) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Remix.time_line,
                      size: 16,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CARRIED FORWARD TASK',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFB45309),
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (activity.originalScheduledDateDisplay != null)
                            Text(
                              'Originally scheduled: ${activity.originalScheduledDateDisplay} • Current: ${formatActivityDate(activity.date)}',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (activity.planName != null && activity.planName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Remix.vip_crown_line,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    activity.planName!,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),

            // Key Details Section
            Text(
              'ASSIGNMENT & WORK DETAILS',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),

            // 1. Customer Name
            _buildDetailTile(
              icon: Remix.building_2_line,
              label: 'Customer',
              value:
                  activity.businessName.trim().isNotEmpty
                  ? activity.businessName.trim()
                  : (activity.customerName.trim().isNotEmpty
                        ? activity.customerName.trim()
                        : '—'),
            ),
            const SizedBox(height: 8),

            // 2. Scheduled Date & Time
            _buildDetailTile(
              icon: Remix.calendar_event_line,
              label: 'Scheduled Date & Time',
              value:
                  activity.time.trim().isNotEmpty &&
                          activity.time.trim().toLowerCase() != 'time not set'
                      ? '${formatActivityDate(activity.date)} • ${activity.time.trim()}'
                      : formatActivityDate(activity.date),
            ),
            const SizedBox(height: 8),

            // 3. Assigned Employee
            if (activity.assignedEmployee.trim().isNotEmpty &&
                activity.assignedEmployee.toLowerCase() != 'unassigned') ...[
              _buildDetailTile(
                icon: Remix.user_3_line,
                label: 'Assigned Employee',
                value: activity.assignedEmployee,
                valueColor: const Color(0xFF4338CA),
              ),
              const SizedBox(height: 8),
            ],

            // 4. Assigned Team
            if (activity.team != null && activity.team!.trim().isNotEmpty) ...[
              _buildDetailTile(
                icon: Remix.team_line,
                label: 'Assigned Team',
                value: activity.team!,
              ),
              const SizedBox(height: 8),
            ],

            // Video Editor
            if (activity.editorName != null &&
                activity.editorName!.trim().isNotEmpty &&
                activity.editorName!.trim().toLowerCase() != 'unassigned') ...[
              _buildDetailTile(
                icon: Remix.film_line,
                label: 'Video Editor',
                value: activity.editorName!.trim(),
                valueColor: const Color(0xFF7C3AED),
              ),
              const SizedBox(height: 8),
            ],

            // 5. Current Status
            _buildDetailTile(
              icon: Remix.flag_line,
              label: 'Current Status',
              value: _status.toUpperCase(),
              valueColor: _getStatusColor(_status),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),

            // ── LATEST WORK UPDATE BOX ──
            Text(
              'LATEST WORK UPDATE',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Remix.chat_quote_line,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (_notes != null && _notes!.trim().isNotEmpty)
                          ? _notes!
                          : 'No updates recorded yet.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: (_notes != null && _notes!.trim().isNotEmpty)
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── SUBMIT PROGRESS UPDATE INPUT ──
            Text(
              'SUBMIT PROGRESS UPDATE',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _updateNoteController,
                      decoration: InputDecoration(
                        hintText: 'Enter update (e.g. Editing 80% complete)...',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _isLoading
                        ? null
                        : () {
                            final text = _updateNoteController.text.trim();
                            if (text.isNotEmpty) {
                              _submitProgressUpdate(newNotes: text);
                            }
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Send',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),

            // ── STATUS ACTION BUTTONS ──
            _buildActionButtons(canReopen),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool canReopen) {
    final s = _status.toUpperCase();

    if (_isLoading) {
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (s == 'COMPLETED' || s == 'APPROVED') {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Remix.checkbox_circle_fill,
                  size: 18,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(width: 8),
                Text(
                  'Work Completed',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
          if (canReopen) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    _submitProgressUpdate(newStatus: 'IN_PROGRESS'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  'Reopen Work (Set to In Progress)',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (s == 'BLOCKED') {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Remix.error_warning_fill,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(width: 8),
                Text(
                  'Work Blocked',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => _submitProgressUpdate(newStatus: 'IN_PROGRESS'),
              icon: const Icon(Remix.play_fill, size: 18, color: Colors.white),
              label: Text(
                'Resume Work (In Progress)',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (s == 'IN_PROGRESS' || s == 'PROCESSING') {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _submitProgressUpdate(newStatus: 'COMPLETED'),
                icon: const Icon(
                  Remix.checkbox_circle_line,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  'Complete Work',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _submitProgressUpdate(newStatus: 'BLOCKED'),
                icon: const Icon(
                  Remix.pause_circle_line,
                  size: 16,
                  color: Color(0xFFDC2626),
                ),
                label: Text(
                  'Block',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Default: SCHEDULED, ASSIGNED, PENDING
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _submitProgressUpdate(newStatus: 'IN_PROGRESS'),
              icon: const Icon(Remix.play_fill, size: 18, color: Colors.white),
              label: Text(
                'Start Work',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _submitProgressUpdate(newStatus: 'BLOCKED'),
              icon: const Icon(
                Remix.pause_circle_line,
                size: 16,
                color: Color(0xFFDC2626),
              ),
              label: Text(
                'Block',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFDC2626),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
