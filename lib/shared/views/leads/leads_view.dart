import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:quickboom_crm_customer/core/network/api_exception.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart' as customer_model;
import 'package:quickboom_crm_customer/roles/customer/widgets/schedule_visit_bottom_sheet.dart';
import 'package:quickboom_crm_customer/shared/models/lead_model.dart';
import 'package:quickboom_crm_customer/shared/models/lead_stage_model.dart';
import 'package:quickboom_crm_customer/shared/viewmodels/lead_stages_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/viewmodels/leads_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/shared/widgets/lead_business_image.dart';
import 'package:quickboom_crm_customer/shared/widgets/social_media_profiles_card.dart';
import 'lead_details_view.dart';

class LeadsView extends ConsumerStatefulWidget {
  const LeadsView({super.key});

  @override
  ConsumerState<LeadsView> createState() => _LeadsViewState();
}

class _LeadsViewState extends ConsumerState<LeadsView>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  String _selectedStatus = '';
  int? _selectedStageId;
  final Set<String> _selectedLeadIds = {};
  bool _selectingLeads = false;
  bool _deletingLeads = false;

  (String, String) _leadLoadError(Object error) {
    final status = error is DioException
        ? error.response?.statusCode
        : error is ApiException
        ? error.statusCode
        : null;
    if (status == 401) {
      return (
        'Unable to load leads',
        'Your session needs attention. Retry to refresh it, or sign in again if it has expired.',
      );
    }
    if (status == 403) {
      return (
        'Unable to load leads',
        'You do not currently have permission to access these leads, or your session needs attention.',
      );
    }
    if (error is DioException && error.response == null) {
      return (
        'Unable to load leads',
        'The network connection was interrupted. Check your connection and retry.',
      );
    }
    if (status != null && status >= 500) {
      return (
        'Unable to load leads',
        'The server could not load leads right now. Retry in a moment.',
      );
    }
    return (
      'Unable to load leads',
      'The lead list could not be loaded. Retry without leaving this screen.',
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_loadMoreIfNeeded);
    // Each new route starts with All and an empty search; discard another
    // route's query so the results match the visible controls.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(leadStagesProvider);
      final notifier = ref.read(leadsProvider.notifier);
      final current = ref.read(leadsProvider);
      final hasRows = current.asData?.value.isNotEmpty ?? false;
      if (!notifier.hasQuery && hasRows) return;
      if (current.isLoading && notifier.hasLoaded) return;
      _onSearchSubmitted();
    });
  }

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 480) {
      ref.read(leadsProvider.notifier).loadMore();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(leadsProvider.notifier).refreshLeads();
      ref.read(leadStagesProvider.notifier).refresh();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_loadMoreIfNeeded);
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), _onSearchSubmitted);
  }

  void _onSearchSubmitted() {
    _searchDebounce?.cancel();
    _fetchLeads();
  }

  Future<void> _retryFailedLoads() async {
    final stagesFailed = ref.read(leadStagesProvider).hasError;
    final leadsFailed = ref.read(leadsProvider).hasError;
    if (stagesFailed) {
      await ref.read(leadStagesProvider.notifier).refresh();
    }
    if (leadsFailed || !stagesFailed) {
      await ref.read(leadsProvider.notifier).refreshLeads();
    }
  }

  void _fetchLeads() {
    ref.read(leadsProvider.notifier).fetchLeads(
      status: _selectedStatus.isEmpty ? null : _selectedStatus,
      stageId: _selectedStageId,
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      refreshCounts: true,
    );
  }

  void _toggleLeadSelection(String id) {
    setState(() {
      _selectingLeads = true;
      if (_selectedLeadIds.contains(id)) {
        _selectedLeadIds.remove(id);
      } else {
        _selectedLeadIds.add(id);
      }
    });
  }

  Future<void> _deleteSelectedLeads() async {
    if (_selectedLeadIds.isEmpty || _deletingLeads) return;
    final count = _selectedLeadIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${count == 1 ? 'lead' : 'leads'}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text(
          count == 1 ? 'Delete this lead?' : 'Delete $count leads?',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingLeads = true);
    try {
      await ref.read(leadsProvider.notifier).deleteLeads(_selectedLeadIds.toList());
      if (!mounted) return;
      setState(() {
        _selectedLeadIds.clear();
        _selectingLeads = false;
        _deletingLeads = false;
      });
      AppToast.success(context, count == 1 ? 'Lead deleted' : '$count leads deleted');
    } catch (error) {
      if (!mounted) return;
      setState(() => _deletingLeads = false);
      final message = error is DioException && error.response?.data is Map
          ? (error.response!.data as Map)['message']?.toString()
          : null;
      AppToast.error(context, message == null || message.isEmpty ? 'The lead could not be deleted.' : message);
    }
  }

  Widget _pipelineAppBarIcon(IconData icon, VoidCallback onTap, String tooltip, {bool circled = false}) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.only(left: 8),
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      icon: circled
          ? Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD5DEE8), width: 1.2),
              ),
              child: Icon(icon, size: 16, color: const Color(0xFF1A2332)),
            )
          : Icon(icon, size: 20, color: const Color(0xFF1A2332)),
    );
  }

  void _onFilterSelected(String status, int? stageId) {
    if (_selectedStatus == status && _selectedStageId == stageId) return;
    setState(() { _selectedStatus = status; _selectedStageId = stageId; });
    _fetchLeads();
  }

  Widget _buildFilterChipsSkeleton() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(
          6,
          (i) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              height: 34,
              width: 72 + (i % 3) * 16.0,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadsLoading() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Container(
                  height: 22,
                  width: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 14,
              width: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  height: 12,
                  width: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                Container(
                  height: 12,
                  width: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadsState = ref.watch(leadsProvider);
    final stagesAsync = ref.watch(leadStagesProvider);
    final stages = ref.watch(activeLeadStagesProvider);
    final stageCounts = ref.watch(leadsStageCountsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppAppBar(
        title: _selectingLeads
            ? (_selectedLeadIds.isEmpty ? 'Select leads' : '${_selectedLeadIds.length} selected')
            : 'Leads Pipeline',
        actions: [
          _pipelineAppBarIcon(
            Remix.delete_bin_line,
            () {
              if (_deletingLeads) return;
              if (_selectedLeadIds.isNotEmpty) {
                _deleteSelectedLeads();
                return;
              }
              setState(() => _selectingLeads = !_selectingLeads);
            },
            _selectedLeadIds.isEmpty ? 'Select leads' : 'Delete selected',
          ),
          _pipelineAppBarIcon(Remix.refresh_line, () {
            ref.read(leadStagesProvider.notifier).refresh();
            ref.read(leadsProvider.notifier).refreshLeads();
          }, 'Refresh'),
          _pipelineAppBarIcon(Remix.add_line, _showAddLead, 'Add lead', circled: true),
        ],
      ),
      body: Column(
        children: [
          if (stagesAsync.hasError)
            Material(
              color: const Color(0xFFFEF2F2),
              child: ListTile(
              dense: true,
              tileColor: const Color(0xFFFEF2F2),
              leading: const Icon(Remix.error_warning_line, color: Colors.red),
              title: Text(
                'Unable to load pipeline stages',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.red.shade900,
                ),
              ),
              subtitle: Text(
                stagesAsync.error is ApiException ? (stagesAsync.error! as ApiException).userMessage : 'The stage list could not be loaded.',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.red.shade800),
              ),
              trailing: TextButton(
                onPressed: _retryFailedLoads,
                child: const Text('Retry'),
              ),
            ),
            ),
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: TextField(
                    controller: _searchController,
                    textAlignVertical: TextAlignVertical.center,
                    style: GoogleFonts.outfit(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search leads by name, phone, city...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      prefixIcon: const Icon(Remix.search_2_line, size: 20),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Remix.close_circle_line, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                                _onSearchSubmitted();
                              },
                            ),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _onSearchSubmitted(),
                  )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Horizontal Stage Filter Chips
                if (stagesAsync.isLoading && stages.isEmpty)
                  _buildFilterChipsSkeleton()
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildStageChip(
                          name: 'All',
                          key: '',
                          isSelected: _selectedStatus.isEmpty,
                          color: AppColors.primary,
                          count: leadsState.hasError && !leadsState.hasValue ? null : stageCounts[''] ?? stageCounts['ALL'],
                        ),
                        for (final stage in stages)
                          _buildStageChip(
                            name: stage.name,
                            key: stage.key,
                            stageId: stage.id,
                            isSelected: _selectedStatus.toUpperCase() == stage.key.toUpperCase() || _selectedStatus == stage.id.toString(),
                            color: stage.stageColor,
                            bgColor: stage.stageBgColor,
                            count: _countFor(stageCounts, stage, stage.key),
                          ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                if (!stagesAsync.isLoading && !stagesAsync.hasError && stages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text('No stages available', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),

          if (leadsState.isLoading && leadsState.hasValue)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            )
          else
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Leads List
          Expanded(
            child: leadsState.when(
              skipLoadingOnReload: true,
              loading: () => ref.read(leadsProvider.notifier).hasLoaded
                  ? const Center(child: CircularProgressIndicator())
                  : _buildLeadsLoading(),
              error: (err, _) {
                final copy = _leadLoadError(err);
                return ListView(
                children: [
                  const SizedBox(height: 24),
                  const Icon(
                    Remix.error_warning_line,
                    size: 36,
                    color: Colors.grey,
                  ),
                      const SizedBox(height: 12),
                      Text(
                        copy.$1,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        copy.$2,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(leadsProvider.notifier).refreshLeads(),
                        child: const Text('Retry'),
                      ),
                ],
              );
              },
              data: (leads) {
                final displayLeads = leads;

                if (displayLeads.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Remix.inbox_line,
                            size: 56,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No leads found',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchController.text.trim().isNotEmpty
                                ? 'No leads match this search.'
                                : _selectedStatus.isNotEmpty
                                ? 'No leads in this stage.'
                                : 'No leads currently in your CRM pipeline.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(leadStagesProvider.notifier).refresh();
                    await ref.read(leadsProvider.notifier).refreshLeads();
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 840 ? 2 : 1;
                      final rows = columns == 1 ? displayLeads.length : (displayLeads.length + 1) ~/ 2;
                      final loadingMore = ref.read(leadsProvider.notifier).loadingMore;
                      return ListView.separated(
                        // ignore: deprecated_member_use
                        cacheExtent: 800,
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.paddingOf(context).bottom),
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        itemCount: rows + (loadingMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          if (idx >= rows) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }
                          if (columns == 1) return _pipelineCard(displayLeads[idx]);
                          final left = idx * 2;
                          final right = left + 1;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _pipelineCard(displayLeads[left])),
                              const SizedBox(width: 12),
                              Expanded(child: right < displayLeads.length ? _pipelineCard(displayLeads[right]) : const SizedBox.shrink()),
                            ],
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int? _countFor(Map<String, int> counts, LeadStageModel? stage, String key) {
    if (stage != null && counts.containsKey(stage.id.toString())) return counts[stage.id.toString()];
    return counts[key] ?? counts[key.toUpperCase()];
  }

  String _month(int month) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];

  Future<void> _showAddLead() async {
    final draft = await showModalBottomSheet<_LeadDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _AddLeadSheet(stages: ref.read(activeLeadStagesProvider)),
    );
    if (draft == null || !mounted) return;
    try {
      await ref.read(leadsProvider.notifier).createLead({
        'title': draft.company,
        'companyName': draft.company,
        'phone': draft.phone,
        'city': draft.city,
        if (draft.state.isNotEmpty) 'state': draft.state,
        if (draft.pincode.isNotEmpty) 'pincode': draft.pincode,
        if (draft.website != null) 'website': draft.website,
        if (draft.social.isNotEmpty) 'socialMedia': draft.social,
        if (draft.stage != null) 'stageId': draft.stage!.id,
        if (draft.stage != null) 'status': draft.stage!.key,
      });
      if (mounted) AppToast.success(context, 'Lead created');
    } catch (error) {
      if (mounted) AppToast.error(context, 'The lead could not be created.');
    }
  }

  Widget _buildStageChip({
    required String name,
    required String key,
    required bool isSelected,
    required Color color,
    Color? bgColor,
    int? count,
    int? stageId,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _onFilterSelected(key, stageId),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF16A34A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                const Icon(Remix.check_line, size: 14, color: Colors.white)
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                ),
              const SizedBox(width: 6),
              Text(
                name,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF111827),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _sourceLabel(String source) {
    final words = source.trim().replaceAll('_', ' ').split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    if (words.isEmpty) return 'Manual';
    return words.map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}').join(' ');
  }

  Widget _infoLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(fontSize: 13, height: 1.3, color: const Color(0xFF475569)),
          ),
        ),
      ],
    );
  }

  String _phoneDigits(String? phone) => phone?.replaceAll(RegExp(r'[^\d]'), '') ?? '';

  bool _validEmail(String email) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  Widget _pipelineCard(LeadModel lead) {
    final resolvedStage = ref.read(leadStagesProvider.notifier).resolveLeadStage(lead.stageId, lead.status);
    return _buildLeadCard(
      lead: lead,
      stageName: resolvedStage?.name ?? lead.stageName,
      stageColor: resolvedStage?.stageColor ?? lead.stageColor,
      stageBgColor: resolvedStage?.stageBgColor ?? lead.stageBgColor,
      stageBorderColor: resolvedStage?.stageBorderColor ?? lead.stageBorderColor,
    );
  }

  Widget _buildLeadCard({
    required LeadModel lead,
    required String stageName,
    required Color stageColor,
    required Color stageBgColor,
    required Color stageBorderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _selectedLeadIds.contains(lead.id) ? AppColors.primary : const Color(0xFFE2E8F0), width: _selectedLeadIds.contains(lead.id) ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () => _toggleLeadSelection(lead.id),
          onTap: () {
            if (_selectingLeads) {
              _toggleLeadSelection(lead.id);
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    LeadDetailsView(leadId: lead.id, initialLead: lead),
              ),
            ).then((_) {
              ref.read(leadsProvider.notifier).refreshLeads();
            });
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 360;
              final roomy = constraints.maxWidth >= 520;
              final imageSize = roomy ? 76.0 : 64.0;
              final phone = _phoneDigits(lead.phone);
              final email = lead.email?.trim() ?? '';
              final hasPhone = phone.length >= 6;
              final hasEmail = _validEmail(email);
              final place = [lead.city, lead.state].whereType<String>().map((part) => part.trim()).where((part) => part.isNotEmpty).join(', ');
              return Padding(
                padding: EdgeInsets.fromLTRB(roomy ? 16 : 12, 12, roomy ? 16 : 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectingLeads) ...[
                          Icon(
                            _selectedLeadIds.contains(lead.id) ? Remix.checkbox_circle_fill : Remix.checkbox_blank_circle_line,
                            size: 20,
                            color: _selectedLeadIds.contains(lead.id) ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 8),
                        ],
                        LeadBusinessImage(lead: lead, size: imageSize, radius: 12),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      lead.displayName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(fontSize: roomy ? 17 : 16, fontWeight: FontWeight.w700, height: 1.25, color: const Color(0xFF111827)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.32),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: stageBgColor,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: stageBorderColor),
                                      ),
                                      child: Text(
                                        stageName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: stageColor),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if ((lead.category ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(lead.category!.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                              ],
                              const SizedBox(height: 2),
                              Text('Lead #${lead.id}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (hasPhone || (lead.phone ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoLine(Remix.phone_line, (lead.phone ?? '').trim()),
                    ],
                    if (place.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _infoLine(Remix.map_pin_2_line, place),
                    ],
                    const SizedBox(height: 4),
                    _infoLine(Remix.global_line, 'Source: ${_sourceLabel(lead.source)}'),
                    LeadSocialIconRow(socialMedia: lead.socialMedia, website: lead.website, wrap: true),
                    const Padding(
                      padding: EdgeInsets.only(top: 10, bottom: 10),
                      child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                    ),
                    Row(
                      children: [
                        Expanded(child: _cardAction(Remix.phone_line, 'Call', hasPhone ? () => _onLeadAction('call', lead) : () => AppToast.error(context, 'This lead has no phone number.'), narrow, hasPhone)),
                        const SizedBox(width: 6),
                        Expanded(child: _cardAction(Remix.whatsapp_line, 'WhatsApp', hasPhone ? () => _onLeadAction('whatsapp', lead) : () => AppToast.error(context, 'This lead has no phone number.'), narrow, hasPhone)),
                        const SizedBox(width: 6),
                        Expanded(child: _cardAction(Remix.mail_line, 'Email', hasEmail ? () => _onLeadAction('email', lead) : () => AppToast.error(context, 'This lead has no email address.'), narrow, hasEmail)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _visitWhen(LeadVisitModel visit) {
    final parsed = DateTime.tryParse(visit.date);
    final local = parsed?.toLocal();
    final date = local == null
        ? (visit.date.length >= 10 ? visit.date.substring(0, 10) : visit.date)
        : '${local.day} ${_month(local.month)} ${local.year}';
    final clock = _clockLabel(visit.time) ?? (local == null || (local.hour == 0 && local.minute == 0 && (visit.time == null || visit.time!.isEmpty)) ? null : _clockFromDate(local));
    return [date, clock].where((part) => part != null && part.isNotEmpty).join(' · ');
  }

  String? _clockLabel(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return value;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return value;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  String _clockFromDate(DateTime value) {
    final period = value.hour >= 12 ? 'PM' : 'AM';
    final hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '$hour12:${value.minute.toString().padLeft(2, '0')} $period';
  }

  Widget _cardAction(IconData icon, String label, VoidCallback onTap, bool narrow, bool enabled) {
    final color = enabled ? const Color(0xFF16A34A) : const Color(0xFF94A3B8);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFE8F7ED) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: narrow
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(height: 2),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: color))),
                ],
              ),
      ),
    );
  }

  Future<void> _onLeadAction(String action, LeadModel lead) async {
    if (action == 'select') {
      _toggleLeadSelection(lead.id);
      return;
    }
    if (action == 'email') {
      final email = lead.email?.trim() ?? '';
      if (!_validEmail(email)) {
        AppToast.error(context, 'This lead has no email address.');
        return;
      }
      final launched = await launchUrl(Uri(scheme: 'mailto', path: email));
      if (!launched && mounted) AppToast.error(context, 'The email app could not be opened.');
      return;
    }
    if (action == 'whatsapp') {
      final phone = _phoneDigits(lead.phone);
      if (phone.length < 6) {
        AppToast.error(context, 'This lead has no phone number.');
        return;
      }
      final launched = await launchUrl(Uri.parse('https://wa.me/$phone'), mode: LaunchMode.externalApplication);
      if (!launched && mounted) AppToast.error(context, 'WhatsApp could not be opened.');
      return;
    }
    if (action == 'call') {
      final phone = lead.phone?.trim() ?? '';
      if (_phoneDigits(phone).length < 6) {
        AppToast.error(context, 'This lead has no phone number.');
        return;
      }
      final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
      if (!launched && mounted) AppToast.error(context, 'The phone app could not be opened.');
      return;
    }
    if (action == 'view') {
      _showVisit(lead);
      return;
    }
    if (action == 'schedule') {
      final updated = await showScheduleVisitBottomSheet(
        context,
        lead: customer_model.LeadModel.fromJson(lead.toJson()),
        ref: ref,
      );
      if (updated != null) await ref.read(leadsProvider.notifier).refreshLeads();
      return;
    }
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _NoteSheet(),
    );
    if (note == null || note.isEmpty || !mounted) return;
    try {
      await ref.read(leadsProvider.notifier).addNote(lead.id, note);
      if (mounted) AppToast.success(context, 'Note added');
    } catch (_) {
      if (mounted) AppToast.error(context, 'The note could not be saved.');
    }
  }

  void _showVisit(LeadModel lead) {
    final visit = lead.nextScheduledVisit;
    if (visit == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scheduled visit', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _visitLine('Visit date', _visitWhen(visit).split(' · ').first),
              _visitLine('Visit time', _clockLabel(visit.time) ?? '—'),
              _visitLine('Assigned employee/visitor', visit.assignedEmployee ?? lead.assignedToName ?? '—'),
              _visitLine('Visit location', visit.location),
              _visitLine('Visit status', visit.status),
              if (visit.notes != null && visit.notes!.trim().isNotEmpty) _visitLine('Notes', visit.notes!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _visitLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: GoogleFonts.outfit(color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _NoteSheet extends StatefulWidget {
  const _NoteSheet();

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add Note', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: _note, maxLines: 4, decoration: const InputDecoration(labelText: 'Note')),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final value = _note.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(context, value);
              },
              child: const Text('Save Note'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadDraft {
  final String company;
  final String phone;
  final String city;
  final String state;
  final String pincode;
  final String? website;
  final Map<String, String> social;
  final LeadStageModel? stage;

  const _LeadDraft({
    required this.company,
    required this.phone,
    required this.city,
    required this.state,
    required this.pincode,
    required this.website,
    required this.social,
    required this.stage,
  });
}

class _AddLeadSheet extends StatefulWidget {
  final List<LeadStageModel> stages;
  const _AddLeadSheet({required this.stages});

  @override
  State<_AddLeadSheet> createState() => _AddLeadSheetState();
}

class _AddLeadSheetState extends State<_AddLeadSheet> {
  final _company = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _stateName = TextEditingController();
  final _pincode = TextEditingController();
  final _website = TextEditingController();
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();
  final _linkedin = TextEditingController();
  late final LeadStageModel? _stage = widget.stages.isEmpty ? null : widget.stages.first;
  String? _companyError;

  @override
  void dispose() {
    for (final controller in [_company, _phone, _city, _stateName, _pincode, _website, _instagram, _facebook, _linkedin]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _link(TextEditingController controller, {bool allowHandle = false}) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    if (allowHandle && value.startsWith('@')) return value;
    return value.startsWith(RegExp(r'https?://', caseSensitive: false)) ? value : 'https://$value';
  }

  void _save() {
    final company = _company.text.trim();
    if (company.isEmpty) {
      setState(() => _companyError = 'Enter the business name');
      return;
    }
    final social = <String, String>{};
    final instagram = _link(_instagram, allowHandle: true);
    final facebook = _link(_facebook);
    final linkedin = _link(_linkedin);
    if (instagram != null) social['instagram'] = instagram;
    if (facebook != null) social['facebook'] = facebook;
    if (linkedin != null) social['linkedin'] = linkedin;
    Navigator.pop(context, _LeadDraft(
      company: company,
      phone: _phone.text.trim(),
      city: _city.text.trim(),
      state: _stateName.text.trim(),
      pincode: _pincode.text.trim(),
      website: _link(_website),
      social: social,
      stage: _stage,
    ));
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
    );
  }

  Widget _box(TextEditingController controller, String hint, {TextInputType? keyboard, int? maxLength, String? error, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLength: maxLength,
      onChanged: onChanged,
      style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF172033)),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        errorText: error,
        hintStyle: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFFB0B8C4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF22C55E))),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.9 - inset;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: height < 320 ? 320 : height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text('New Lead', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF172033)))),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Business name'),
                    _box(_company, 'Business name', error: _companyError, onChanged: (_) {
                      if (_companyError != null) setState(() => _companyError = null);
                    }),
                    const SizedBox(height: 14),
                    _label('Phone'),
                    _box(_phone, 'Phone number', keyboard: TextInputType.phone),
                    const SizedBox(height: 14),
                    _label('City'),
                    _box(_city, 'e.g. Mumbai'),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('State'), _box(_stateName, 'e.g. MH')])),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Pincode'), _box(_pincode, '000000', keyboard: TextInputType.number, maxLength: 6)])),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text('Social Media & Web', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                    const SizedBox(height: 14),
                    _label('Website URL'),
                    _box(_website, 'https://company.com', keyboard: TextInputType.url),
                    const SizedBox(height: 14),
                    _label('Instagram'),
                    _box(_instagram, 'https://instagram.com/... or @handle', keyboard: TextInputType.url),
                    const SizedBox(height: 14),
                    _label('Facebook'),
                    _box(_facebook, 'https://facebook.com/...', keyboard: TextInputType.url),
                    const SizedBox(height: 14),
                    _label('LinkedIn'),
                    _box(_linkedin, 'https://linkedin.com/...', keyboard: TextInputType.url),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('CREATE LEAD', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
