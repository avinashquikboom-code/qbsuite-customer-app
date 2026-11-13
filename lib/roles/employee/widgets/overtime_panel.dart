import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/roles/employee/models/employee_attendance_model.dart';
import 'package:quickboom_crm_customer/roles/employee/services/employee_api_service.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_attendance_viewmodel.dart';
import 'package:remixicon/remixicon.dart';

class OvertimeHomeButton extends ConsumerStatefulWidget {
  const OvertimeHomeButton({super.key});

  @override
  ConsumerState<OvertimeHomeButton> createState() => _OvertimeHomeButtonState();
}

class _OvertimeHomeButtonState extends ConsumerState<OvertimeHomeButton> {
  List<OvertimeRequestItem> _requests = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await ref.read(employeeApiServiceProvider).getMyOvertimeRequests();
    if (mounted) setState(() => _requests = rows);
  }

  OvertimeRequestItem? get _current {
    OvertimeRequestItem? pick(bool Function(OvertimeRequestItem) test) {
      for (final row in _requests) {
        if (test(row)) return row;
      }
      return null;
    }

    return pick((row) => row.isInProgress) ??
        pick((row) => row.isCancellationRequested) ??
        pick((row) => row.isApproved) ??
        pick((row) => row.isPending) ??
        pick((row) => row.isRejected) ??
        (_requests.isEmpty ? null : _requests.first);
  }

  bool _windowOpen(OvertimeRequestItem row) {
    final start = DateTime.tryParse('${row.otDate}T${row.plannedStartTime}:00');
    final end = DateTime.tryParse('${row.otDate}T${row.plannedEndTime}:00');
    if (start == null || end == null) return false;
    final finish = end.isAfter(start) ? end : end.add(const Duration(days: 1));
    final now = DateTime.now();
    return !now.isBefore(start) && !now.isAfter(finish);
  }

  Future<void> _tap() async {
    final row = _current;
    if (row == null || row.isRejected || row.isCompleted) {
      await _openForm();
      return;
    }
    if (row.isCancellationRequested) {
      AppToast.info(context, 'Your cancellation request is waiting for admin review.');
      return;
    }
    if (row.isPending || (row.isApproved && !_windowOpen(row))) {
      AppToast.info(context, row.isPending
          ? 'This overtime request is waiting for admin approval.'
          : 'Approved window: ${row.plannedStartTime} – ${row.plannedEndTime} on ${row.otDate}.');
      return;
    }
    setState(() => _busy = true);
    try {
      final api = ref.read(employeeApiServiceProvider);
      if (row.isInProgress) {
        await api.endOvertimeSession(row.id);
      } else {
        await api.startOvertimeSession(row.id);
      }
      if (mounted) AppToast.success(context, row.isInProgress ? 'Overtime ended.' : 'Overtime started.');
      await _load();
    } catch (error) {
      if (mounted) AppToast.error(context, error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openForm() async {
    final tall = MediaQuery.sizeOf(context).height >= 700;
    final saved = tall
        ? await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (_) => const _OvertimeForm(),
          )
        : await Navigator.of(context).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _OvertimeForm(fullScreen: true)));
    if (saved == true) await _load();
  }

  bool _canCancel(OvertimeRequestItem row) {
    if (row.isInProgress || row.isCompleted || row.isCancellationRequested || row.isCancelled) return false;
    if (row.isPending) return true;
    if (!row.isApproved || row.actualStartTime != null) return false;
    final start = DateTime.tryParse('${row.otDate}T${row.plannedStartTime}:00');
    return start != null && DateTime.now().isBefore(start);
  }

  Future<void> _cancel(OvertimeRequestItem row) async {
    if (row.isPending) {
      try {
        await ref.read(employeeApiServiceProvider).cancelPendingOvertime(row.id);
        if (mounted) AppToast.success(context, 'Overtime request cancelled.');
        await _load();
      } catch (error) {
        if (mounted) AppToast.error(context, error.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }
    await _requestCancellation(row);
  }

  Future<void> _requestCancellation(OvertimeRequestItem row) async {
    final reason = TextEditingController();
    final remarks = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request OT Cancellation', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Are you sure you want to cancel your approved overtime request?', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text('${row.otDate} · ${row.otType.replaceAll('_', ' ')}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            Text('${row.plannedStartTime} – ${row.plannedEndTime} · ${row.approvedDurationMinutes ?? row.plannedDurationMinutes} min', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextField(controller: reason, maxLength: 250, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason for cancellation')),
            TextField(controller: remarks, maxLength: 250, minLines: 1, maxLines: 2, decoration: const InputDecoration(labelText: 'Remarks (optional)')),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (reason.text.trim().isEmpty) {
                    AppToast.error(sheetContext, 'Enter a reason for cancellation.');
                    return;
                  }
                  Navigator.pop(sheetContext, true);
                },
                child: const Text('Submit cancellation'),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
      await ref.read(employeeApiServiceProvider).requestOvertimeCancellation(row.id, reason: reason.text.trim(), remarks: remarks.text);
      if (mounted) AppToast.success(context, 'Cancellation request submitted.');
      await _load();
    } catch (error) {
      if (mounted) AppToast.error(context, error.toString().replaceFirst('Exception: ', ''));
    }
    reason.dispose();
    remarks.dispose();
  }

  String _clock(int minutes) {
    final safe = minutes < 0 ? 0 : minutes;
    final hours = safe ~/ 60;
    final mins = safe % 60;
    return '${hours}h ${mins.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final row = _current;
    final canCancel = row != null && _canCancel(row);
    final startInstead = row != null && row.isApproved && _windowOpen(row) && !row.isInProgress;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          if (row != null && row.isInProgress) ...[
            _OvertimeTimerCard(row: row, clock: _clock),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _busy ? null : _tap,
                icon: const Icon(Remix.stop_circle_line, size: 18),
                label: Text(_busy ? 'Saving overtime...' : 'End OT', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _busy ? null : (startInstead ? _tap : _openForm),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _busy ? 'Saving...' : (startInstead ? 'Start OT' : 'Apply OT'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: !canCancel || _busy ? null : () => _cancel(row),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: canCancel ? const Color(0xFFB91C1C) : const Color(0xFFE2E8F0), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Cancel OT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: canCancel ? const Color(0xFFB91C1C) : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (row != null && row.isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'OT completed · worked ${_clock(((row.payableHours) * 60).round())} payable',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
          ],
          if (row != null && row.cancellationRejected && (row.cancellationDecisionNotes ?? '').isNotEmpty)
            Text(row.cancellationDecisionNotes!, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _OvertimeTimerCard extends StatefulWidget {
  const _OvertimeTimerCard({required this.row, required this.clock});
  final OvertimeRequestItem row;
  final String Function(int minutes) clock;

  @override
  State<_OvertimeTimerCard> createState() => _OvertimeTimerCardState();
}

class _OvertimeTimerCardState extends State<_OvertimeTimerCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(widget.row.actualStartTime ?? '');
    final server = DateTime.tryParse(widget.row.serverNow ?? '');
    final offset = start == null || server == null ? Duration.zero : server.difference(DateTime.now());
    final elapsed = start == null ? Duration.zero : DateTime.now().add(offset).difference(start);
    final worked = elapsed.isNegative ? 0 : elapsed.inMinutes;
    final approved = widget.row.approvedDurationMinutes ?? widget.row.plannedDurationMinutes;
    final remaining = approved - worked;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OT In Progress', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF166534))),
          const SizedBox(height: 4),
          Text('Worked ${widget.clock(worked)} · approved ${widget.clock(approved)} · remaining ${widget.clock(remaining)}', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class OvertimeLogSection extends ConsumerStatefulWidget {
  const OvertimeLogSection({super.key});

  @override
  ConsumerState<OvertimeLogSection> createState() => _OvertimeLogSectionState();
}

class _OvertimeLogSectionState extends ConsumerState<OvertimeLogSection> {
  List<OvertimeRequestItem> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await ref.read(employeeApiServiceProvider).getMyOvertimeRequests();
    if (mounted) setState(() => _rows = rows.take(8).toList());
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overtime Attendance', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        ..._rows.map((row) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderLight)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${row.otType.replaceAll('_', ' ')} · ${row.otDate}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Approved window ${row.plannedStartTime} – ${row.plannedEndTime}', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                  Text('Actual ${row.actualStartTime ?? '—'} – ${row.actualEndTime ?? '—'} · ${row.displayStatus}', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                  if ((row.cancellationDecisionNotes ?? '').isNotEmpty) Text(row.cancellationDecisionNotes!, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            )),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _OvertimeForm extends ConsumerStatefulWidget {
  const _OvertimeForm({this.fullScreen = false});
  final bool fullScreen;

  @override
  ConsumerState<_OvertimeForm> createState() => _OvertimeFormState();
}

class _OvertimeFormState extends ConsumerState<_OvertimeForm> {
  final _reason = TextEditingController();
  final _remarks = TextEditingController();
  late DateTime _date = DateTime.now().add(const Duration(days: 1));
  String _type = 'BEFORE_SHIFT';
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  bool _saving = false;
  bool _timesReady = false;

  TimeOfDay? _parseClock(String raw) {
    final match = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false).firstMatch(raw.trim());
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)?.toUpperCase();
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _applyShiftDefaults(AssignedShiftInfo? shift) {
    if (_timesReady || shift == null) return;
    final start = _parseClock(shift.startTime);
    final end = _parseClock(shift.endTime);
    if (start == null || end == null) return;
    _timesReady = true;
    _end = start;
    final before = start.hour * 60 + start.minute - 120;
    _start = TimeOfDay(hour: (before < 0 ? before + 1440 : before) ~/ 60, minute: (before < 0 ? before + 1440 : before) % 60);
  }

  void _selectType(String type, AssignedShiftInfo? shift) {
    final start = shift == null ? null : _parseClock(shift.startTime);
    final end = shift == null ? null : _parseClock(shift.endTime);
    setState(() {
      _type = type;
      if (type == 'BEFORE_SHIFT' && start != null) {
        _end = start;
        final minutes = start.hour * 60 + start.minute - 120;
        final normalized = minutes < 0 ? minutes + 1440 : minutes;
        _start = TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
      }
      if (type == 'AFTER_SHIFT' && end != null) {
        _start = end;
        final minutes = end.hour * 60 + end.minute + 120;
        _end = TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60);
      }
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    _remarks.dispose();
    super.dispose();
  }

  int get _minutes {
    final start = _start.hour * 60 + _start.minute;
    var end = _end.hour * 60 + _end.minute;
    if (end <= start) end += 24 * 60;
    return end - start;
  }

  String _clock(TimeOfDay time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _ampm(TimeOfDay time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  String? _localError(AssignedShiftInfo? shift) {
    if ((_type == 'BEFORE_SHIFT' || _type == 'AFTER_SHIFT') && (shift == null || shift.startTime.isEmpty || shift.endTime.isEmpty)) {
      return 'An assigned shift is required for before-shift or after-shift overtime.';
    }
    if (_reason.text.trim().isEmpty) return 'Enter a reason for overtime.';
    if (_reason.text.trim().length > 250 || _remarks.text.trim().length > 250) return 'Reason and remarks must stay within 250 characters.';
    if (_minutes <= 0) return 'End time must be after the start time.';
    final shiftStart = shift == null ? null : _parseClock(shift.startTime);
    final shiftEnd = shift == null ? null : _parseClock(shift.endTime);
    if (shiftStart != null && _type == 'BEFORE_SHIFT') {
      final end = _end.hour * 60 + _end.minute;
      final start = shiftStart.hour * 60 + shiftStart.minute;
      if (end > start) return 'Before-shift overtime must finish when the shift starts.';
    }
    if (shiftEnd != null && _type == 'AFTER_SHIFT') {
      final start = _start.hour * 60 + _start.minute;
      final end = shiftEnd.hour * 60 + shiftEnd.minute;
      if (start < end) return 'After-shift overtime must start when the shift ends.';
    }
    return null;
  }

  Future<void> _submit(AssignedShiftInfo? shift) async {
    final message = _localError(shift);
    if (message != null) {
      AppToast.error(context, message);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(employeeApiServiceProvider).submitOvertimeRequest(
            otDate: '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
            otType: _type,
            plannedStartTime: _clock(_start),
            plannedEndTime: _clock(_end),
            plannedDurationMinutes: _minutes,
            reason: _reason.text.trim(),
            employeeConsent: true,
            employeeNotes: _remarks.text.trim(),
            shiftId: int.tryParse('${shift?.id}'),
          );
      if (!mounted) return;
      AppToast.success(context, 'Overtime application submitted.');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) AppToast.error(context, error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(loginStateProvider);
    final shift = ref.watch(employeeAttendanceProvider).status.assignedShift;
    _applyShiftDefaults(shift);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final earliest = DateTime.now().add(const Duration(days: 1));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateLabel = '${_date.day.toString().padLeft(2, '0')} ${months[_date.month - 1]} ${_date.year}';
    final body = Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            children: [
              Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 42, height: 42, alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFE8F9EE), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Remix.calendar_check_line, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Apply for Overtime', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF172033))),
                    Text('Request overtime for your scheduled shift.', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                  ])),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Remix.close_line)),
                ],
              ),
              const SizedBox(height: 12),
              _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(auth.userName ?? 'Employee', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                Text('Employee ID: ${auth.employeeCode ?? auth.employeeId ?? '—'}', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                const SizedBox(height: 6),
                Text('Assigned shift: ${shift == null ? 'Not assigned' : '${shift.startTime} – ${shift.endTime}'}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
              ])),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Overtime date', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                subtitle: Text(dateLabel, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                trailing: const Icon(Remix.calendar_line),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _date.isBefore(earliest) ? earliest : _date, firstDate: DateTime(earliest.year, earliest.month, earliest.day), lastDate: DateTime.now().add(const Duration(days: 90)));
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              Text('Overtime type', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _typeCard('BEFORE_SHIFT', 'Before Shift', shift?.startTime ?? '', shift)),
                const SizedBox(width: 10),
                Expanded(child: _typeCard('AFTER_SHIFT', 'After Shift', shift?.endTime ?? '', shift)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _timeButton('Start Time', _start)),
                const SizedBox(width: 10),
                Expanded(child: _timeButton('End Time', _end)),
              ]),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFE8F9EE), borderRadius: BorderRadius.circular(14)),
                child: Text('Requested Duration: ${_minutes ~/ 60}h ${_minutes % 60}m', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                maxLength: 250,
                minLines: 2,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Reason for Overtime', hintText: 'Enter reason for overtime...'),
              ),
              TextField(
                controller: _remarks,
                maxLength: 250,
                minLines: 2,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Optional Remarks', hintText: 'Add any additional remarks...'),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _saving ? null : () => _submit(shift),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Remix.send_plane_2_line),
              label: Text(_saving ? 'Submitting...' : 'Submit Application', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
    final height = MediaQuery.sizeOf(context).height;
    if (widget.fullScreen) return Scaffold(backgroundColor: Colors.white, body: SafeArea(child: body));
    return SizedBox(height: height * 0.92, child: body);
  }

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
    child: child,
  );

  Widget _typeCard(String value, String title, String time, AssignedShiftInfo? shift) {
    final selected = _type == value;
    return InkWell(
      onTap: () => _selectType(value, shift),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F9EE) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : const Color(0xFFE2E8F0), width: selected ? 1.5 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700))),
            if (selected) const Icon(Remix.checkbox_circle_fill, color: AppColors.primary, size: 18),
          ]),
          if (time.isNotEmpty) Text(time, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
        ]),
      ),
    );
  }

  Widget _timeButton(String label, TimeOfDay time) => OutlinedButton(
    onPressed: () async {
      final picked = await showTimePicker(context: context, initialTime: time);
      if (picked == null) return;
      setState(() {
        if (label.startsWith('Start')) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    },
    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    child: Column(children: [
      Text(label, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B))),
      Text(_ampm(time), style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: const Color(0xFF172033))),
    ]),
  );
}
