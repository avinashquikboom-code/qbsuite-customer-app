import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/constants/app_bar_titles.dart';
import 'package:quickboom_crm_customer/core/models/permission_model.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/leads_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/new_lead_bottom_sheet.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/lead_limit_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_stage_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/lead_stages_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_profile_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/widgets/stage_badge.dart';
import 'lead_details_view.dart';

class LeadsView extends ConsumerStatefulWidget {
  const LeadsView({super.key});

  @override
  ConsumerState<LeadsView> createState() => _LeadsViewState();
}

class _LeadsViewState extends ConsumerState<LeadsView>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  int? _cachedTotalCount;
  final Map<String, int> _cachedStageCounts = {};

  bool _isSelectionMode = false;
  final Set<String> _selectedLeadIds = {};
  bool _isDeleting = false;

  Future<void> _handleBulkDelete(BuildContext context) async {
    if (_isDeleting || _selectedLeadIds.isEmpty) return;

    final count = _selectedLeadIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Leads?'),
        content: Text(
          'Are you sure you want to delete $count selected lead${count == 1 ? '' : 's'}?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final idsToDelete = _selectedLeadIds
          .where((id) => id.isNotEmpty && id != 'bulk')
          .toList();
      if (idsToDelete.isEmpty) return;

      final result = await ref
          .read(leadsProvider.notifier)
          .bulkDeleteLeads(idsToDelete);

      if (!mounted) return;

      final deleted = result['deleted'] ?? idsToDelete.length;
      final failed = result['failed'] ?? 0;

      if (failed > 0) {
        AppToast.error(
          this.context,
          '$deleted lead${deleted == 1 ? '' : 's'} deleted, $failed could not be deleted.',
        );
      } else {
        AppToast.success(
          this.context,
          '$deleted lead${deleted == 1 ? '' : 's'} deleted successfully.',
        );
      }

      setState(() {
        _isSelectionMode = false;
        _selectedLeadIds.clear();
      });

      final currentFilter = ref.read(leadsFilterProvider);
      await Future.wait([
        ref
            .read(leadsProvider.notifier)
            .refreshLeads(
              stageId: currentFilter.stageId,
              status: currentFilter.stageKey,
              search: _searchController.text.trim(),
            ),
        ref.read(leadStagesProvider.notifier).refresh(),
        ref.read(leadLimitProvider.notifier).fetchLimits(),
      ]);
    } catch (e) {
      if (mounted) {
        AppToast.error(
          this.context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final currentFilter = ref.read(leadsFilterProvider);
      await ref
          .read(leadsProvider.notifier)
          .refreshLeads(search: currentFilter.search);
      ref.read(leadStagesProvider.notifier).refresh();
      ref.read(leadLimitProvider.notifier).fetchLimits();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref
          .read(leadsProvider.notifier)
          .refreshLeads(search: _searchController.text.trim());
      ref.read(leadStagesProvider.notifier).refresh();
      ref.read(leadLimitProvider.notifier).fetchLimits();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final permsState = ref.watch(permissionManagerProvider);
    final leadsState = ref.watch(leadsProvider);
    final stagesAsync = ref.watch(leadStagesProvider);
    final limitState = ref.watch(leadLimitProvider);
    final filterState = ref.watch(leadsFilterProvider);
    final selectedStageId = filterState.stageId;
    final selectedStageKey = filterState.stageKey;

    // Resolve Visitor employee role/designation from existing providers
    final profile = ref.watch(employeeProfileProvider).asData?.value;
    final desigName = (profile?.designation ?? '').trim().toUpperCase();
    final roleName = (permsState.role ?? '').trim().toUpperCase();
    final isVisitor =
        desigName.contains('VISITOR') ||
        desigName.contains('FIELD VISIT') ||
        desigName.contains('FIELD_VISIT') ||
        desigName == 'VISIT' ||
        roleName.contains('VISITOR') ||
        roleName.contains('FIELD VISIT') ||
        roleName.contains('FIELD_VISIT') ||
        roleName == 'VISIT';
    final canCreateLead = !isVisitor && permsState.canCreate(AppModule.leads);
    final canDeleteLead = permsState.canDelete(AppModule.leads);
    final isDailyExhausted = limitState.value?.daily.isExhausted ?? false;
    final isMonthlyExhausted = limitState.value?.monthly.isExhausted ?? false;

    // Listen to permission resolution to trigger fetch when permissions finish loading,
    // or when employee/tenant changes to refresh and reset stale filters.
    ref.listen<PermissionState>(permissionManagerProvider, (prev, next) {
      final employeeChanged =
          prev != null &&
          (prev.employeeId != next.employeeId ||
              prev.tenantId != next.tenantId);
      if (employeeChanged) {
        ref.read(leadsFilterProvider.notifier).clearFilter();
        setState(() {
          _searchController.clear();
          _cachedTotalCount = null;
          _cachedStageCounts.clear();
        });
        ref.read(leadsProvider.notifier).refreshLeads();
        ref.read(leadStagesProvider.notifier).refresh();
        ref.invalidate(leadLimitProvider);
        ref.read(leadLimitProvider.notifier).fetchLimits();
        return;
      }
      if ((prev == null || !prev.isReady) && next.isReady) {
        if (next.canView(AppModule.leads)) {
          final currentFilter = ref.read(leadsFilterProvider);
          ref
              .read(leadsProvider.notifier)
              .refreshLeads(
                stageId: currentFilter.stageId,
                status: currentFilter.stageKey,
                search: _searchController.text.trim(),
              );
          ref.read(leadStagesProvider.notifier).refresh();
        }
      }
    });

    // Validate saved filter against available stages whenever stages update
    ref.listen<AsyncValue<List<LeadStageModel>>>(leadStagesProvider, (
      prev,
      next,
    ) {
      final active = (next.asData?.value ?? [])
          .where((s) => s.isActive)
          .toList();
      if (active.isNotEmpty) {
        final changed = ref
            .read(leadsFilterProvider.notifier)
            .validateAgainstStages(active);
        if (changed) {
          ref
              .read(leadsProvider.notifier)
              .refreshLeads(search: _searchController.text.trim());
        }
      }
    });

    // 1. Initial Permission Loading State — show structured pipeline skeleton
    if (!permsState.isReady && permsState.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppAppBar(
          title: AppBarTitles.leadsPipeline,
          showBackButton: false,
          showDrawerButton: false,
        ),
        body: Column(
          children: [
            _buildSearchAndFilterSkeleton(context, isVisitor: isVisitor),
            const Expanded(child: SkeletonList(count: 5)),
          ],
        ),
      );
    }

    // 2. Permission Denied State — show access denied when LEADS:VIEW is not permitted
    if (permsState.isReady && !permsState.canView(AppModule.leads)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppAppBar(
          title: AppBarTitles.leadsPipeline,
          showBackButton: false,
          showDrawerButton: false,
        ),
        body: _buildPermissionDeniedUI(),
      );
    }

    final stages = stagesAsync.asData?.value ?? [];
    final activeStages = stages.where((s) => s.isActive).toList();
    final isStagesLoading = stagesAsync.isLoading && !stagesAsync.hasValue;
    final isInitialLeadsLoading = leadsState.isLoading && !leadsState.hasValue;

    // Derive or retrieve lead counts from authoritative server source
    final loadedLeads = leadsState.asData?.value;
    final isUnfiltered =
        selectedStageId == null &&
        selectedStageKey == null &&
        _searchController.text.trim().isEmpty;

    final serverTotal = ref.read(leadServiceProvider).lastTotalCount;

    bool isLeadInStage(LeadModel l, LeadStageModel stage) {
      final resolved = LeadStageModel.resolve(
        stages: stages,
        stageId: l.stageId,
        status: l.status,
        stageName: l.stageNameConfig,
      );
      return resolved != null && resolved.id == stage.id;
    }

    LeadStageModel? selectedStage;
    if (selectedStageId != null || selectedStageKey != null) {
      if (selectedStageId != null) {
        for (final s in activeStages) {
          if (selectedStageId == s.id.toString()) {
            selectedStage = s;
            break;
          }
        }
      }
      if (selectedStage == null && selectedStageKey != null) {
        for (final s in activeStages) {
          if (selectedStageKey.toUpperCase() == s.key.toUpperCase()) {
            selectedStage = s;
            break;
          }
        }
      }
    }

    List<LeadModel> leadsForStage(List<LeadModel> raw, LeadStageModel? stage) {
      if (isVisitor) {
        return raw.where(_isLeadInVisitScheduledStage).toList();
      }
      if (stage != null) {
        return raw.where((l) => isLeadInStage(l, stage)).toList();
      }
      return List<LeadModel>.from(raw);
    }

    int countInLoaded(LeadStageModel stage) {
      if (loadedLeads == null) return 0;
      return leadsForStage(loadedLeads, stage).length;
    }

    if (loadedLeads != null && isUnfiltered) {
      final derivedSum = activeStages.fold<int>(
        0,
        (sum, s) => sum + countInLoaded(s),
      );
      final accurateTotal =
          serverTotal ?? (derivedSum > 0 ? derivedSum : loadedLeads.length);
      _cachedTotalCount = accurateTotal;
      for (final stage in activeStages) {
        final inLoaded = countInLoaded(stage);
        _cachedStageCounts[stage.id.toString()] = inLoaded;
        _cachedStageCounts[stage.key.toUpperCase()] = inLoaded;
      }
    }

    int getStageCount(LeadStageModel stage) {
      if (loadedLeads == null) return 0;

      // Selected stage chip must equal the list currently shown for that stage.
      if (selectedStage != null && stage.id == selectedStage.id) {
        final count = countInLoaded(selectedStage);
        _cachedStageCounts[stage.id.toString()] = count;
        _cachedStageCounts[stage.key.toUpperCase()] = count;
        return count;
      }

      if (isUnfiltered) {
        final count = countInLoaded(stage);
        _cachedStageCounts[stage.id.toString()] = count;
        _cachedStageCounts[stage.key.toUpperCase()] = count;
        return count;
      }

      return _cachedStageCounts[stage.id.toString()] ??
          _cachedStageCounts[stage.key.toUpperCase()] ??
          0;
    }

    final stageSum = activeStages.fold<int>(
      0,
      (sum, s) => sum + getStageCount(s),
    );
    final effectiveTotalCount =
        _cachedTotalCount ??
        (isUnfiltered && loadedLeads != null
            ? (serverTotal ?? loadedLeads.length)
            : stageSum);

    int countForKey(String key) {
      final match = activeStages.where(
        (s) => s.key.toUpperCase() == key.toUpperCase(),
      );
      if (match.isEmpty) return 0;
      return getStageCount(match.first);
    }

    debugPrint('''
[LEADS_PIPELINE_COUNTS]
all: $effectiveTotalCount
new: ${countForKey('NEW')}
contacted: ${countForKey('CONTACTED')}
followUp: ${countForKey('FOLLOW_UP')}
finalCall: ${countForKey('FINAL_CALL')}
won: ${countForKey('WON')}

[LEADS_PIPELINE_FILTER]
selectedFilter: ${selectedStageKey ?? (selectedStageId ?? 'ALL')}
beforeFilterCount: $effectiveTotalCount
afterFilterCount: ${loadedLeads?.length ?? 0}
''');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: theme.colorScheme.surface,
              elevation: 0.5,
              leading: IconButton(
                key: const ValueKey('btn_exit_multi_select'),
                icon: const Icon(Remix.close_line),
                tooltip: 'Cancel',
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedLeadIds.clear();
                  });
                },
              ),
              title: Text(
                _selectedLeadIds.isEmpty
                    ? 'Select Leads'
                    : 'Selected: ${_selectedLeadIds.length}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                TextButton(
                  key: const ValueKey('btn_select_all_leads'),
                  onPressed: () {
                    final currentLeads = leadsState.asData?.value ?? [];
                    if (currentLeads.isEmpty) return;
                    setState(() {
                      if (_selectedLeadIds.length == currentLeads.length) {
                        _selectedLeadIds.clear();
                      } else {
                        _selectedLeadIds.clear();
                        _selectedLeadIds.addAll(
                          currentLeads
                              .map((l) => l.id)
                              .where((id) => id.isNotEmpty && id != 'bulk'),
                        );
                      }
                    });
                  },
                  child: Text(
                    _selectedLeadIds.length ==
                                (leadsState.asData?.value.length ?? 0) &&
                            (leadsState.asData?.value.isNotEmpty ?? false)
                        ? 'Clear'
                        : 'Select All',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (canDeleteLead)
                  IconButton(
                    key: const ValueKey('btn_bulk_delete_leads'),
                    tooltip: 'Delete Selected',
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.error,
                            ),
                          )
                        : Icon(
                            Remix.delete_bin_line,
                            color: _selectedLeadIds.isNotEmpty
                                ? AppColors.error
                                : const Color(0xFFCBD5E1),
                          ),
                    onPressed: (_isDeleting || _selectedLeadIds.isEmpty)
                        ? null
                        : () => _handleBulkDelete(context),
                  ),
              ],
            )
          : AppAppBar(
              title: AppBarTitles.leadsPipeline,
              showBackButton: false,
              showDrawerButton: false,
              actions: [
                if (canDeleteLead)
                  IconButton(
                    key: const ValueKey('btn_enter_multi_select'),
                    icon: const Icon(Remix.delete_bin_line),
                    tooltip: 'Delete Leads',
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = true;
                        _selectedLeadIds.clear();
                      });
                    },
                  ),
                if (!isVisitor && canCreateLead)
                  IconButton(
                    icon: Icon(
                      Remix.add_circle_line,
                      color: (isDailyExhausted || isMonthlyExhausted)
                          ? AppColors.textSecondary
                          : null,
                    ),
                    onPressed: () {
                      if (isDailyExhausted) {
                        AppToast.error(
                          context,
                          'Daily lead generation limit reached.',
                        );
                        return;
                      }
                      if (isMonthlyExhausted) {
                        AppToast.error(
                          context,
                          'Monthly lead generation limit reached.',
                        );
                        return;
                      }
                      showNewLeadBottomSheet(context);
                    },
                  ),
              ],
            ),
      body: Column(
        children: [
          // Search & Filter Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search leads by name, phone, city...',
                    prefixIcon: const Icon(Remix.search_2_line),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Remix.close_circle_line, size: 18),
                            onPressed: () {
                              _debounceTimer?.cancel();
                              _searchController.clear();
                              ref
                                  .read(leadsFilterProvider.notifier)
                                  .setSearch('');
                              setState(() {
                                _isSelectionMode = false;
                                _selectedLeadIds.clear();
                              });
                              ref
                                  .read(leadsProvider.notifier)
                                  .refreshLeads(
                                    stageId: selectedStageId,
                                    status: selectedStageKey,
                                  );
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedLeadIds.clear();
                    });
                    ref.read(leadsFilterProvider.notifier).setSearch(val);
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(
                      const Duration(milliseconds: 500),
                      () {
                        if (!mounted) return;
                        ref
                            .read(leadsProvider.notifier)
                            .refreshLeads(
                              search: val.trim(),
                              stageId: selectedStageId,
                              status: selectedStageKey,
                            );
                      },
                    );
                  },
                  onSubmitted: (value) {
                    _debounceTimer?.cancel();
                    ref.read(leadsFilterProvider.notifier).setSearch(value);
                    setState(() {
                      _isSelectionMode = false;
                      _selectedLeadIds.clear();
                    });
                    ref
                        .read(leadsProvider.notifier)
                        .refreshLeads(
                          search: value.trim(),
                          stageId: selectedStageId,
                          status: selectedStageKey,
                        );
                  },
                ),

                if (!isVisitor) ...[
                  const SizedBox(height: 12),
                  if (isStagesLoading ||
                      (isInitialLeadsLoading && activeStages.isEmpty))
                    _buildFilterChipsSkeleton()
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildAllChip(effectiveTotalCount, filterState.isAll),
                          ...activeStages.map(
                            (stage) => _buildStageFilterChip(
                              stage,
                              getStageCount(stage),
                              isSelected:
                                  selectedStage != null &&
                                  selectedStage.id == stage.id,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),

          // Leads List with explicit loading -> error -> empty -> data state handling
          Expanded(
            child: ColoredBox(
              color: AppColors.background,
              child: leadsState.when(
                loading: () => const SkeletonList(count: 5),
                error: (error, stack) {
                  final errString = error.toString().toLowerCase();
                  final isConnectionError =
                      errString.contains('failed host lookup') ||
                      errString.contains('socketexception') ||
                      errString.contains('connection error') ||
                      errString.contains('no address associated with hostname');

                  final isAuthError =
                      errString.contains('session expired') ||
                      errString.contains('unauthorized') ||
                      errString.contains('401');

                  final isPermissionError =
                      errString.contains('access denied') ||
                      errString.contains('permission') ||
                      errString.contains('forbidden') ||
                      errString.contains('403');

                  final title = isAuthError
                      ? 'Session Expired'
                      : (isPermissionError
                            ? 'Access Denied'
                            : (isConnectionError
                                  ? 'Unable to connect to the server.'
                                  : 'Unable to load leads'));

                  final subtitle = isAuthError
                      ? 'Your session has expired. Please log in again.'
                      : (isPermissionError
                            ? 'You do not have permission to view leads.'
                            : (isConnectionError
                                  ? 'Please check your internet connection and try again.'
                                  : 'Something went wrong while loading your leads. Please try again.'));

                  final iconData = isAuthError
                      ? Remix.login_circle_line
                      : (isPermissionError
                            ? Remix.lock_line
                            : (isConnectionError
                                  ? Remix.wifi_off_line
                                  : Remix.error_warning_line));

                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              iconData,
                              size: 48,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              final currentFilter = ref.read(
                                leadsFilterProvider,
                              );
                              ref
                                  .read(leadsProvider.notifier)
                                  .refreshLeads(
                                    stageId: currentFilter.stageId,
                                    status: currentFilter.stageKey,
                                    search: _searchController.text.trim(),
                                  );
                              ref.read(leadStagesProvider.notifier).refresh();
                            },
                            icon: const Icon(Remix.refresh_line, size: 18),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                data: (rawLeads) {
                  final leads = leadsForStage(rawLeads, selectedStage);
                  leads.sort((a, b) => a.compareCreatedAtDesc(b));

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedLeadIds.clear();
                      });
                      final currentFilter = ref.read(leadsFilterProvider);
                      await Future.wait([
                        ref
                            .read(leadsProvider.notifier)
                            .refreshLeads(
                              stageId: currentFilter.stageId,
                              status: currentFilter.stageKey,
                              search: _searchController.text.trim(),
                            ),
                        ref.read(leadStagesProvider.notifier).refresh(),
                        ref.read(leadLimitProvider.notifier).fetchLimits(),
                      ]);
                    },
                    child: leads.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: _buildEmptyState(),
                                ),
                              );
                            },
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: leads.length,
                            itemBuilder: (context, index) {
                              final lead = leads[index];
                              final isSelected = _selectedLeadIds.contains(
                                lead.id,
                              );
                              return SizedBox(
                                width: double.infinity,
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 0.5,
                                  color: isSelected
                                      ? theme.colorScheme.primaryContainer
                                            .withValues(alpha: 0.2)
                                      : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outlineVariant
                                                .withValues(alpha: 0.5),
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onLongPress: canDeleteLead
                                        ? () {
                                            setState(() {
                                              _isSelectionMode = true;
                                              _selectedLeadIds.add(lead.id);
                                            });
                                          }
                                        : null,
                                    onTap: () async {
                                      if (_isSelectionMode) {
                                        setState(() {
                                          if (_selectedLeadIds.contains(
                                            lead.id,
                                          )) {
                                            _selectedLeadIds.remove(lead.id);
                                          } else {
                                            _selectedLeadIds.add(lead.id);
                                          }
                                        });
                                        return;
                                      }
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LeadDetailsView(
                                            leadId: lead.id,
                                            initialLead: lead,
                                          ),
                                        ),
                                      );
                                      if (mounted) {
                                        final currentFilter = ref.read(
                                          leadsFilterProvider,
                                        );
                                        ref
                                            .read(leadsProvider.notifier)
                                            .refreshLeads(
                                              stageId: currentFilter.stageId,
                                              status: currentFilter.stageKey,
                                              search: _searchController.text
                                                  .trim(),
                                            );
                                        ref
                                            .read(leadStagesProvider.notifier)
                                            .refresh();
                                        ref
                                            .read(leadLimitProvider.notifier)
                                            .fetchLimits();
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Top Row: Checkbox (in selection mode) + Lead/Company Name (Left) + Stage Badge (Right)
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              if (_isSelectionMode) ...[
                                                Icon(
                                                  isSelected
                                                      ? Icons.check_box
                                                      : Icons
                                                            .check_box_outline_blank,
                                                  color: isSelected
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : theme
                                                            .colorScheme
                                                            .outline,
                                                  size: 22,
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              _LeadThumb(lead: lead),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  lead.displayTitle,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color:
                                                        lead
                                                            .displayName
                                                            .isNotEmpty
                                                        ? null
                                                        : Theme.of(
                                                            context,
                                                          ).hintColor,
                                                    fontStyle:
                                                        lead
                                                            .displayName
                                                            .isNotEmpty
                                                        ? FontStyle.normal
                                                        : FontStyle.italic,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Builder(
                                                builder: (context) {
                                                  final stageModel = ref
                                                      .read(
                                                        leadStagesProvider
                                                            .notifier,
                                                      )
                                                      .resolveLeadStage(
                                                        lead.stageId,
                                                        lead.status,
                                                        lead.stageNameConfig,
                                                      );
                                                  return StageBadge(
                                                    stage:
                                                        stageModel?.name ??
                                                        lead.stageLabel,
                                                    color:
                                                        stageModel
                                                            ?.stageColor ??
                                                        lead.stageColor,
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),

                                          // Contact Row: Contact Name / Phone / City / Category (No fake Business Lead)
                                          Builder(
                                            builder: (context) {
                                              final contactPerson =
                                                  lead.validContactPerson;
                                              final phoneStr =
                                                  (lead.phone != null &&
                                                      lead.phone!
                                                          .trim()
                                                          .isNotEmpty)
                                                  ? lead.phone!.trim()
                                                  : null;
                                              final cityStr =
                                                  (lead.city != null &&
                                                      lead.city!
                                                          .trim()
                                                          .isNotEmpty)
                                                  ? lead.city!.trim()
                                                  : null;
                                              final categoryStr =
                                                  (lead.category != null &&
                                                      lead.category!
                                                          .trim()
                                                          .isNotEmpty &&
                                                      lead.category!
                                                              .trim()
                                                              .toLowerCase() !=
                                                          'general')
                                                  ? lead.category!.trim()
                                                  : null;

                                              String primaryText = '';
                                              String? secondaryText;
                                              IconData rowIcon =
                                                  Remix.user_line;

                                              if (contactPerson != null &&
                                                  contactPerson.isNotEmpty) {
                                                primaryText = contactPerson;
                                                secondaryText =
                                                    phoneStr ??
                                                    cityStr ??
                                                    categoryStr;
                                                rowIcon = Remix.user_line;
                                              } else if (phoneStr != null) {
                                                primaryText = phoneStr;
                                                secondaryText =
                                                    cityStr ?? categoryStr;
                                                rowIcon = Remix.phone_line;
                                              } else if (cityStr != null) {
                                                primaryText = cityStr;
                                                secondaryText = categoryStr;
                                                rowIcon = Remix.map_pin_line;
                                              } else if (categoryStr != null) {
                                                primaryText = categoryStr;
                                                rowIcon =
                                                    Remix.price_tag_3_line;
                                              }

                                              if (primaryText.isEmpty) {
                                                return const SizedBox.shrink();
                                              }

                                              return Row(
                                                children: [
                                                  Icon(
                                                    rowIcon,
                                                    size: 14,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      primaryText,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (secondaryText != null &&
                                                      secondaryText
                                                          .isNotEmpty) ...[
                                                    const Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                          ),
                                                      child: Text(
                                                        '•',
                                                        style: TextStyle(
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                                    Flexible(
                                                      child: Text(
                                                        secondaryText,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.grey,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 12),

                                          // Bottom Row: Social Icons, Source & Arrow
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              if (lead.hasSocialOrWebsite) ...[
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (lead
                                                                .socialMedia!
                                                                .instagram !=
                                                            null &&
                                                        lead
                                                            .socialMedia!
                                                            .instagram!
                                                            .isNotEmpty)
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              right: 5,
                                                            ),
                                                        child: Icon(
                                                          Remix.instagram_line,
                                                          size: 14,
                                                          color: Color(
                                                            0xFFE1306C,
                                                          ),
                                                        ),
                                                      ),
                                                    if (lead
                                                                .socialMedia!
                                                                .facebook !=
                                                            null &&
                                                        lead
                                                            .socialMedia!
                                                            .facebook!
                                                            .isNotEmpty)
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              right: 5,
                                                            ),
                                                        child: Icon(
                                                          Remix
                                                              .facebook_circle_line,
                                                          size: 14,
                                                          color: Color(
                                                            0xFF1877F2,
                                                          ),
                                                        ),
                                                      ),
                                                    if (lead
                                                                .socialMedia!
                                                                .linkedin !=
                                                            null &&
                                                        lead
                                                            .socialMedia!
                                                            .linkedin!
                                                            .isNotEmpty)
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              right: 5,
                                                            ),
                                                        child: Icon(
                                                          Remix
                                                              .linkedin_box_line,
                                                          size: 14,
                                                          color: Color(
                                                            0xFF0A66C2,
                                                          ),
                                                        ),
                                                      ),
                                                    if (lead
                                                                .socialMedia!
                                                                .youtube !=
                                                            null &&
                                                        lead
                                                            .socialMedia!
                                                            .youtube!
                                                            .isNotEmpty)
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              right: 5,
                                                            ),
                                                        child: Icon(
                                                          Remix.youtube_line,
                                                          size: 14,
                                                          color: Color(
                                                            0xFFFF0000,
                                                          ),
                                                        ),
                                                      ),
                                                    if (lead
                                                                .socialMedia!
                                                                .twitter !=
                                                            null &&
                                                        lead
                                                            .socialMedia!
                                                            .twitter!
                                                            .isNotEmpty)
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              right: 5,
                                                            ),
                                                        child: Icon(
                                                          Remix.twitter_x_line,
                                                          size: 14,
                                                          color: Color(
                                                            0xFF1E293B,
                                                          ),
                                                        ),
                                                      ),
                                                    if (lead
                                                                .socialMedia
                                                                ?.tiktok !=
                                                            null &&
                                                        lead
                                                            .socialMedia!
                                                            .tiktok!
                                                            .isNotEmpty)
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              right: 5,
                                                            ),
                                                        child: Icon(
                                                          Remix.tiktok_fill,
                                                          size: 14,
                                                          color: Color(
                                                            0xFF000000,
                                                          ),
                                                        ),
                                                      ),
                                                    if (lead
                                                                .socialMedia
                                                                ?.pinterest !=
                                                            null &&
                                                        lead
                                                            .socialMedia!
                                                            .pinterest!
                                                            .isNotEmpty)
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              right: 5,
                                                            ),
                                                        child: Icon(
                                                          Remix.pinterest_fill,
                                                          size: 14,
                                                          color: Color(
                                                            0xFFE60023,
                                                          ),
                                                        ),
                                                      ),
                                                    if ((lead.website != null &&
                                                            lead
                                                                .website!
                                                                .isNotEmpty) ||
                                                        (lead
                                                                    .socialMedia
                                                                    ?.website !=
                                                                null &&
                                                            lead
                                                                .socialMedia!
                                                                .website!
                                                                .isNotEmpty))
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              right: 5,
                                                            ),
                                                        child: Icon(
                                                          Remix.global_line,
                                                          size: 14,
                                                          color: Color(
                                                            0xFF0D9488,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const Spacer(),
                                              ] else ...[
                                                const Spacer(),
                                              ],
                                              Text(
                                                'Source: ${lead.sourceDisplayName}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.right,
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Remix.arrow_right_s_line,
                                                size: 16,
                                                color: AppColors.primary,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSkeleton(
    BuildContext context, {
    bool isVisitor = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          if (!isVisitor) ...[
            const SizedBox(height: 12),
            _buildFilterChipsSkeleton(),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChipsSkeleton() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Container(
              width: index == 0 ? 68 : 96,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedUI() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Remix.lock_line,
                size: 48,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Access Denied',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You do not have permission to view leads in the CRM.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllChip(int totalCount, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        showCheckmark: false,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Remix.check_line, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              'All',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            if (totalCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ],
        ),
        onSelected: (_) {
          if (isSelected) return;
          _debounceTimer?.cancel();
          ref.read(leadsFilterProvider.notifier).clearStage();
          setState(() {
            _isSelectionMode = false;
            _selectedLeadIds.clear();
          });
          ref
              .read(leadsProvider.notifier)
              .refreshLeads(search: _searchController.text.trim());
        },
      ),
    );
  }

  Widget _buildStageFilterChip(
    LeadStageModel stage,
    int count, {
    required bool isSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        showCheckmark: false,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
        avatar: isSelected
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: stage.stageColor,
                  shape: BoxShape.circle,
                ),
              ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Remix.check_line, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              stage.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : stage.stageColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : stage.stageColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        onSelected: (selected) {
          _debounceTimer?.cancel();
          setState(() {
            _isSelectionMode = false;
            _selectedLeadIds.clear();
          });
          if (selected) {
            setState(() {
              _cachedStageCounts.remove(stage.id.toString());
              _cachedStageCounts.remove(stage.key.toUpperCase());
            });
            ref
                .read(leadsFilterProvider.notifier)
                .setStage(stageId: stage.id.toString(), stageKey: stage.key);
            ref
                .read(leadsProvider.notifier)
                .refreshLeads(
                  stageId: stage.id.toString(),
                  search: _searchController.text.trim(),
                );
          } else {
            ref.read(leadsFilterProvider.notifier).clearStage();
            ref
                .read(leadsProvider.notifier)
                .refreshLeads(search: _searchController.text.trim());
          }
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final filter = ref.read(leadsFilterProvider);
    final hasSearchOrFilter =
        _searchController.text.trim().isNotEmpty || !filter.isAll;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Remix.inbox_line,
                size: 48,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No leads found in pipeline.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearchOrFilter
                  ? 'Try changing the filter or search criteria.'
                  : 'New leads assigned to you will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            if (hasSearchOrFilter) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _debounceTimer?.cancel();
                  ref.read(leadsFilterProvider.notifier).clearFilter();
                  setState(() {
                    _searchController.clear();
                  });
                  ref.read(leadsProvider.notifier).refreshLeads();
                },
                icon: const Icon(Remix.filter_off_line, size: 16),
                label: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isLeadInVisitScheduledStage(LeadModel lead) {
    final status = lead.status.trim().toUpperCase();
    final stageName = (lead.stageNameConfig ?? '').trim().toUpperCase();
    final stageIdStr = (lead.stageId ?? '').trim().toUpperCase();

    // If it is explicitly marked DONE / COMPLETED / VISIT_DONE, it is NOT in Visit Scheduled
    if (status == 'VISIT_DONE' ||
        status.contains('DONE') ||
        status.contains('COMPLETE') ||
        stageName.contains('DONE') ||
        stageName.contains('COMPLETE') ||
        stageIdStr.contains('DONE')) {
      return false;
    }

    // Direct status / stage name / stageId string match
    if (status == 'VISIT_SCHEDULED' ||
        status == 'VISIT' ||
        status.contains('SCHEDULE') ||
        status.contains('VISIT') ||
        stageName.contains('SCHEDULE') ||
        stageName.contains('VISIT') ||
        stageIdStr == 'VISIT_SCHEDULED' ||
        stageIdStr == 'VISIT') {
      return true;
    }

    // Check if the lead has any active or scheduled visits
    if (lead.visits.isNotEmpty) {
      final hasActiveVisit = lead.visits.any((v) {
        final vst = v.status.trim().toUpperCase();
        return vst != 'CANCELLED' &&
            vst != 'REJECTED' &&
            (vst == 'SCHEDULED' ||
                vst == 'IN_PROGRESS' ||
                vst.contains('SCHEDULE'));
      });
      if (hasActiveVisit) return true;
    }

    // Cross-reference with stages list by numeric stageId or key
    final stages = ref.read(leadStagesProvider).asData?.value;
    if (stages != null && stages.isNotEmpty) {
      for (final s in stages) {
        final sKey = s.key.trim().toUpperCase();
        final sName = s.name.trim().toUpperCase();
        if ((sKey.contains('VISIT') || sName.contains('VISIT')) &&
            !sKey.contains('DONE') &&
            !sName.contains('DONE')) {
          if (lead.stageId != null &&
              (lead.stageId == s.id.toString() ||
                  lead.stageId!.toUpperCase() == sKey)) {
            return true;
          }
        }
      }
    }

    return false;
  }
}

class _LeadThumb extends StatelessWidget {
  final LeadModel lead;
  const _LeadThumb({required this.lead});

  @override
  Widget build(BuildContext context) {
    final letter = lead.displayTitle.trim().isEmpty ? 'L' : lead.displayTitle.trim()[0].toUpperCase();
    final fallback = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
      child: Text(letter, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
    );
    final image = lead.primaryImage;
    if (image == null || !LeadModel.isValidRealImageUrl(image.url)) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        LeadImageModel.resolveUrl(image.url),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
