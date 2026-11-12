import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:dio/dio.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/leads_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/lead_stages_viewmodel.dart';

/// Shows the modernized Schedule Field Visit bottom sheet.
Future<LeadModel?> showScheduleVisitBottomSheet(
  BuildContext context, {
  required LeadModel lead,
  required WidgetRef ref,
  Function(LeadModel)? onVisitScheduled,
}) {
  final rbac = ref.read(permissionManagerProvider);
  final rawRole = (rbac.role ?? '').trim().toUpperCase();
  final isCustomerOrAdmin =
      rawRole.contains('CUSTOMER') ||
      rawRole.contains('ADMIN') ||
      rawRole == 'SUPER_ADMIN';
  final isBpo = rawRole.contains('BPO') || rbac.isCrmEligible;
  final canSchedule =
      isCustomerOrAdmin ||
      isBpo ||
      rbac.canViewLeads ||
      rbac.canScheduleVisits ||
      PermissionManager.instance.canScheduleVisits;
  if (!canSchedule) {
    AppToast.error(
      context,
      'Access denied: Missing required permission [VISITS:CREATE]',
    );
    return Future.value(null);
  }

  return showModalBottomSheet<LeadModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (ctx) => ScheduleVisitBottomSheet(
      lead: lead,
      onVisitScheduled: onVisitScheduled,
    ),
  );
}

class ScheduleVisitBottomSheet extends ConsumerStatefulWidget {
  final LeadModel lead;
  final Function(LeadModel)? onVisitScheduled;

  const ScheduleVisitBottomSheet({
    super.key,
    required this.lead,
    this.onVisitScheduled,
  });

  @override
  ConsumerState<ScheduleVisitBottomSheet> createState() =>
      _ScheduleVisitBottomSheetState();
}

class _ScheduleVisitBottomSheetState
    extends ConsumerState<ScheduleVisitBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _purposeCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _notesCtrl;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  int? _selectedEmployeeId;
  List<Map<String, dynamic>> _visitorEmployees = [];
  bool _isLoadingEmployees = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _purposeCtrl = TextEditingController(
      text: 'Product Demo & Architecture Review',
    );
    _locationCtrl = TextEditingController(
      text: widget.lead.address ?? widget.lead.city ?? 'Client Office',
    );
    _notesCtrl = TextEditingController();
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _selectedTime = const TimeOfDay(hour: 11, minute: 0);

    if (widget.lead.employeeId != null) {
      _selectedEmployeeId = int.tryParse(widget.lead.employeeId.toString());
    }

    _fetchVisitorEmployees();
  }

  @override
  void dispose() {
    _purposeCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool _isVisitorEmployee(Map<String, dynamic> emp) {
    final status = (emp['status'] ?? '').toString().toUpperCase();
    if (status != 'ACTIVE' || emp['mobileLoginEnabled'] == false) return false;

    final desigName =
        ((emp['designation'] is Map
                    ? emp['designation']['name']
                    : emp['designationName'] ?? emp['designation']) ??
                '')
            .toString()
            .toUpperCase();
    final desigCode =
        ((emp['designation'] is Map
                    ? emp['designation']['code']
                    : emp['designationCode']) ??
                '')
            .toString()
            .toUpperCase();
    final role =
        ((emp['role'] is Map ? emp['role']['name'] : emp['role']) ?? '')
            .toString()
            .toUpperCase();
    final roleType = (emp['roleType'] ?? '').toString().toUpperCase();

    // Match by name, code, or role — no hardcoded IDs
    return desigName.contains('VISIT') ||
        desigName.contains('FIELD VISIT') ||
        desigName.contains('VISITOR') ||
        desigCode.contains('VISIT') ||
        desigCode.contains('FIELD') ||
        desigCode.contains('VISITOR') ||
        role.contains('VISITOR') ||
        role.contains('VISIT') ||
        roleType.contains('VISITOR') ||
        roleType.contains('VISIT');
  }

  Future<void> _fetchVisitorEmployees() async {
    try {
      final all = <Map<String, dynamic>>[];
      var page = 1;
      var totalPages = 1;
      do {
        final res = await ref.read(apiClientProvider).get('/employees', queryParameters: {'status': 'ACTIVE', 'page': page, 'limit': 100});
        final raw = res.data;
        final data = raw is Map && raw['data'] is Map ? raw['data'] : raw;
        final items = data is List ? data : data is Map ? (data['items'] ?? data['data'] ?? data['employees']) : null;
        if (items is! List) throw const FormatException('Invalid visitor employee response');
        all.addAll(items.map((e) => Map<String,dynamic>.from(e as Map)));
        final pagination = data is Map ? data['pagination'] ?? data['meta'] : null;
        totalPages = pagination is Map ? (pagination['totalPages'] as num?)?.toInt() ?? 1 : 1;
        page++;
      } while (page <= totalPages);
      if (!mounted) return;
      setState(() {
        _visitorEmployees = all.where(_isVisitorEmployee).toList();
        _isLoadingEmployees = false;
        if (!_visitorEmployees.any((e) => e['id'] == _selectedEmployeeId)) _selectedEmployeeId = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingEmployees = false);
      AppToast.error(context, 'Unable to load Visitor employees. Please reopen the scheduling form to retry.');
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatDate(DateTime dt) {
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _handleSubmit() async {
    final rbac = ref.read(permissionManagerProvider);
    final rawRole = (rbac.role ?? '').trim().toUpperCase();
    final isCustomerOrAdmin =
        rawRole.contains('CUSTOMER') ||
        rawRole.contains('ADMIN') ||
        rawRole == 'SUPER_ADMIN';
    final isBpo = rawRole.contains('BPO') || rbac.isCrmEligible;
    final canSchedule =
        isCustomerOrAdmin ||
        isBpo ||
        rbac.canViewLeads ||
        rbac.canScheduleVisits ||
        PermissionManager.instance.canScheduleVisits;
    if (!canSchedule) {
      AppToast.error(
        context,
        'Access denied: Missing required permission [VISITS:CREATE]',
      );
      return;
    }

    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) return;

    if (_selectedEmployeeId == null) {
      AppToast.error(context, 'Please select a visitor employee.');
      return;
    }

    setState(() => _isSubmitting = true);

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final timeStr = _selectedTime.format(context);

    try {
      final updated = await ref
          .read(leadsProvider.notifier)
          .manageVisit(
            widget.lead.id,
            action: 'SCHEDULE',
            purpose: _purposeCtrl.text.trim(),
            location: _locationCtrl.text.trim(),
            date: dateStr,
            time: timeStr,
            notes: _notesCtrl.text.trim(),
            employeeId: _selectedEmployeeId,
          );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (updated != null) {
        ref.read(leadsProvider.notifier).refreshCurrentList();
        ref.read(leadStagesProvider.notifier).refresh();
        widget.onVisitScheduled?.call(updated);
        Navigator.pop(context, updated);
        AppToast.success(context, 'Field Visit Scheduled Successfully!');
      } else {
        AppToast.error(context, 'Failed to schedule visit. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        // Extract the real backend error message from DioException
        String errorMsg = 'Failed to schedule visit.';
        if (e is DioException) {
          final status = e.response?.statusCode;
          final responseData = e.response?.data;
          final backendMsg = responseData is Map
              ? (responseData['message']?.toString() ??
                    responseData['error']?.toString())
              : null;
          if (backendMsg != null && backendMsg.isNotEmpty) {
            errorMsg = '[HTTP $status] $backendMsg';
          } else {
            errorMsg = '[HTTP $status] ${e.message ?? e.toString()}';
          }
        } else {
          errorMsg = e.toString();
        }
        AppToast.error(context, errorMsg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomNavPadding = MediaQuery.of(context).viewPadding.bottom > 0
        ? MediaQuery.of(context).viewPadding.bottom
        : (MediaQuery.of(context).padding.bottom > 0
              ? MediaQuery.of(context).padding.bottom
              : 0.0);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final company = widget.lead.companyName;
    final fullName = '${widget.lead.firstName} ${widget.lead.lastName}'.trim();
    final leadTitle = (company != null && company.isNotEmpty)
        ? company
        : fullName;
    final displayName = leadTitle.isNotEmpty ? leadTitle : widget.lead.title;

    final footerBottomPadding = keyboardInset > 0
        ? 12.0
        : (bottomNavPadding > 0 ? bottomNavPadding + 10 : 16.0);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              spreadRadius: 2,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 6),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Remix.calendar_event_fill,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule Field Visit',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (displayName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'For $displayName',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Remix.close_line, size: 22),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // Scrollable Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Visit Purpose
                      _buildSectionHeader(
                        'Visit Purpose *',
                        Remix.briefcase_line,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _purposeCtrl,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. Demonstration & Proposal Discussion',
                          prefixIcon: const Icon(
                            Remix.file_list_3_line,
                            size: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? 'Purpose is required'
                            : null,
                      ),

                      const SizedBox(height: 16),

                      // Visit Location
                      _buildSectionHeader(
                        'Visit Location *',
                        Remix.map_pin_2_line,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _locationCtrl,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. Andheri East, Mumbai',
                          prefixIcon: const Icon(
                            Remix.map_pin_range_line,
                            size: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? 'Location is required'
                            : null,
                      ),

                      const SizedBox(height: 16),

                      // Date & Time Selectors (Clean modern cards)
                      _buildSectionHeader('Date & Time *', Remix.time_line),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Date selector
                          Expanded(
                            child: InkWell(
                              onTap: _selectDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Remix.calendar_2_line,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _formatDate(_selectedDate),
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Time selector
                          Expanded(
                            child: InkWell(
                              onTap: _selectTime,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Remix.time_line,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedTime.format(context),
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Assign Visitor / Field Officer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader(
                            'Assign Visitor / Field Officer *',
                            Remix.user_star_line,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E7FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Visitors Only',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF3730A3),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      if (_isLoadingEmployees)
                        Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_visitorEmployees.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Remix.error_warning_line,
                                size: 18,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No visitor or field officers found. Please assign "Visitor" or "Field Officer" designation to an employee in Admin Settings.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<int>(
                          initialValue:
                              _visitorEmployees.any(
                                (e) => e['id'] == _selectedEmployeeId,
                              )
                              ? _selectedEmployeeId
                              : null,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Remix.user_star_line,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          isExpanded: true,
                          items: _visitorEmployees.map((emp) {
                            final name =
                                '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'
                                    .trim();
                            final code = emp['employeeCode'] ?? '';
                            final desig =
                                (emp['designation'] is Map
                                    ? emp['designation']['name']
                                    : emp['designationName']) ??
                                'Field Officer';
                            return DropdownMenuItem<int>(
                              value: emp['id'] as int,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name.isNotEmpty
                                          ? name
                                          : 'Employee #${emp['id']}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (code.toString().isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '($code)',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFFA7F3D0),
                                      ),
                                    ),
                                    child: Text(
                                      desig.toString(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedEmployeeId = val);
                          },
                        ),

                      const SizedBox(height: 16),

                      // Preparation Notes
                      _buildSectionHeader(
                        'Preparation Notes',
                        Remix.file_text_line,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        style: GoogleFonts.outfit(fontSize: 13),
                        decoration: InputDecoration(
                          hintText:
                              'Key stakeholder names, presentation items, or special instructions...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Fixed Bottom Action Area
            Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, footerBottomPadding),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.7),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'CONFIRM VISIT SCHEDULE',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
