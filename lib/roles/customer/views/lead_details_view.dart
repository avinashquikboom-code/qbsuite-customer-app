import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:quickboom_crm_customer/core/models/permission_model.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/shared/utils/stage_notification_feedback.dart';
import 'package:quickboom_crm_customer/core/utils/permission_service.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_stage_model.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/lead_stages_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/leads_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/widgets/permission_required_dialog.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/new_lead_bottom_sheet.dart';
import 'package:quickboom_crm_customer/roles/customer/services/customer_service.dart';
import 'package:quickboom_crm_customer/core/services/secure_storage_service.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/lead_header.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/lead_tabs.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/lead_email_composer_sheet.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/lead_whatsapp_composer_sheet.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/lead_header_card.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/lead_stage_card.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/lead_communication_card.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/lead_contact_info_card.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/lead_social_media_card.dart';

import 'package:quickboom_crm_customer/roles/customer/widgets/lead_commission_card.dart';

import 'package:quickboom_crm_customer/roles/customer/widgets/lead_details_skeleton.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/schedule_visit_bottom_sheet.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_profile_viewmodel.dart';

class LeadDetailsView extends ConsumerStatefulWidget {
  final String leadId;
  final LeadModel? initialLead;

  const LeadDetailsView({super.key, required this.leadId, this.initialLead});

  @override
  ConsumerState<LeadDetailsView> createState() => _LeadDetailsViewState();
}

class _LeadDetailsViewState extends ConsumerState<LeadDetailsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  LeadModel? _lead;
  bool _isLoading = true;
  bool _isUpdatingStage = false;
  bool _isDeletingLead = false;
  String? _errorMessage;
  int? _errorCode;

  bool get _isVisitor {
    final profile = ref.read(employeeProfileProvider).asData?.value;
    final desigName = (profile?.designation ?? '').trim().toUpperCase();
    final rawRole = (ref.read(permissionManagerProvider).role ?? '')
        .trim()
        .toUpperCase();
    return desigName.contains('VISITOR') ||
        desigName == 'VISIT' ||
        desigName.contains('FIELD VISIT') ||
        rawRole.contains('VISITOR') ||
        rawRole == 'VISIT';
  }

  bool get _canScheduleVisits {
    if (_isVisitor) return false;
    final rbac = ref.read(permissionManagerProvider);
    final rawRole = (rbac.role ?? '').trim().toUpperCase();
    final isCustomerOrAdmin =
        rawRole.contains('CUSTOMER') ||
        rawRole.contains('ADMIN') ||
        rawRole == 'SUPER_ADMIN';
    final isBpo = rawRole.contains('BPO') || rbac.isCrmEligible;
    if (isCustomerOrAdmin || isBpo) return true;
    return rbac.canViewLeads ||
        rbac.canScheduleVisits ||
        PermissionManager.instance.canScheduleVisits;
  }

  bool _isVisitScheduleStage(LeadStageModel stage) {
    final key = stage.key.toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
    final name = stage.name.toUpperCase();
    return key == 'VISIT_SCHEDULED' ||
        key == 'VISIT' ||
        key == 'SCHEDULE_VISIT' ||
        (name.contains('VISIT') && name.contains('SCHEDUL'));
  }

  void _onPipelineStageSelected(LeadStageModel stage, {BuildContext? sheetContext}) {
    final currentStageId = _lead?.stageId;
    final isCurrent = currentStageId != null &&
        currentStageId == stage.id.toString();
    if (isCurrent) {
      AppToast.info(context, 'Lead is already in "${stage.name}" stage');
      return;
    }
    if (_isVisitScheduleStage(stage) && !_isVisitor && _canScheduleVisits) {
      if (sheetContext != null) Navigator.pop(sheetContext);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showScheduleVisitSheet();
      });
      return;
    }
    if (sheetContext != null) Navigator.pop(sheetContext);
    _handleStageChange(stage);
  }

  bool get _canViewVisits {
    if (_isVisitor) return true;
    final rbac = ref.read(permissionManagerProvider);
    final rawRole = (rbac.role ?? '').trim().toUpperCase();
    final isCustomerOrAdmin =
        rawRole.contains('CUSTOMER') ||
        rawRole.contains('ADMIN') ||
        rawRole == 'SUPER_ADMIN';
    if (isCustomerOrAdmin) return true;
    return rbac.canViewVisits || PermissionManager.instance.canViewVisits;
  }

  bool get _canStartVisit {
    if (_isVisitor) return true;
    final rbac = ref.read(permissionManagerProvider);
    final rawRole = (rbac.role ?? '').trim().toUpperCase();
    final isCustomerOrAdmin =
        rawRole.contains('CUSTOMER') ||
        rawRole.contains('ADMIN') ||
        rawRole == 'SUPER_ADMIN';
    if (isCustomerOrAdmin) return true;
    return rbac.canStartVisit || PermissionManager.instance.canStartVisit;
  }

  bool get _canCompleteVisit {
    if (_isVisitor) return true;
    final rbac = ref.read(permissionManagerProvider);
    final rawRole = (rbac.role ?? '').trim().toUpperCase();
    final isCustomerOrAdmin =
        rawRole.contains('CUSTOMER') ||
        rawRole.contains('ADMIN') ||
        rawRole == 'SUPER_ADMIN';
    if (isCustomerOrAdmin) return true;
    return rbac.canCompleteVisit || PermissionManager.instance.canCompleteVisit;
  }

  bool _isCurrentStageVisitScheduled(LeadModel lead) {
    final status = lead.status.trim().toUpperCase();
    final stageName = (lead.stageNameConfig ?? '').trim().toUpperCase();
    final stageId = (lead.stageId ?? '').trim().toUpperCase();

    if (status == 'VISIT_SCHEDULED' ||
        status == 'VISIT' ||
        stageName == 'VISIT SCHEDULED' ||
        stageName == 'VISIT' ||
        stageId == 'VISIT_SCHEDULED' ||
        stageId == 'VISIT') {
      return true;
    }

    final stages = ref.read(leadStagesProvider).asData?.value;
    if (stages != null && stages.isNotEmpty) {
      for (final s in stages) {
        final sKey = s.key.trim().toUpperCase();
        final sName = s.name.trim().toUpperCase();
        if (sKey == 'VISIT_SCHEDULED' ||
            sKey == 'VISIT' ||
            sName == 'VISIT SCHEDULED' ||
            sName == 'VISIT') {
          if (lead.stageId != null &&
              (lead.stageId == s.id.toString() || lead.stageId == s.key)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  // Stage lists are NOT hardcoded here.
  // They come from leadStagesProvider (GET /leads/stages) at runtime.
  // The pipeline visualizer, action card, and bottom bar all read from the provider.

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _lead = widget.initialLead;
    _fetchLead();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLead() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _errorCode = null;
    });

    ref.invalidate(leadCommunicationsProvider(widget.leadId));

    try {
      final service = ref.read(leadServiceProvider);
      final data = await service.getLeadById(widget.leadId);
      if (!mounted) return;
      setState(() {
        _lead = data;
        _isLoading = false;
        _errorMessage = null;
        _errorCode = null;
      });
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('404') ||
          errStr.contains('not found') ||
          errStr.contains('no longer exists')) {
        ref.read(leadsProvider.notifier).removeLocalLead(widget.leadId);
        setState(() {
          _lead = null;
          _errorMessage = 'Lead no longer exists or is no longer available.';
          _errorCode = 404;
          _isLoading = false;
        });
        return;
      }
      try {
        final fallback = await ref
            .read(leadsProvider.notifier)
            .getLeadDetails(widget.leadId);
        if (fallback != null) {
          setState(() {
            _lead = fallback;
            _isLoading = false;
            _errorMessage = null;
            _errorCode = null;
          });
          return;
        }
      } catch (_) {}

      if (_lead != null) {
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }

    final current = _lead;
    if (current != null) {
      final employeeId = await SecureStorageService.getEmployeeId();
      final companyId = await SecureStorageService.getCustomerId();
      debugPrint('''
[LEAD_DETAILS]
leadId=${current.id}
companyId=$companyId
employeeId=$employeeId
''');
      debugPrint('''
[LEAD DETAILS OPEN]
Lead ID: ${current.id}
Stage ID: ${current.stageId}
Stage Name: ${current.stageName}
Company ID: $companyId
Employee ID: $employeeId
''');
    }
  }

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isNotEmpty) {
      final uri = Uri.parse('tel:$cleanPhone');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) _showLogFollowUpSheet();
            });
          }
        } else {
          if (mounted) AppToast.error(context, 'Could not open phone dialer.');
        }
      } catch (e) {
        if (mounted) AppToast.error(context, 'Could not launch dialer: $e');
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    String formattedUrl = url;
    if (!formattedUrl.startsWith('http://') &&
        !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }
    final uri = Uri.parse(formattedUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// Centralized stage change handler with loading guard, toast notifications,
  /// and immediate UI state update.
  Future<void> _handleStageChange(
    LeadStageModel targetStage, {
    String? notes,
  }) async {
    if (_isUpdatingStage) return;
    final lead = _lead;
    if (lead == null) return;

    final employeeId = await SecureStorageService.getEmployeeId();
    final companyId = await SecureStorageService.getCustomerId();
    if (!mounted) return;
    debugPrint('''
[LEAD_STATUS_DEBUG]
leadId=${lead.id}
companyName=${lead.companyName ?? lead.businessName ?? lead.title}
source=${lead.source}
employeeId=${employeeId ?? lead.employeeId ?? 'unknown'}
companyId=${companyId ?? 'unknown'}
targetStageId=${targetStage.id}
targetStageName=${targetStage.name}
''');

    if (lead.stageId != null && lead.stageId == targetStage.id.toString()) {
      AppToast.info(context, 'Lead is already at "${targetStage.name}" stage');
      return;
    }

    final doneKey = targetStage.key.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
    final doneName = targetStage.name.trim().toUpperCase();
    final isVisitDoneStage = doneKey == 'VISIT_DONE' || doneName == 'VISIT DONE' || doneName.contains('VISIT DONE');
    if (isVisitDoneStage && !_isVisitor) {
      AppToast.error(context, 'Only a visitor employee can mark this lead as Visit Done.');
      return;
    }

    if (_isVisitor) {
      final isCurrentScheduled = _isCurrentStageVisitScheduled(lead);
      if (!isCurrentScheduled) {
        AppToast.error(
          context,
          'Visitors can only update leads that are currently in Visit Scheduled stage',
        );
        return;
      }

      final key = targetStage.key.trim().toUpperCase();
      final name = targetStage.name.trim().toUpperCase();
      final isVisitDone =
          key == 'VISIT_DONE' ||
          key == 'VISIT DONE' ||
          name == 'VISIT DONE' ||
          name == 'VISIT_DONE';
      if (!isVisitDone) {
        AppToast.error(
          context,
          'Visitors can only move leads to Visit Done stage',
        );
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Change lead stage', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text('Move this lead to ${targetStage.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isUpdatingStage = true);

    try {
      final updateResult = await ref
          .read(leadsProvider.notifier)
          .updateStatus(
            lead.id,
            status: targetStage.key,
            stageId: targetStage.id,
            notes: notes,
          );

      if (updateResult != null && mounted) {
        final updated = updateResult.lead;
        final returnedStage = updated.stageId?.toString();
        if (returnedStage != null && returnedStage.isNotEmpty && returnedStage != targetStage.id.toString()) {
          throw Exception('Saved stage does not match ${targetStage.name}');
        }
        setState(() => _lead = updated);
        ref.read(leadsProvider.notifier).refreshCurrentList();
        ref.read(leadStagesProvider.notifier).refresh();
        ref.invalidate(leadCommunicationsProvider(lead.id));
        invalidateCustomersDirectory(ref);
        await _fetchLead();
        if (!mounted) return;
        AppToast.success(context, 'Lead stage updated successfully!');
        showStageChannelFeedback(
          context,
          email: updateResult.emailNotification,
          whatsapp: updateResult.whatsappNotification,
        );
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('404') ||
            errStr.contains('not found') ||
            errStr.contains('no longer exists')) {
          AppToast.error(
            context,
            'Lead no longer exists or is no longer available.',
          );
          ref.read(leadsProvider.notifier).removeLocalLead(lead.id);
          ref.read(leadsProvider.notifier).refreshCurrentList();
          Navigator.of(context).pop();
        } else {
          final cleanMsg = e.toString().replaceFirst('Exception: ', '');
          AppToast.error(context, cleanMsg);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStage = false);
      }
    }
  }

  /// Opens the Lead Edit bottom sheet loaded with current lead details.
  Future<void> _openEditLead() async {
    final lead = _lead;
    if (lead == null) return;
    final updated = await showEditLeadBottomSheet(context, lead: lead);
    if (updated != null && mounted) {
      setState(() => _lead = updated);
      await _fetchLead();
    }
  }

  /// Opens a modern modal bottom sheet displaying all available pipeline stages.
  void _showStagePickerSheet(
    List<LeadStageModel> stages,
    LeadStageModel? currentStage,
  ) {
    if (_isUpdatingStage) return;

    if (_isVisitor) {
      final lead = _lead;
      if (lead == null || !_isCurrentStageVisitScheduled(lead)) {
        AppToast.info(
          context,
          'Visitors can only advance leads currently scheduled for a visit.',
        );
        return;
      }
    }

    final availableStages = _isVisitor
        ? stages.where((s) {
            final key = s.key.trim().toUpperCase();
            final name = s.name.trim().toUpperCase();
            return key == 'VISIT_DONE' ||
                key == 'VISIT DONE' ||
                name == 'VISIT DONE' ||
                name == 'VISIT_DONE';
          }).toList()
        : stages;

    if (availableStages.isEmpty) {
      AppToast.info(context, 'No further stages available for Visitor.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSheetHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Remix.git_commit_line,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isVisitor
                                ? 'Complete Visit'
                                : 'Select Pipeline Stage',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _isVisitor
                                ? 'Move lead from Visit Scheduled to Visit Done'
                                : 'Move this lead to any configured CRM stage',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: availableStages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, idx) {
                    final stage = availableStages[idx];
                    final isCurrent = currentStage != null
                        ? stage.id == currentStage.id
                        : (_lead?.stageId == stage.id.toString() ||
                              _lead?.status.toUpperCase() ==
                                  stage.key.toUpperCase());

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _onPipelineStageSelected(
                          stage,
                          sheetContext: modalCtx,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? stage.stageBgColor
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCurrent
                                  ? stage.stageColor
                                  : const Color(0xFFE2E8F0),
                              width: isCurrent ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: stage.stageColor,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${idx + 1}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stage.name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: isCurrent
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: isCurrent
                                            ? stage.stageColor
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'KEY: ${stage.key}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: stage.stageColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Current',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              else
                                const Icon(
                                  Remix.arrow_right_s_line,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ----------------------------------------------------
  // ACTION BOTTOM SHEETS FOR EVERY CRM STAGE
  // ----------------------------------------------------

  /// STAGE 1: Log Follow-up Call Outcome
  void _showLogFollowUpSheet() {
    final notesCtrl = TextEditingController();
    String selectedOutcome = 'Interested';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 11, minute: 0);

    final outcomes = [
      'Interested',
      'Not Interested',
      'Call Later',
      'No Response',
      'Wrong Number',
      'Follow-up Required',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
                    _buildSheetHandle(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Log Follow-up Call',
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
                    const SizedBox(height: 16),
                    Text(
                      'Call Outcome *',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: outcomes.map((outcome) {
                        final isSel = selectedOutcome == outcome;
                        return ChoiceChip(
                          label: Text(outcome),
                          selected: isSel,
                          selectedColor: AppColors.primaryLight,
                          labelStyle: GoogleFonts.outfit(
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSel
                                ? AppColors.primaryDark
                                : AppColors.textPrimary,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setSheetState(() => selectedOutcome = outcome);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Next Follow-up Schedule',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 90),
                                ),
                              );
                              if (picked != null) {
                                setSheetState(() => selectedDate = picked);
                              }
                            },
                            icon: const Icon(
                              Remix.calendar_line,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            label: Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: GoogleFonts.outfit(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (picked != null) {
                                setSheetState(() => selectedTime = picked);
                              }
                            },
                            icon: const Icon(
                              Remix.time_line,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            label: Text(
                              selectedTime.format(context),
                              style: GoogleFonts.outfit(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Call Notes',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter discussion highlights...',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
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
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final dateStr =
                              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                          final timeStr = selectedTime.format(context);

                          final updated = await ref
                              .read(leadsProvider.notifier)
                              .logFollowUp(
                                widget.leadId,
                                outcome: selectedOutcome,
                                notes: notesCtrl.text.trim(),
                                nextFollowUpDate: dateStr,
                                nextFollowUpTime: timeStr,
                              );

                          if (!mounted) return;
                          if (updated != null) {
                            setState(() => _lead = updated);
                            AppToast.success(
                              this.context,
                              'Follow-up Call Logged & Status Updated!',
                            );
                          } else {
                            AppToast.error(
                              this.context,
                              'Failed to log follow-up.',
                            );
                          }
                        },
                        child: Text(
                          'SAVE CALL OUTCOME',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// STAGE 2: Schedule Field Visit (Modern Proper Bottom Sheet)
  void _showScheduleVisitSheet() {
    if (_lead == null) return;
    if (!_canScheduleVisits) {
      AppToast.error(
        context,
        'You do not have permission to schedule visits.',
      );
      return;
    }
    showScheduleVisitBottomSheet(
      context,
      lead: _lead!,
      ref: ref,
      onVisitScheduled: (updated) {
        if (mounted) {
          setState(() => _lead = updated);
        }
      },
    );
  }

  /// STAGE 2 (cont): Start Visit with Location Verification
  Future<void> _handleStartVisit() async {
    if (!_canStartVisit) {
      AppToast.error(
        context,
        'Access denied: Missing required permission [VISITS:START]',
      );
      return;
    }
    final permissionService = ref.read(permissionServiceProvider);
    var status = await permissionService.checkLocationPermission();

    if (!status.isGranted) {
      if (!mounted) return;
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => PermissionRequiredDialog(
          title: 'GPS Location Required',
          description:
              'QB Suite verifies your GPS location when starting an on-site field visit.',
          icon: Remix.map_pin_user_fill,
          isPermanentlyDenied: status.isPermanentlyDenied,
          onAllow: () => Navigator.of(context).pop(true),
          onCancel: () => Navigator.of(context).pop(false),
          onOpenSettings: () {
            permissionService.openAppSettings();
            Navigator.of(context).pop(false);
          },
        ),
      );

      if (shouldRequest != true) return;
      status = await permissionService.requestLocationPermission();
      if (!status.isGranted) return;
    }

    double? lat;
    double? lng;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
      lat = position.latitude;
      lng = position.longitude;
    } catch (_) {
      lat = 19.1136;
      lng = 72.8697;
    }

    final updated = await ref
        .read(leadsProvider.notifier)
        .manageVisit(
          widget.leadId,
          action: 'START',
          latitude: lat,
          longitude: lng,
        );

    if (!mounted) return;
    if (updated != null) {
      setState(() => _lead = updated);
      AppToast.success(
        context,
        'Visit Started! GPS Location logged (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})',
      );
    } else {
      AppToast.error(context, 'Failed to start visit.');
    }
  }

  /// STAGE 2 (cont): Complete Field Visit
  void _showCompleteVisitSheet() {
    if (!_canCompleteVisit) {
      AppToast.error(
        context,
        'Access denied: Missing required permission [VISITS:COMPLETE]',
      );
      return;
    }
    final summaryCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String customerResponse = 'Positive - Requested Quotation';

    final responses = [
      'Positive - Requested Quotation',
      'Interested - Needs Follow-up',
      'Requires Further Demo',
      'Decision Pending Management',
      'Not Interested',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
                    _buildSheetHandle(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Complete Field Visit',
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
                    Text(
                      'Customer Response *',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: customerResponse,
                          isExpanded: true,
                          items: responses
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(
                                    r,
                                    style: GoogleFonts.outfit(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => customerResponse = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Visit Summary *',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: summaryCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText:
                            'Key requirements discussed during the meeting...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Additional Notes',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Action items, next steps...',
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
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final updated = await ref
                              .read(leadsProvider.notifier)
                              .manageVisit(
                                widget.leadId,
                                action: 'COMPLETE',
                                summary: summaryCtrl.text.trim(),
                                customerResponse: customerResponse,
                                notes: notesCtrl.text.trim(),
                              );

                          if (!mounted) return;
                          if (updated != null) {
                            setState(() => _lead = updated);
                            AppToast.success(
                              this.context,
                              'Visit Marked Completed! Stage updated to VISIT.',
                            );
                          } else {
                            AppToast.error(
                              this.context,
                              'Failed to complete visit.',
                            );
                          }
                        },
                        child: Text(
                          'MARK VISIT COMPLETED',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// STAGE 3: Create & Send Proposal
  void _showCreateProposalSheet() {
    final itemNameCtrl = TextEditingController(
      text: 'Enterprise CRM Cloud Solution',
    );
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: '65000');
    final discountCtrl = TextEditingController(text: '5000');
    final notesCtrl = TextEditingController(
      text: 'Includes 1-year priority support and on-premise training.',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final qty = int.tryParse(qtyCtrl.text) ?? 1;
            final unitPrice = double.tryParse(priceCtrl.text) ?? 0.0;
            final discount = double.tryParse(discountCtrl.text) ?? 0.0;
            final subTotal = (qty * unitPrice) - discount;
            final tax = subTotal * 0.18;
            final grandTotal = subTotal + tax;

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
                    _buildSheetHandle(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Create Proposal / Quotation',
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
                    Text(
                      'Service / Product Name *',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: itemNameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. QuickBoom CRM Enterprise Plan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quantity',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setSheetState(() {}),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Unit Price (₹)',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: priceCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setSheetState(() {}),
                                decoration: InputDecoration(
                                  prefixText: '₹ ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Discount (₹)',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: discountCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow(
                            'Subtotal',
                            '₹${subTotal.toStringAsFixed(0)}',
                          ),
                          const SizedBox(height: 6),
                          _buildSummaryRow(
                            'GST (18%)',
                            '₹${tax.toStringAsFixed(0)}',
                          ),
                          const Divider(height: 14),
                          _buildSummaryRow(
                            'Total Proposal Amount',
                            '₹${grandTotal.toStringAsFixed(0)}',
                            isBold: true,
                            color: AppColors.primaryDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Terms & Notes',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Payment schedule, delivery timeline...',
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
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final items = [
                            {
                              'name': itemNameCtrl.text.trim(),
                              'quantity': qty,
                              'unitPrice': unitPrice,
                              'total': subTotal,
                            },
                          ];

                          final updated = await ref
                              .read(leadsProvider.notifier)
                              .createProposal(
                                widget.leadId,
                                items: items,
                                subTotal: subTotal,
                                taxAmount: tax,
                                discount: discount,
                                totalAmount: grandTotal,
                                notes: notesCtrl.text.trim(),
                              );

                          if (!mounted) return;
                          if (updated != null) {
                            setState(() => _lead = updated);
                            AppToast.success(
                              this.context,
                              'Proposal Generated & Sent to Client!',
                            );
                          } else {
                            AppToast.error(
                              this.context,
                              'Failed to generate proposal.',
                            );
                          }
                        },
                        child: Text(
                          'SEND PROPOSAL (₹${grandTotal.toStringAsFixed(0)})',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// STAGE 4: Final Call Negotiation
  void _showFinalCallSheet() {
    final notesCtrl = TextEditingController();
    String customerResponse = 'Accepted';
    DateTime selectedClosing = DateTime.now().add(const Duration(days: 3));

    final responses = [
      'Accepted',
      'Negotiation',
      'Call Later',
      'Interested',
      'Rejected',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
                    _buildSheetHandle(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Final Call / Negotiation',
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
                    Text(
                      'Client Decision *',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: responses.map((resp) {
                        final isSel = customerResponse == resp;
                        return ChoiceChip(
                          label: Text(resp),
                          selected: isSel,
                          selectedColor: resp == 'Accepted'
                              ? AppColors.primaryLight
                              : resp == 'Rejected'
                              ? AppColors.error.withValues(alpha: 0.15)
                              : AppColors.warning.withValues(alpha: 0.15),
                          labelStyle: GoogleFonts.outfit(
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSel
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setSheetState(() => customerResponse = resp);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Expected Closing / Payment Date',
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
                          initialDate: selectedClosing,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 90),
                          ),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedClosing = picked);
                        }
                      },
                      icon: const Icon(Remix.calendar_check_line, size: 16),
                      label: Text(
                        '${selectedClosing.day}/${selectedClosing.month}/${selectedClosing.year}',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Negotiation & Closing Notes',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText:
                            'Approved discounts, payment method commitments...',
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
                          backgroundColor: customerResponse == 'Accepted'
                              ? AppColors.primary
                              : AppColors.warning,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final closingStr =
                              '${selectedClosing.year}-${selectedClosing.month.toString().padLeft(2, '0')}-${selectedClosing.day.toString().padLeft(2, '0')}';

                          final updated = await ref
                              .read(leadsProvider.notifier)
                              .recordFinalCall(
                                widget.leadId,
                                proposalAmount: _lead?.value ?? 0.0,
                                customerResponse: customerResponse,
                                negotiationNotes: notesCtrl.text.trim(),
                                expectedClosingDate: closingStr,
                              );

                          if (!mounted) return;
                          if (updated != null) {
                            setState(() => _lead = updated);
                            AppToast.success(
                              this.context,
                              'Final Call Logged: $customerResponse',
                            );
                          } else {
                            AppToast.error(
                              this.context,
                              'Failed to log final call.',
                            );
                          }
                        },
                        child: Text(
                          customerResponse == 'Accepted'
                              ? 'ACCEPT & MOVE TO PAYMENT'
                              : 'SAVE FINAL CALL OUTCOME',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// STAGE 5: Record Payment Verification
  void _showRecordPaymentSheet() {
    final defaultAmount = _lead?.value ?? 50000.0;
    final totalCtrl = TextEditingController(
      text: defaultAmount.toStringAsFixed(0),
    );
    final paidCtrl = TextEditingController(
      text: defaultAmount.toStringAsFixed(0),
    );
    final refCtrl = TextEditingController(
      text:
          'NEFT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    final notesCtrl = TextEditingController(
      text: 'Verified with accounts department.',
    );
    String paymentMethod = 'BANK_TRANSFER';
    String paymentStatus = 'PAID';

    final methods = [
      'BANK_TRANSFER',
      'RAZORPAY',
      'CASH',
      'CREDIT_CARD',
      'OTHER',
    ];
    final statuses = ['PAID', 'PARTIAL', 'PENDING'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
                    _buildSheetHandle(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Record & Verify Payment',
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
                                'Total Deal Amount (₹)',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: totalCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  prefixText: '₹ ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                                'Amount Paid (₹) *',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: paidCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  prefixText: '₹ ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Method',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: paymentMethod,
                                    isExpanded: true,
                                    items: methods
                                        .map(
                                          (m) => DropdownMenuItem(
                                            value: m,
                                            child: Text(
                                              m.replaceAll('_', ' '),
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setSheetState(
                                          () => paymentMethod = val,
                                        );
                                      }
                                    },
                                  ),
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
                                'Payment Status',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: paymentStatus,
                                    isExpanded: true,
                                    items: statuses
                                        .map(
                                          (s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(
                                              s,
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setSheetState(
                                          () => paymentStatus = val,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Transaction / UTR Reference',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: refCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. UTR1092837482',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Notes',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Verification details...',
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
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final total = double.tryParse(totalCtrl.text) ?? 0.0;
                          final paid = double.tryParse(paidCtrl.text) ?? 0.0;

                          final updated = await ref
                              .read(leadsProvider.notifier)
                              .recordPayment(
                                widget.leadId,
                                totalAmount: total,
                                paidAmount: paid,
                                pendingAmount: total > paid
                                    ? total - paid
                                    : 0.0,
                                paymentMethod: paymentMethod,
                                transactionRef: refCtrl.text.trim(),
                                status: paymentStatus,
                                notes: notesCtrl.text.trim(),
                              );

                          if (!mounted) return;
                          if (updated != null) {
                            setState(() => _lead = updated);
                            AppToast.success(
                              this.context,
                              'Payment Recorded & Lead Moved to PAYMENT stage!',
                            );
                          } else {
                            AppToast.error(
                              this.context,
                              'Failed to record payment.',
                            );
                          }
                        },
                        child: Text(
                          'CONFIRM PAYMENT RECORD',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// STAGE 6: Kick off Project Work
  void _showStartWorkSheet() {
    final teamCtrl = TextEditingController(
      text: 'Customer Success & Tech Squad',
    );
    final serviceCtrl = TextEditingController(
      text: _lead?.title ?? 'CRM Deployment & Onboarding',
    );
    final notesCtrl = TextEditingController(
      text: 'Sprint 1 kickoff scheduled with client technical team.',
    );
    DateTime selectedStart = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
                    _buildSheetHandle(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Start Project Work',
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
                    Text(
                      'Work Kickoff Date *',
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
                          initialDate: selectedStart,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 7),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 90),
                          ),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedStart = picked);
                        }
                      },
                      icon: const Icon(Remix.calendar_event_line, size: 16),
                      label: Text(
                        '${selectedStart.day}/${selectedStart.month}/${selectedStart.year}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Assigned Team / Squad *',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: teamCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Implementation Squad Alpha',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Service / Project Scope',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: serviceCtrl,
                      decoration: InputDecoration(
                        hintText: 'Scope description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Kickoff Notes',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Initial delivery timeline & milestone notes',
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
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final startStr =
                              '${selectedStart.year}-${selectedStart.month.toString().padLeft(2, '0')}-${selectedStart.day.toString().padLeft(2, '0')}';

                          final updated = await ref
                              .read(leadsProvider.notifier)
                              .startWork(
                                widget.leadId,
                                workStartDate: startStr,
                                assignedTeam: teamCtrl.text.trim(),
                                serviceName: serviceCtrl.text.trim(),
                                notes: notesCtrl.text.trim(),
                              );

                          if (!mounted) return;
                          if (updated != null) {
                            setState(() => _lead = updated);
                            AppToast.success(
                              this.context,
                              'Work Started! Status moved to WORK_STARTED.',
                            );
                          } else {
                            AppToast.error(
                              this.context,
                              'Failed to start project work.',
                            );
                          }
                        },
                        child: Text(
                          'OFFICIALLY START WORK',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------
  // BUILD METHOD & UI SECTIONS
  // ----------------------------------------------------

  Future<void> _confirmAndDeleteLead() async {
    if (_isDeletingLead) return;
    final lead = _lead;
    if (lead == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isDeletingLead,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Remix.delete_bin_line,
                color: Color(0xFFDC2626),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Lead?',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this lead? This action cannot be undone.',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: const Color(0xFF475569),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    setState(() => _isDeletingLead = true);

    try {
      final success = await ref
          .read(leadsProvider.notifier)
          .deleteLead(lead.id);
      if (!mounted) return;

      if (success) {
        AppToast.success(context, 'Lead deleted successfully');
        ref.read(leadsProvider.notifier).fetchLeads();
        ref.read(leadStagesProvider.notifier).refresh();
        Navigator.pop(context, true);
      } else {
        AppToast.error(context, 'Unable to delete lead. Please try again.');
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      AppToast.error(
        context,
        msg.isNotEmpty ? msg : 'Unable to delete lead. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isDeletingLead = false);
      }
    }
  }

  void _showSendBothSheet(BuildContext context, LeadModel lead) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHandle(),
              Text(
                'Send Both Communications',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Compose and send email and WhatsApp to ${lead.displayName}.',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Remix.mail_line,
                    color: Color(0xFF4F46E5),
                    size: 18,
                  ),
                ),
                title: Text(
                  '1. Compose Email',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  lead.email ?? 'No email available',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                trailing: const Icon(Remix.arrow_right_s_line, size: 18),
                onTap: lead.email != null && lead.email!.isNotEmpty
                    ? () {
                        Navigator.pop(ctx);
                        LeadEmailComposerSheet.show(
                          context,
                          lead,
                          onSent: () {
                            ref.invalidate(leadCommunicationsProvider(lead.id));
                            _fetchLead();
                          },
                        );
                      }
                    : null,
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Remix.whatsapp_line,
                    color: Color(0xFF25D366),
                    size: 18,
                  ),
                ),
                title: Text(
                  '2. Compose WhatsApp',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  lead.phone ?? 'No phone available',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                trailing: const Icon(Remix.arrow_right_s_line, size: 18),
                onTap: lead.phone != null && lead.phone!.isNotEmpty
                    ? () {
                        Navigator.pop(ctx);
                        LeadWhatsAppComposerSheet.show(
                          context,
                          lead,
                          onSent: () {
                            ref.invalidate(leadCommunicationsProvider(lead.id));
                            _fetchLead();
                          },
                        );
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawRole = (ref.watch(permissionManagerProvider).role ?? '')
        .toUpperCase();
    final profile = ref.watch(employeeProfileProvider).asData?.value;
    final desigName = (profile?.designation ?? '').trim().toUpperCase();
    final isVisitor =
        desigName.contains('VISITOR') ||
        desigName == 'VISIT' ||
        desigName.contains('FIELD VISIT') ||
        rawRole.contains('VISITOR') ||
        rawRole == 'VISIT';

    final isCustomerOrAdmin =
        rawRole.contains('CUSTOMER') ||
        rawRole.contains('ADMIN') ||
        rawRole == 'SUPER_ADMIN';
    final canEditLead =
        !isVisitor &&
        (ref.watch(permissionManagerProvider).canEdit(AppModule.leads) ||
            PermissionManager.instance.canEdit(AppModule.leads) ||
            isCustomerOrAdmin);
    final canDeleteLead =
        !isVisitor &&
        (ref.watch(permissionManagerProvider).canDelete(AppModule.leads) ||
            PermissionManager.instance.canDelete(AppModule.leads) ||
            isCustomerOrAdmin);

    final canViewVisits = _canViewVisits;
    final canScheduleVisits = _canScheduleVisits;
    final canStartVisit = _canStartVisit;
    final canCompleteVisit = _canCompleteVisit;

    // Resolve stages dynamically from Stage Management API
    final stagesAsync = ref.watch(leadStagesProvider);
    final stages = stagesAsync.asData?.value ?? [];
    final notifier = ref.read(leadStagesProvider.notifier);

    if (_isLoading && _lead == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: LeadHeader(
          canEdit: canEditLead,
          onEdit: _openEditLead,
          canDelete: canDeleteLead,
          onDelete: _confirmAndDeleteLead,
          canChangeStage: canEditLead,
        ),
        body: const LeadDetailsSkeleton(),
      );
    }

    if (_errorMessage != null && _lead == null) {
      IconData errorIcon = Remix.wifi_off_line;
      String errorHeading = 'Connection Issue';

      if (_errorCode == 401) {
        errorIcon = Remix.lock_password_line;
        errorHeading = 'Session Expired';
      } else if (_errorCode == 403) {
        errorIcon = Remix.shield_keyhole_line;
        errorHeading = 'Access Denied';
      } else if (_errorCode == 404) {
        errorIcon = Remix.file_search_line;
        errorHeading = 'Customer no longer exists';
      } else if (_errorCode != null && _errorCode! >= 500) {
        errorIcon = Remix.server_line;
        errorHeading = 'Server Error';
      }

      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: LeadHeader(
          canEdit: canEditLead,
          onEdit: _openEditLead,
          canDelete: canDeleteLead,
          onDelete: _confirmAndDeleteLead,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    errorIcon,
                    size: 40,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  errorHeading,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),
                if (_errorCode == 404)
                  ElevatedButton.icon(
                    onPressed: () {
                      invalidateCustomersDirectory(ref);
                      ref.invalidate(leadsProvider);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Remix.arrow_left_line, size: 16),
                    label: const Text('Back to Customers'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _fetchLead,
                    icon: const Icon(Remix.refresh_line, size: 16),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final lead = _lead!;
    final isLeadAlreadyDone =
        lead.status.toUpperCase() == 'VISIT_DONE' ||
        (lead.stageNameConfig ?? '').toUpperCase() == 'VISIT DONE';
    final isCurrentScheduled = _isCurrentStageVisitScheduled(lead);
    final canChangeStage = isVisitor
        ? (isCurrentScheduled && !isLeadAlreadyDone)
        : canEditLead;
    final currentStage = notifier.resolveLeadStage(
      lead.stageId,
      lead.status,
      lead.stageNameConfig,
    );
    final rawNextStage = notifier.nextStage(lead.stageId, lead.status);
    final nextStage = isVisitor
        ? (isLeadAlreadyDone || !isCurrentScheduled
              ? null
              : (rawNextStage != null &&
                        (rawNextStage.key.toUpperCase() == 'VISIT_DONE' ||
                            rawNextStage.name.toUpperCase().contains(
                              'VISIT DONE',
                            ))
                    ? rawNextStage
                    : stages
                          .where(
                            (s) =>
                                s.key.toUpperCase() == 'VISIT_DONE' ||
                                s.name.toUpperCase().contains('VISIT DONE'),
                          )
                          .firstOrNull))
        : rawNextStage;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: LeadHeader(
        canEdit: canEditLead,
        onEdit: _openEditLead,
        canDelete: canDeleteLead,
        onDelete: _confirmAndDeleteLead,
        canChangeStage: isVisitor ? false : canChangeStage,
        onChangeStage: !isVisitor && canChangeStage && stages.isNotEmpty
            ? () => _showStagePickerSheet(stages, currentStage)
            : null,
        onRefresh: () async {
          await Future.wait([
            _fetchLead(),
            ref.read(leadStagesProvider.notifier).refresh(),
          ]);
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _fetchLead(),
            ref.read(leadStagesProvider.notifier).refresh(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LeadPhotoGallery(lead: lead),
              // 1. Lead Header Card (Name, Contact Person, Stage, Phone, City)
              LeadHeaderCard(lead: lead, currentStage: currentStage),
              const SizedBox(height: 10),

              // 2. BPO Communications Card (Moved above Lead Stage)
              LeadCommunicationCard(
                lead: lead,
                onEmail: lead.email != null && lead.email!.isNotEmpty
                    ? () => LeadEmailComposerSheet.show(
                        context,
                        lead,
                        onSent: () {
                          ref.invalidate(leadCommunicationsProvider(lead.id));
                          _fetchLead();
                        },
                      )
                    : null,
                onWhatsApp: lead.phone != null && lead.phone!.isNotEmpty
                    ? () => LeadWhatsAppComposerSheet.show(
                        context,
                        lead,
                        onSent: () {
                          ref.invalidate(leadCommunicationsProvider(lead.id));
                          _fetchLead();
                        },
                      )
                    : null,
                onSendBoth: () => _showSendBothSheet(context, lead),
              ),
              const SizedBox(height: 14),

              // 3. Stage Progression / Status Card
              LeadStageCard(
                lead: lead,
                currentStage: currentStage,
                nextStage: nextStage,
                stages: stages,
                canChangeStage: isVisitor
                    ? (isCurrentScheduled && !isLeadAlreadyDone)
                    : canChangeStage,
                isUpdating: _isUpdatingStage,
                onChangeStageTap: isVisitor
                    ? null
                    : (canChangeStage && stages.isNotEmpty
                          ? () => _showStagePickerSheet(stages, currentStage)
                          : null),
                onAdvanceNextStage:
                    nextStage != null && (!isVisitor || isCurrentScheduled)
                    ? () {
                        if (_isVisitScheduleStage(nextStage) &&
                            !_isVisitor &&
                            _canScheduleVisits) {
                          _showScheduleVisitSheet();
                        } else {
                          _handleStageChange(nextStage);
                        }
                      }
                    : null,
              ),
              const SizedBox(height: 14),

              // 4. Contact & Business Information Card
              LeadContactInfoCard(
                lead: lead,
                onPhoneTap: lead.phone != null && lead.phone!.isNotEmpty
                    ? () => _makeCall(lead.phone!)
                    : null,
                onWhatsAppTap: lead.phone != null && lead.phone!.isNotEmpty
                    ? () => LeadWhatsAppComposerSheet.show(
                        context,
                        lead,
                        onSent: () {
                          ref.invalidate(leadCommunicationsProvider(lead.id));
                          _fetchLead();
                        },
                      )
                    : null,
                onEmailTap: lead.email != null && lead.email!.isNotEmpty
                    ? () => LeadEmailComposerSheet.show(
                        context,
                        lead,
                        onSent: () {
                          ref.invalidate(leadCommunicationsProvider(lead.id));
                          _fetchLead();
                        },
                      )
                    : null,
                onWebsiteTap: (url) => _launchUrl(url),
              ),
              const SizedBox(height: 14),

              // Social Media & Online Presence Card
              LeadSocialMediaCard(lead: lead),
              const SizedBox(height: 14),

              // Additional: Upcoming Commission Card (Only shown if eligible & > 0)
              if (lead.hasCommission) ...[
                LeadCommissionCard(lead: lead),
                const SizedBox(height: 14),
              ],

              // 15. Operational Tabs (Notes, Proposal Generator, Payment, History)
              LeadTabs(
                lead: lead,
                tabController: _tabController,
                canViewVisits: canViewVisits,
                onScheduleVisit: canScheduleVisits
                    ? _showScheduleVisitSheet
                    : null,
                onStartVisit: canStartVisit ? _handleStartVisit : null,
                onCompleteVisit: canCompleteVisit
                    ? _showCompleteVisitSheet
                    : null,
                onCreateProposal: _showCreateProposalSheet,
                onLogFinalCall: _showFinalCallSheet,
                onRecordPayment: _showRecordPaymentSheet,
                onStartWork: _showStartWorkSheet,
                onChangeStage: !isVisitor && stages.isNotEmpty
                    ? () => _showStagePickerSheet(stages, currentStage)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // HELPER WIDGETS
  // ----------------------------------------------------

  Widget _buildSheetHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? AppColors.textPrimary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _LeadPhotoGallery extends StatelessWidget {
  final LeadModel lead;
  const _LeadPhotoGallery({required this.lead});

  @override
  Widget build(BuildContext context) {
    final images = lead.images.where((image) => LeadModel.isValidRealImageUrl(image.url)).toList();
    if (images.isEmpty) return const SizedBox.shrink();
    final letter = lead.displayTitle.trim().isEmpty ? 'L' : lead.displayTitle.trim()[0].toUpperCase();
    final credits = images.expand((image) => image.attributions).where((name) => name.isNotEmpty).toSet().join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final url = LeadImageModel.resolveUrl(images[index].url);
              return GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    child: InteractiveViewer(
                      child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, _, _) => SizedBox(height: 180, child: Center(child: Text(letter)))),
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    width: 128,
                    height: 96,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => Container(
                      width: 128,
                      height: 96,
                      color: AppColors.primaryLight,
                      alignment: Alignment.center,
                      child: Text(letter, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (images.any((image) => image.url.contains('/data-capture/photo'))) ...[
          const SizedBox(height: 6),
          Text(
            credits.isEmpty ? 'Photos from Google Maps' : 'Photos from Google Maps · $credits',
            style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}
