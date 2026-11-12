import 'package:dio/dio.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/services/crm_access.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/roles/customer/services/customer_service.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/schedule_visit_bottom_sheet.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart'
    as customer_model;
import 'package:quickboom_crm_customer/shared/models/lead_model.dart';
import 'package:quickboom_crm_customer/shared/models/lead_stage_model.dart';
import 'package:quickboom_crm_customer/shared/viewmodels/lead_stages_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/viewmodels/leads_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/utils/stage_notification_feedback.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/shared/widgets/lead_business_image.dart';
import 'package:quickboom_crm_customer/shared/widgets/contact_information_card.dart';
import 'package:quickboom_crm_customer/shared/widgets/social_media_profiles_card.dart';
import 'package:quickboom_crm_customer/shared/views/leads/edit_lead_page.dart';
import 'package:quickboom_crm_customer/shared/views/leads/send_details_sheet.dart';
import 'package:quickboom_crm_customer/shared/widgets/send_details_delivery_history_card.dart';

class LeadDetailsView extends ConsumerStatefulWidget {
  final String leadId;
  final LeadModel? initialLead;

  const LeadDetailsView({super.key, required this.leadId, this.initialLead});

  @override
  ConsumerState<LeadDetailsView> createState() => _LeadDetailsViewState();
}

class _LeadDetailsViewState extends ConsumerState<LeadDetailsView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  LeadModel? _lead;
  bool _isLoading = false;
  String? _loadError;
  bool _isUpdatingStage = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);
    _lead = widget.initialLead;
    _fetchLead();
  }

  @override
  void dispose() {
    _isUpdatingStage = false;
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isUpdatingStage) {
      _fetchLead();
    }
  }

  String _message(Object error) => error is DioException
      ? ApiException.fromDioException(error).message
      : error.toString().replaceFirst('Exception: ', '');

  String _readable(String value) {
    return value.trim().replaceAll('_', ' ').split(RegExp(r'\s+')).where((word) => word.isNotEmpty).map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}').join(' ');
  }

  Future<void> _openMail(LeadModel lead) async {
    final email = lead.email?.trim() ?? '';
    if (email.isEmpty) {
      AppToast.error(context, 'This lead has no email address.');
      return;
    }
    final launched = await launchUrl(Uri(scheme: 'mailto', path: email));
    if (!launched && mounted) AppToast.error(context, 'The email app could not be opened.');
  }

  Future<void> _openWhatsApp(LeadModel lead) async {
    final phone = lead.phone?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
    if (phone.isEmpty) {
      AppToast.error(context, 'This lead has no phone number.');
      return;
    }
    final launched = await launchUrl(Uri.parse('https://wa.me/$phone'), mode: LaunchMode.externalApplication);
    if (!launched && mounted) AppToast.error(context, 'WhatsApp could not be opened.');
  }

  Future<void> _openSendDetails(LeadModel lead) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendDetailsSheet(
        lead: lead,
        onDispatched: () {
          _fetchLead();
        },
      ),
    );
  }

  Future<void> _editLead(LeadModel lead) async {
    final updated = await Navigator.push<LeadModel>(
      context,
      MaterialPageRoute(builder: (_) => EditLeadPage(lead: lead)),
    );
    if (updated != null && mounted) setState(() => _lead = updated);
  }

  Future<void> _fetchLead() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final lead = await ref
          .read(leadsProvider.notifier)
          .getLeadDetails(widget.leadId);
      if (mounted && lead != null) {
        setState(() => _lead = lead);
        final placeId = lead.googlePlaceId ?? '';
        if ((lead.imageUrl ?? '').isEmpty && placeId.isNotEmpty && !placeId.startsWith('custom_')) {
          Future<void>.delayed(const Duration(seconds: 5), () async {
            if (!mounted) return;
            try {
              final again = await ref.read(leadsProvider.notifier).getLeadDetails(widget.leadId);
              if (!mounted || again == null || (again.imageUrl ?? '').isEmpty) return;
              setState(() => _lead = again);
            } catch (_) {}
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = _message(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _isVisitor {
    final rbac = ref.read(permissionManagerProvider);
    return isFieldVisitorActor(
      role: rbac.role,
      crmCategory: rbac.crmCategory,
      isCrmEligible: rbac.isCrmEligible,
    );
  }

  bool get _canScheduleVisits {
    final rbac = ref.read(permissionManagerProvider);
    return canEmployeeScheduleFieldVisit(
      role: rbac.role,
      crmCategory: rbac.crmCategory,
      isCrmEligible: rbac.isCrmEligible,
      canScheduleVisits:
          rbac.canScheduleVisits || PermissionManager.instance.canScheduleVisits,
    );
  }

  bool _isVisitScheduleStage(LeadStageModel stage) {
    final key = stage.key.toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
    final name = stage.name.toUpperCase();
    return key == 'VISIT_SCHEDULED' ||
        key == 'VISIT' ||
        key == 'SCHEDULE_VISIT' ||
        (name.contains('VISIT') && name.contains('SCHEDUL'));
  }

  bool _isVisitDoneStage(LeadStageModel stage) {
    final key = stage.key.toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
    final name = stage.name.toUpperCase();
    return key == 'VISIT_DONE' || name == 'VISIT DONE' || name.contains('VISIT DONE');
  }

  void _onPipelineStageSelected(LeadStageModel stage, {BuildContext? sheetContext}) {
    final lead = _lead;
    if (lead == null) return;
    final isCurrent = lead.stageId == stage.id ||
        lead.status.toUpperCase() == stage.key.toUpperCase();
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

  void _showScheduleVisitSheet() {
    final lead = _lead;
    if (lead == null) return;
    if (!_canScheduleVisits) {
      AppToast.error(
        context,
        'Access denied: Missing required permission [VISITS:CREATE]',
      );
      return;
    }

    final customerLead = customer_model.LeadModel.fromJson(lead.toJson());
    showScheduleVisitBottomSheet(
      context,
      lead: customerLead,
      ref: ref,
      onVisitScheduled: (updatedCustomerLead) async {
        await _fetchLead();
        await ref.read(leadsProvider.notifier).refreshLeads();
      },
    );
  }

  Future<void> _handleStageChange(LeadStageModel targetStage) async {
    if (_isUpdatingStage || !targetStage.isActive) return;
    final lead = _lead;
    if (lead == null) return;

    if (_isVisitor) {
      final currentStatus = (lead.status).toUpperCase();
      final currentStageKey = (lead.stage?.key ?? '').toUpperCase();
      final currentStageName = (lead.stage?.name ?? '').toUpperCase();
      final isCurrentScheduled = currentStatus == 'VISIT_SCHEDULED' ||
          currentStatus == 'VISIT' ||
          currentStageKey == 'VISIT_SCHEDULED' ||
          currentStageKey == 'VISIT' ||
          currentStageName == 'VISIT SCHEDULED' ||
          currentStageName.contains('VISIT SCHEDULED');

      if (!isCurrentScheduled) {
        AppToast.error(
          context,
          'Visitors can only update leads that are currently in Visit Scheduled stage',
        );
        return;
      }

      final targetKey = targetStage.key.toUpperCase();
      final targetName = targetStage.name.toUpperCase();
      final isTargetVisitDone = targetKey == 'VISIT_DONE' ||
          targetName == 'VISIT DONE' ||
          targetName == 'VISIT DONE';

      if (!isTargetVisitDone) {
        AppToast.error(
          context,
          'Visitor employee can only update leads to Visit Done stage.',
        );
        return;
      }
    }

    final currentResolved = ref
        .read(leadStagesProvider.notifier)
        .resolveLeadStage(lead.stageId, lead.status);

    if (currentResolved != null && currentResolved.id == targetStage.id) {
      AppToast.info(context, 'Lead is already in "${targetStage.name}" stage');
      return;
    }

    if (_isVisitDoneStage(targetStage) && !_isVisitor) {
      AppToast.error(context, 'Only a visitor employee can mark this lead as Visit Done.');
      return;
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
          );

      if (updateResult != null && mounted) {
        final updated = updateResult.lead;
        final confirmedStage = updated.stageId == targetStage.id ||
            (updated.stage?.key ?? '').toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_') ==
                targetStage.key.toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
        if (!confirmedStage) {
          throw FormatException('Saved stage is ${updated.stage?.name ?? updated.status}, not ${targetStage.name}');
        }
        setState(() => _lead = updated);
        AppToast.success(context, 'Lead stage updated successfully!');
        showStageAutomationFeedback(context, updateResult);
        try {
          await ref.read(leadsProvider.notifier).refreshLeads();
          final fresh = await ref.read(leadsProvider.notifier).getLeadDetails(lead.id);
          if (fresh != null && mounted) setState(() => _lead = fresh);
        } catch (_) {}
        invalidateCustomersDirectory(ref);
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = _message(e);
        AppToast.error(context, 'Failed to update stage: $cleanMsg');
      }
    } finally {
      _isUpdatingStage = false;
      if (mounted) setState(() {});
    }
  }

  void _showStagePickerSheet(
    List<LeadStageModel> stages,
    LeadStageModel? currentStage,
  ) {
    if (_isUpdatingStage) return;

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
                            'Select Pipeline Stage',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Move this lead to any configured CRM stage',
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
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: stages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final stage = stages[idx];
                    if (!_isVisitor && _isVisitDoneStage(stage)) {
                      return const SizedBox.shrink();
                    }
                    final isCurrent = currentStage != null
                        ? stage.id == currentStage.id ||
                              stage.key.toUpperCase() ==
                                  currentStage.key.toUpperCase()
                        : (_lead?.stageId == stage.id ||
                              _lead?.status.toUpperCase() ==
                                  stage.key.toUpperCase());

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (_isVisitor &&
                              stage.key.toUpperCase() != 'VISIT_DONE' &&
                              !stage.name.toUpperCase().contains('VISIT DONE')) {
                            AppToast.error(
                              context,
                              'Visitors can only advance leads to Visit Done stage.',
                            );
                            return;
                          }
                          _onPipelineStageSelected(
                            stage,
                            sheetContext: modalCtx,
                          );
                        },
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
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
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
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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

  Widget _metaLine(IconData icon, String text, double fontSize) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: fontSize + 2, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(fontSize: fontSize, height: 1.3, color: const Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }

  Widget _buildSheetHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lead = _lead;
    final stagesAsync = ref.watch(leadStagesProvider);
    final stages = ref.watch(activeLeadStagesProvider);

    final currentStage = lead != null
        ? lead.stage ??
              ref
                  .read(leadStagesProvider.notifier)
                  .resolveLeadStage(lead.stageId, lead.status)
        : null;

    final nextStage = lead != null
        ? ref
              .read(leadStagesProvider.notifier)
              .nextStage(lead.stageId, lead.status)
        : null;

    final stageNotifier = ref.read(leadStagesProvider.notifier);
    final pipelineStages = stageNotifier.activePipelineStages;
    final stagePosition = lead != null ? stageNotifier.stageIndexInPipeline(lead.stageId) : -1;
    final stageProgressLabel = stagePosition >= 0 && pipelineStages.isNotEmpty
        ? 'Stage ${stagePosition + 1} of ${pipelineStages.length}'
        : null;
    final stagesInitialLoading = stagesAsync.isLoading && stagesAsync.asData == null;

    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;
    final wide = width >= 720;
    final pagePad = compact ? 12.0 : wide ? 28.0 : 16.0;
    final avatar = compact ? 56.0 : wide ? 72.0 : 64.0;
    double fs(double size) => size * (compact ? 0.92 : wide ? 1.06 : 1);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2),
      ),
      child: Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppAppBar(
        title: 'Lead Details',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: 'Edit Lead',
            icon: const Icon(Remix.pencil_line),
            onPressed: lead == null ? null : () => _editLead(lead),
          ),
        ],
      ),
      body: _isLoading && lead == null
          ? const Center(child: CircularProgressIndicator())
          : lead == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Remix.error_warning_line,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(_loadError ?? 'Lead not found'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _fetchLead,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchLead,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(pagePad, pagePad, pagePad, pagePad + MediaQuery.paddingOf(context).bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stagesInitialLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (stagesAsync.hasError && stages.isEmpty)
                      Material(
                        color: Colors.white,
                        child: ListTile(
                          title: const Text('Unable to load pipeline stages'),
                          trailing: TextButton(
                            onPressed: () =>
                                ref.read(leadStagesProvider.notifier).refresh(),
                            child: const Text('Retry'),
                          ),
                        ),
                      ),
                    // 1. LEAD HEADER CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LeadBusinessImage(lead: lead, size: avatar, radius: 16, initials: lead.initials, initialsFontSize: fs(22)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lead.displayName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(fontSize: fs(18), fontWeight: FontWeight.w800, color: const Color(0xFF111827)),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: (currentStage?.stageBgColor ?? lead.stageBgColor),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(width: 7, height: 7, decoration: BoxDecoration(color: currentStage?.stageColor ?? lead.stageColor, shape: BoxShape.circle)),
                                              const SizedBox(width: 5),
                                              ConstrainedBox(
                                                constraints: BoxConstraints(maxWidth: width * (wide ? 0.28 : 0.42)),
                                                child: Text(currentStage?.name ?? lead.stageName, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: fs(12), fontWeight: FontWeight.w700, color: currentStage?.stageColor ?? lead.stageColor)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (lead.source.trim().isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Remix.map_pin_line, size: 12, color: Color(0xFF64748B)),
                                                const SizedBox(width: 4),
                                                ConstrainedBox(
                                                  constraints: BoxConstraints(maxWidth: width * (wide ? 0.28 : 0.42)),
                                                  child: Text(_readable(lead.source), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: fs(12), fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                            child: Column(
                              children: [
                                _metaLine(Remix.user_3_line, 'Assigned: ${(lead.assignedToName ?? '').trim().isEmpty ? 'Unassigned' : lead.assignedToName!.trim()}', fs(12)),
                                const SizedBox(height: 6),
                                _metaLine(Remix.calendar_line, 'Created: ${(lead.createdAt ?? '').isEmpty ? '—' : _shortDate(lead.createdAt!)}', fs(12)),
                              ],
                            ),
                          ),
                          if ([lead.city, lead.state].any((part) => (part ?? '').trim().isNotEmpty)) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Remix.map_pin_2_line, size: fs(14), color: const Color(0xFF94A3B8)),
                                const SizedBox(width: 6),
                                Expanded(child: Text([lead.city, lead.state].whereType<String>().map((part) => part.trim()).where((part) => part.isNotEmpty).join(', '), maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: fs(13), color: const Color(0xFF475569)))),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    _BpoCommunicationsCard(
                      leadId: lead.id,
                      onMail: () => _openMail(lead),
                      onWhatsApp: () => _openWhatsApp(lead),
                      onBoth: () async {
                        await _openMail(lead);
                        await _openWhatsApp(lead);
                      },
                      onSendDetails: () => _openSendDetails(lead),
                    ),

                    const SizedBox(height: 12),
                    SendDetailsDeliveryHistoryCard(
                      leadId: lead.id,
                      onSendDetails: () => _openSendDetails(lead),
                    ),

                    const SizedBox(height: 12),

                    // 2. PIPELINE PROGRESSION / STAGE CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(color: const Color(0xFFE8F7ED), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Remix.git_commit_line, size: 16, color: Color(0xFF16A34A)),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Lead Stage',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: fs(16),
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (stageProgressLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                stageProgressLabel,
                                style: GoogleFonts.outfit(fontSize: fs(11), fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                              ),
                            ),

                          // Stage Selector Button
                          InkWell(
                            onTap: _isUpdatingStage || (stages.isEmpty && currentStage == null)
                                ? null
                                : () => _showStagePickerSheet(
                                    [
                                      if (currentStage != null && !stages.any((stage) => stage.id == currentStage.id)) currentStage,
                                      ...stages,
                                    ],
                                    currentStage,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color:
                                    (currentStage?.stageBgColor ??
                                    lead.stageBgColor),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      (currentStage?.stageBorderColor ??
                                      lead.stageBorderColor),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: currentStage?.stageColor ?? lead.stageColor, shape: BoxShape.circle)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      currentStage?.name ?? lead.stageName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(fontSize: fs(15), fontWeight: FontWeight.w800, color: const Color(0xFF111827)),
                                    ),
                                  ),
                                  if (_isUpdatingStage)
                                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFFE8F4FF), borderRadius: BorderRadius.circular(16)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Change', style: GoogleFonts.outfit(fontSize: fs(12), fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                                          const Icon(Remix.arrow_down_s_line, size: 16, color: Color(0xFF2563EB)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          if (nextStage != null) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _isUpdatingStage
                                  ? null
                                  : () {
                                      if (_isVisitScheduleStage(nextStage) &&
                                          !_isVisitor &&
                                          _canScheduleVisits) {
                                        _showScheduleVisitSheet();
                                      } else {
                                        _handleStageChange(nextStage);
                                      }
                                    },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                                child: Row(
                                  children: [
                                    const Icon(Remix.arrow_right_line, size: 16, color: Color(0xFF111827)),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text('Next: ${nextStage.name}', maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: fs(14), fontWeight: FontWeight.w700, color: const Color(0xFF111827)))),
                                    Text('Change', style: GoogleFonts.outfit(fontSize: fs(12), fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),



                    const SizedBox(height: 16),
                    ContactInformationCard(
                      businessName: lead.companyName,
                      contactPerson: lead.contactPerson,
                      phone: lead.phone,
                      email: lead.email,
                      website: lead.website,
                      address: lead.address,
                      city: lead.city,
                      state: lead.state,
                      pincode: lead.pincode,
                      country: lead.country,
                      category: lead.category,
                      googlePlaceId: lead.googlePlaceId,
                    ),
                    const SizedBox(height: 16),
                    SocialMediaProfilesCard(
                      socialMedia: lead.socialMedia,
                      website: lead.website,
                      title: 'Social Media & Online Presence',
                      showEmpty: true,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: AppColors.primary,
                        indicatorWeight: 3.0,
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: const Color(0xFF64748B),
                        labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                        unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 12),
                        tabs: const [
                          Tab(icon: Icon(Remix.file_text_line, size: 18), text: 'Notes', iconMargin: EdgeInsets.only(bottom: 4)),
                          Tab(icon: Icon(Remix.calendar_check_line, size: 18), text: 'Visits', iconMargin: EdgeInsets.only(bottom: 4)),
                          Tab(icon: Icon(Remix.time_line, size: 18), text: 'Timeline', iconMargin: EdgeInsets.only(bottom: 4)),
                          Tab(icon: Icon(Remix.history_line, size: 18), text: 'History', iconMargin: EdgeInsets.only(bottom: 4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        switch (_tabController.index) {
                          case 0:
                            return _buildNotesTab(lead);
                          case 1:
                            return _buildVisitsTab(lead);
                          case 2:
                            return _buildTimelineTab(lead);
                          case 3:
                            return _buildHistoryTab(lead);
                          default:
                            return const SizedBox.shrink();
                        }
                      },
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    ),
    );
  }

  static String _formatDateTime(String rawDate) {
    if (rawDate.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      final now = DateTime.now();
      final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      final timeStr = '$hour:$minute $amPm';
      if (isToday) return 'Today at $timeStr';
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $timeStr';
    } catch (_) {
      return rawDate;
    }
  }

  static String _shortDate(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return rawDate;
    }
  }


  void _showAddNoteBottomSheet(BuildContext context) {
    final textController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: bottomInset > 0 ? bottomInset + 16 : 28,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Remix.file_text_line,
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
                            'Add Note',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Record an internal note or meeting summary',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Remix.close_line,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  maxLines: 5,
                  minLines: 3,
                  autofocus: true,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Enter note details, discussion summary, or next steps...',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.textPlaceholder,
                    ),
                    filled: true,
                    fillColor: AppColors.scaffoldBg,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.borderLight,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.borderLight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isSaving
                          ? null
                          : () => Navigator.pop(sheetContext),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final text = textController.text.trim();
                              if (text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter note content'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }

                              setSheetState(() => isSaving = true);
                              try {
                                final success = await ref
                                    .read(leadsProvider.notifier)
                                    .addNote(widget.leadId, text);

                                if (context.mounted) {
                                  Navigator.pop(sheetContext);
                                  ref.invalidate(sharedLeadNotesProvider(widget.leadId));
                                  _fetchLead();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Note added successfully'
                                            : 'Failed to add note',
                                      ),
                                      backgroundColor: success
                                          ? AppColors.success
                                          : AppColors.error,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  setSheetState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to add note: $e'),
                                      backgroundColor: AppColors.error,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Save Note',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotesTab(LeadModel lead) {
    final notesAsync = ref.watch(sharedLeadNotesProvider(lead.id));

    return notesAsync.when(
      data: (notes) {
        final hasApiNotes = notes.isNotEmpty;
        final hasLegacyNote = lead.notes != null && lead.notes!.trim().isNotEmpty;

        if (!hasApiNotes && !hasLegacyNote) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Remix.file_text_line,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Notes Yet',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add a note to keep track of important information about this lead.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Remix.add_line, size: 16),
                  label: Text(
                    'Add Note',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => _showAddNoteBottomSheet(context),
                ),
              ],
            ),
          );
        }

        final allNotes = <Map<String, dynamic>>[...notes];
        if (allNotes.isEmpty && hasLegacyNote) {
          allNotes.add({
            'id': 'legacy',
            'content': lead.notes!,
            'authorName': 'Team Member',
            'createdAt': lead.createdAt ?? '',
          });
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Lead Notes (${allNotes.length})',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => _showAddNoteBottomSheet(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.add_line,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Add Note',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: allNotes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final note = allNotes[index];
                final content = note['content']?.toString() ?? '';
                final author = (note['authorName']?.toString() ??
                        (note['user'] is Map
                            ? '${note['user']['firstName'] ?? ''} ${note['user']['lastName'] ?? ''}'
                            : null) ??
                        'Team Member')
                    .trim();
                final dateStr =
                    _formatDateTime(note['createdAt']?.toString() ?? '');

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content,
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          height: 1.45,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Remix.user_line,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$author • $dateStr',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Remix.error_warning_line,
              size: 36,
              color: AppColors.error,
            ),
            const SizedBox(height: 10),
            Text(
              'Unable to load notes.',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => ref.invalidate(sharedLeadNotesProvider(lead.id)),
              child: Text(
                'Retry',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitsTab(LeadModel lead) {
    final visits = lead.visits;
    if (visits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Remix.calendar_check_line,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Visits Scheduled',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Visits scheduled for this lead will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (_canScheduleVisits && !_isVisitor) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Remix.add_line, size: 16),
                label: Text(
                  'Schedule Visit',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _showScheduleVisitSheet,
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Field Visits (${visits.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_canScheduleVisits && !_isVisitor)
                InkWell(
                  onTap: _showScheduleVisitSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Remix.add_line,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Schedule Visit',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: visits.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final v = visits[index];
            final statusStr = v.status.toUpperCase();
            final isDone =
                statusStr == 'COMPLETED' || statusStr == 'VISIT_DONE';
            final statusColor = isDone
                ? const Color(0xFF10B981)
                : (statusStr == 'IN_PROGRESS'
                    ? const Color(0xFFF59E0B)
                    : AppColors.primary);
            final statusBg = statusColor.withValues(alpha: 0.1);
            final dateLabel =
                v.date.isNotEmpty ? _formatDateTime(v.date) : 'Scheduled';
            final timeLabel = v.time ?? '';

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isDone
                              ? 'Visit Done'
                              : (statusStr == 'IN_PROGRESS'
                                  ? 'In Progress'
                                  : 'Scheduled'),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (v.assignedEmployee != null &&
                          v.assignedEmployee!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Remix.user_star_line,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              v.assignedEmployee!,
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    v.purpose,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Remix.map_pin_2_line,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          v.location,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                        '$dateLabel${timeLabel.isNotEmpty ? ' • $timeLabel' : ''}',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (v.notes != null && v.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        v.notes!.trim(),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTimelineTab(LeadModel lead) {
    final createdStr = _formatDateTime(lead.createdAt ?? '');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Remix.checkbox_circle_line,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lead Created (${lead.source.replaceAll('_', ' ')})',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      createdStr,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (lead.stage != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Remix.git_commit_line,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Stage: ${lead.stageName}',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Active in pipeline',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryTab(LeadModel lead) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stage History',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${lead.stageName} (Current)',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Created from: ${lead.createdFrom.replaceAll('_', ' ')}',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (lead.assignedToName != null &&
              lead.assignedToName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Assigned to: ${lead.assignedToName}',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

}

class _BpoCommunicationsCard extends ConsumerStatefulWidget {
  final String leadId;
  final VoidCallback onMail;
  final VoidCallback onWhatsApp;
  final VoidCallback onBoth;
  final VoidCallback? onSendDetails;

  const _BpoCommunicationsCard({
    required this.leadId,
    required this.onMail,
    required this.onWhatsApp,
    required this.onBoth,
    this.onSendDetails,
  });

  @override
  ConsumerState<_BpoCommunicationsCard> createState() => _BpoCommunicationsCardState();
}

class _BpoCommunicationsCardState extends ConsumerState<_BpoCommunicationsCard> {
  int _emails = 0;
  int _whatsapp = 0;
  String _last = 'None yet';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _ago(String? raw) {
    final date = DateTime.tryParse(raw ?? '');
    if (date == null) return 'None yet';
    final diff = DateTime.now().difference(date.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  Future<void> _load() async {
    try {
      final response = await ref.read(apiClientProvider).get('/leads/${widget.leadId}/communications');
      final raw = response.data;
      final payload = raw is Map && raw['data'] is Map ? raw['data'] as Map : raw;
      final summary = payload is Map ? payload['summary'] : null;
      if (!mounted) return;
      if (summary is Map) {
        setState(() {
          _emails = (summary['totalEmails'] as num?)?.toInt() ?? 0;
          _whatsapp = (summary['totalWhatsApp'] as num?)?.toInt() ?? 0;
          _last = _ago(summary['lastContactAt']?.toString());
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _count(String label, String value, Color color, double labelSize, double valueSize) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: labelSize, color: const Color(0xFF64748B))),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, maxLines: 1, style: GoogleFonts.outfit(fontSize: valueSize, fontWeight: FontWeight.w800, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, Color color, Color background, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;
    final wide = width >= 720;
    double fs(double size) => size * (compact ? 0.92 : wide ? 1.06 : 1);

    return Container(
      width: double.infinity,
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
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFE8F7ED), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Remix.chat_1_line, size: 16, color: Color(0xFF16A34A)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('BPO Communications', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: fs(16), fontWeight: FontWeight.w800, color: const Color(0xFF111827)))),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: _loading
                ? const SizedBox(height: 36, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
                : Row(
                    children: [
                      _count('Emails', '$_emails', const Color(0xFF4F46E5), fs(12), fs(18)),
                      Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                      _count('WhatsApp', '$_whatsapp', const Color(0xFF16A34A), fs(12), fs(18)),
                      Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                      _count('Last', _last, const Color(0xFF111827), fs(12), fs(18)),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _action(Remix.mail_line, const Color(0xFF64748B), const Color(0xFFF1F5F9), widget.onMail),
              const SizedBox(width: 8),
              _action(Remix.whatsapp_line, const Color(0xFF16A34A), const Color(0xFFE8F7ED), widget.onWhatsApp),
              const SizedBox(width: 8),
              _action(Remix.flashlight_line, const Color(0xFFD97706), const Color(0xFFFEF3C7), widget.onBoth),
            ],
          ),
          if (widget.onSendDetails != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: widget.onSendDetails,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Remix.send_plane_fill, color: Colors.white, size: 15),
                    const SizedBox(width: 8),
                    Text(
                      'Send Details Package',
                      style: GoogleFonts.outfit(
                        fontSize: fs(13),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
