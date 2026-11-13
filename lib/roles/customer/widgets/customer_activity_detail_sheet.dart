import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/company_admin_models.dart';
import 'package:quickboom_company_admin/roles/company_admin/viewmodels/company_admin_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_subscription_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/views/social_media_work_handler_view.dart';

class CustomerActivityDetailSheet extends ConsumerStatefulWidget {
  final CustomerCalendarActivity activity;

  const CustomerActivityDetailSheet({super.key, required this.activity});

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
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: CustomerActivityDetailSheet(activity: activity),
        ),
      ),
    );
  }

  @override
  ConsumerState<CustomerActivityDetailSheet> createState() =>
      _CustomerActivityDetailSheetState();
}

class _CustomerActivityDetailSheetState
    extends ConsumerState<CustomerActivityDetailSheet> {
  late CustomerCalendarActivity _activity;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
  }

  Future<void> _approveWork() async {
    setState(() => _isLoading = true);
    try {
      final updated = _activity.copyWith(status: 'Completed');
      ref
          .read(companyAdminProvider.notifier)
          .updateCustomCalendarActivity(updated);
      await refreshAllCustomerSubscriptionData(ref);

      setState(() {
        _activity = updated;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deliverable approved successfully! Quota consumed.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve work: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showRevisionDialog() {
    final actionLabel = _activity.reworkActionLabel ?? 'Request Rework';
    final feedbackCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(
              Remix.chat_history_line,
              color: Color(0xFFD97706),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              actionLabel,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provide feedback / instructions for the creative team:',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: feedbackCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'e.g. Please change background audio and adjust color grading...',
                hintStyle: GoogleFonts.outfit(fontSize: 12.5),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              style: GoogleFonts.outfit(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final fb = feedbackCtrl.text.trim();
              if (fb.isEmpty) return;
              Navigator.pop(dlgCtx);

              setState(() => _isLoading = true);
              try {
                final apiClient = ref.read(apiClientProvider);
                await apiClient.post(
                  '/works/${_activity.id}/rework',
                  data: {'reason': fb},
                );

                final updated = _activity.copyWith(
                  revisionCount: _activity.revisionCount + 1,
                  feedback: fb,
                  status: 'Revision Requested',
                  notes: '${_activity.notes ?? ''}\n[Rework Request]: $fb'
                      .trim(),
                );
                ref
                    .read(companyAdminProvider.notifier)
                    .updateCustomCalendarActivity(updated);
                await refreshAllCustomerSubscriptionData(ref);

                setState(() {
                  _activity = updated;
                  _isLoading = false;
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '$actionLabel submitted successfully. Creative team notified.',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: const Color(0xFFD97706),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to submit rework request: $e'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Submit Request',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRescheduleDialog() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _activity.date.isAfter(DateTime.now())
          ? _activity.date
          : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'SELECT NEW SCHEDULE DATE',
    );

    if (pickedDate == null) return;

    // Check Sunday
    if (pickedDate.weekday == DateTime.sunday) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Scheduling on Sundays is not allowed by working calendar policy.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 11, minute: 0),
      helpText: 'SELECT TIME WINDOW',
    );

    final timeStr = pickedTime != null
        ? '${pickedTime.hourOfPeriod.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')} ${pickedTime.period == DayPeriod.am ? 'AM' : 'PM'}'
        : _activity.time;

    setState(() => _isLoading = true);
    try {
      final dateIso =
          '${pickedDate.year.toString().padLeft(4, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
      final apiClient = ref.read(apiClientProvider);
      await apiClient.patch(
        '/works/${_activity.id}/reschedule',
        data: {'scheduledDate': dateIso, 'scheduledTime': timeStr},
      );

      final updated = _activity.copyWith(date: pickedDate, time: timeStr);
      ref
          .read(companyAdminProvider.notifier)
          .updateCustomCalendarActivity(updated);
      await refreshAllCustomerSubscriptionData(ref);

      setState(() {
        _activity = updated;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Schedule successfully moved to ${_formatDate(pickedDate)} at $timeStr',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF2563EB),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reschedule: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = getScheduleColor(_activity.activityType);
    final themeBgColor = getScheduleBgColor(_activity.activityType);
    final statusLower = _activity.status.toLowerCase();
    final isUnderReview =
        statusLower.contains('review') ||
        statusLower.contains('submitted') ||
        statusLower.contains('progress');
    final isCompleted =
        statusLower.contains('complete') || statusLower.contains('approve');
    final canReschedule = !isCompleted && !statusLower.contains('cancel');

    final bottomNavPadding = MediaQuery.of(context).viewPadding.bottom > 0
        ? MediaQuery.of(context).viewPadding.bottom
        : (MediaQuery.of(context).padding.bottom > 0
              ? MediaQuery.of(context).padding.bottom
              : 0.0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          top: 12,
          left: 20,
          right: 20,
          bottom:
              bottomNavPadding + MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: themeBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _activity.activityType.icon,
                      size: 14,
                      color: themeColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _activity.activityType.label,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              '${_activity.customerName} • ${_activity.activityType.label}',
              softWrap: true,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.tierEnterpriseDark,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _activity.businessName,
              softWrap: true,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),

            if (_activity.isCarriedForward) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                      child: Text(
                        'CARRIED FORWARD${_activity.originalScheduledDateDisplay != null ? ' • Originally scheduled: ${_activity.originalScheduledDateDisplay}' : ''}',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Schedule Details Grid
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Remix.vip_crown_line,
                    label: 'Plan',
                    value: _activity.planName ?? 'Active Plan',
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    icon: Remix.calendar_event_line,
                    label: 'Scheduled Date',
                    value: _formatDate(_activity.date),
                  ),
                  if (_activity.isCarriedForward) ...[
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      icon: Remix.history_line,
                      label: 'Carried Forward',
                      value: _activity.originalScheduledDateDisplay != null
                          ? 'Orig: ${_activity.originalScheduledDateDisplay}'
                          : 'Yes',
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    icon: Remix.checkbox_circle_line,
                    label: 'Status',
                    value: _activity.status.trim().toUpperCase(),
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    icon: Remix.time_line,
                    label: 'Time Window',
                    value: _activity.time,
                  ),
                ],
              ),
            ),

            if (_activity.notes != null && _activity.notes!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'NOTES & DELIVERABLES',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  _activity.notes!,
                  softWrap: true,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Reschedule Button for Customer
            if (canReschedule) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _showRescheduleDialog,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Remix.calendar_schedule_line,
                        size: 16,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Reschedule Date & Time',
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Customer Review Actions (Approve / Revision)
            if (isUnderReview && !isCompleted) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _showRevisionDialog,
                      icon: const Icon(
                        Remix.chat_history_line,
                        size: 16,
                        color: Color(0xFFD97706),
                      ),
                      label: Text(
                        'Request Revision',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFCD34D)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _approveWork,
                      icon: const Icon(
                        Remix.check_double_line,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Approve Work',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Request Rework Action for Completed Activity
            if (_activity.canRequestRework || isCompleted) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _showRevisionDialog,
                  icon: const Icon(
                    Remix.chat_history_line,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  label: Text(
                    _activity.reworkActionLabel ?? 'Request Rework / Revision',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCD34D)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Remix.close_line, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Close',
                              textAlign: TextAlign.center,
                              softWrap: true,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SocialMediaWorkHandlerView(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Remix.share_circle_line,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'SSM Account Access',
                              textAlign: TextAlign.center,
                              softWrap: true,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Text(
            label,
            softWrap: true,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            softWrap: true,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
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
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final wd = weekdays[date.weekday - 1];
    final m = months[date.month - 1];
    return '$wd, ${date.day} $m ${date.year}';
  }
}
