import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lead_model.dart';
import '../models/lead_status_update_result.dart';
import '../services/lead_service.dart';
import 'lead_stages_viewmodel.dart';

final leadsProvider =
    NotifierProvider<LeadsViewModel, AsyncValue<List<LeadModel>>>(() {
      return LeadsViewModel();
    });

/// Provider exposing total and per-stage lead counts derived from full pipeline data.
final leadsStageCountsProvider = Provider<Map<String, int>>((ref) {
  ref.watch(leadsProvider);
  return ref.read(leadsProvider.notifier).stageCounts;
});

final sharedLeadNotesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, leadId) async {
      final service = ref.watch(leadServiceProvider);
      return service.getNotes(leadId);
    });

class LeadsViewModel extends Notifier<AsyncValue<List<LeadModel>>> {
  LeadService get _leadService => ref.read(leadServiceProvider);
  String? _lastStatus;
  int? _lastStageId;
  String? _lastSearch;
  String? _lastSource;
  String? _lastCategory;
  int? _lastAssignedToId;
  String? _lastFrom;
  String? _lastTo;
  int _fetchGeneration = 0;
  Future<void>? _inFlight;
  String? _requestKey;
  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;
  int _page = 1;
  int _totalPages = 1;
  bool _loadingMore = false;
  List<LeadModel> _allLeads = const [];
  Map<String, int> _stageCounts = const {};

  Map<String, int> get stageCounts => _stageCounts;
  bool get hasMore => _page < _totalPages;
  bool get loadingMore => _loadingMore;
  bool get hasQuery =>
      _lastStageId != null ||
      (_lastStatus != null && _lastStatus!.isNotEmpty) ||
      (_lastSearch != null && _lastSearch!.trim().isNotEmpty) ||
      (_lastSource != null && _lastSource!.trim().isNotEmpty) ||
      (_lastCategory != null && _lastCategory!.trim().isNotEmpty) ||
      _lastAssignedToId != null ||
      (_lastFrom != null && _lastFrom!.isNotEmpty) ||
      (_lastTo != null && _lastTo!.isNotEmpty);

  @override
  AsyncValue<List<LeadModel>> build() {
    Future.microtask(() {
      if (ref.mounted && _fetchGeneration == 0) fetchLeads();
    });
    return const AsyncValue.loading();
  }

  void _updateCounts(List<LeadModel> leads) {
    final stagesNotifier = ref.read(leadStagesProvider.notifier);
    final counts = <String, int>{'': leads.length, 'ALL': leads.length};
    for (final stage in ref.read(activeLeadStagesProvider)) {
      counts[stage.key.toUpperCase()] = 0;
      counts[stage.id.toString()] = 0;
    }
    for (final lead in leads) {
      final resolved = stagesNotifier.resolveLeadStage(
        lead.stageId,
        lead.status,
      );
      final key = (resolved?.key ?? lead.stage?.key ?? lead.status)
          .toUpperCase();
      counts[key] = (counts[key] ?? 0) + 1;
      if (lead.stageId != null) {
        counts[lead.stageId.toString()] =
            (counts[lead.stageId.toString()] ?? 0) + 1;
      }
    }
    _stageCounts = counts;
  }

  Future<void> fetchLeads({
    String? status,
    String? search,
    int? stageId,
    String? source,
    String? category,
    int? assignedToId,
    String? from,
    String? to,
    bool refreshCounts = false,
  }) async {
    final key = jsonEncode([
      status,
      stageId,
      search,
      source,
      category,
      assignedToId,
      from,
      to,
    ]);
    if (_inFlight != null && key == _requestKey) return _inFlight;
    _requestKey = key;
    final request = _fetchPage(
      status: status,
      search: search,
      stageId: stageId,
      source: source,
      category: category,
      assignedToId: assignedToId,
      from: from,
      to: to,
      refreshCounts: refreshCounts,
    );
    _inFlight = request;
    try {
      await request;
    } finally {
      if (identical(_inFlight, request)) _inFlight = null;
    }
  }

  Future<void> _fetchPage({
    String? status,
    String? search,
    int? stageId,
    String? source,
    String? category,
    int? assignedToId,
    String? from,
    String? to,
    bool refreshCounts = false,
  }) async {
    final sameQuery =
        status == _lastStatus &&
        stageId == _lastStageId &&
        search == _lastSearch &&
        source == _lastSource &&
        category == _lastCategory &&
        assignedToId == _lastAssignedToId &&
        from == _lastFrom &&
        to == _lastTo;
    final generation = ++_fetchGeneration;
    _loadingMore = false;
    _totalPages = 1;
    _lastStatus = status;
    _lastStageId = stageId;
    _lastSearch = search;
    _lastSource = source;
    _lastCategory = category;
    _lastAssignedToId = assignedToId;
    _lastFrom = from;
    _lastTo = to;
    _page = 1;
    final keepVisible = state.asData?.value;
    state = sameQuery && keepVisible != null
        ? const AsyncValue<List<LeadModel>>.loading().copyWithPrevious(state)
        : const AsyncValue.loading();
    try {
      final unfiltered = !hasQuery;
      final result = await _leadService.getLeadPage(
        status: status,
        search: search,
        stageId: stageId,
        source: source,
        category: category,
        assignedToId: assignedToId,
        from: from,
        to: to,
        page: 1,
        limit: 20,
        includeCounts: refreshCounts || (unfiltered && _stageCounts.isEmpty),
      );
      if (!ref.mounted || generation != _fetchGeneration) return;
      _page = result.page;
      _totalPages = result.totalPages;
      debugPrint(
        '[LEADS_DISPLAY] parsed=${result.leads.length} total=${result.total} page=${result.page}/${result.totalPages} ms=${result.durationMs ?? '-'} status=${status ?? 'ALL'}',
      );
      if (result.counts.isNotEmpty) {
        _stageCounts = {
          ...result.counts,
          '': result.counts['ALL'] ?? result.counts[''] ?? result.total,
          'ALL': result.counts['ALL'] ?? result.counts[''] ?? result.total,
        };
      } else if (unfiltered && result.total == result.leads.length) {
        _allLeads = List<LeadModel>.unmodifiable(result.leads);
        _updateCounts(_allLeads);
      } else if (unfiltered) {
        _stageCounts = {'': result.total, 'ALL': result.total};
      }
      _hasLoaded = true;
      state = AsyncValue.data(result.leads);
      unawaited(_fillMissingPhotos(generation));
    } catch (e, st) {
      if (!ref.mounted || generation != _fetchGeneration) return;
      debugPrint('[LeadsViewModel] fetchLeads error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (_inFlight != null || _loadingMore || !hasMore || state.asData == null)
      return;
    final generation = _fetchGeneration;
    _loadingMore = true;
    state = AsyncValue.data(List<LeadModel>.from(state.asData!.value));
    try {
      final result = await _leadService.getLeadPage(
        status: _lastStatus,
        search: _lastSearch,
        stageId: _lastStageId,
        source: _lastSource,
        category: _lastCategory,
        assignedToId: _lastAssignedToId,
        from: _lastFrom,
        to: _lastTo,
        page: _page + 1,
        limit: 20,
      );
      if (!ref.mounted || generation != _fetchGeneration) return;
      _page = result.page;
      _totalPages = result.totalPages;
      _loadingMore = false;
      final seen = state.asData!.value.map((lead) => lead.id).toSet();
      state = AsyncValue.data([
        ...state.asData!.value,
        ...result.leads.where((lead) => seen.add(lead.id)),
      ]);
      unawaited(_fillMissingPhotos(generation));
    } catch (e) {
      debugPrint('[LeadsViewModel] loadMore error: $e');
      if (ref.mounted &&
          generation == _fetchGeneration &&
          state.asData != null) {
        state = AsyncValue.data(List<LeadModel>.from(state.asData!.value));
      }
    } finally {
      if (generation == _fetchGeneration) _loadingMore = false;
    }
  }

  bool _needsPhoto(LeadModel lead) {
    final placeId = lead.googlePlaceId ?? '';
    return (lead.imageUrl ?? '').isEmpty &&
        placeId.isNotEmpty &&
        !placeId.startsWith('custom_');
  }

  void _applyPhotos(List<LeadModel> incoming) {
    final photos = <String, LeadModel>{
      for (final lead in incoming)
        if ((lead.imageUrl ?? '').isNotEmpty) lead.id: lead,
    };
    if (photos.isEmpty) return;
    final current = state.asData?.value;
    if (current == null) return;
    var changed = false;
    final next = current.map((lead) {
      final photo = photos[lead.id];
      if (photo == null || (lead.imageUrl ?? '').isNotEmpty) return lead;
      changed = true;
      return lead.copyWith(
        imageUrl: photo.imageUrl,
        images: photo.images,
        photoCredits: photo.photoCredits,
      );
    }).toList();
    if (changed) state = AsyncValue.data(next);
  }

  /// The list is shown first. Stored capture photos, then a second lead
  /// fetch, fill the picture once Google has saved it.
  Future<void> _fillMissingPhotos(int generation) async {
    if (!(state.asData?.value.any(_needsPhoto) ?? false)) return;
    // The API hydrates newly discovered Google photos in the background. Re-read
    // the lead endpoint so the pipeline can pick up the persisted proxy URL.
    for (final wait in const [Duration(seconds: 3), Duration(seconds: 7)]) {
      await Future<void>.delayed(wait);
      if (!ref.mounted || generation != _fetchGeneration) return;
      final current = state.asData?.value;
      if (current == null || !current.any(_needsPhoto)) return;
      try {
        final again = await _leadService.getLeadPage(
          status: _lastStatus,
          search: _lastSearch,
          stageId: _lastStageId,
          source: _lastSource,
          category: _lastCategory,
          assignedToId: _lastAssignedToId,
          from: _lastFrom,
          to: _lastTo,
          page: 1,
          limit: 20,
        );
        if (!ref.mounted || generation != _fetchGeneration) return;
        _applyPhotos(again.leads);
      } catch (error) {
        debugPrint('[LEAD_IMAGE] background photo refresh failed: $error');
      }
    }
  }

  Future<void> refreshLeads() async {
    await fetchLeads(
      status: _lastStatus,
      search: _lastSearch,
      stageId: _lastStageId,
      source: _lastSource,
      category: _lastCategory,
      assignedToId: _lastAssignedToId,
      from: _lastFrom,
      to: _lastTo,
      refreshCounts: true,
    );
  }

  void prefetchAfterImport() {
    unawaited(fetchLeads(refreshCounts: true));
  }

  Future<LeadModel?> getLeadDetails(String id) async {
    try {
      final lead = await _leadService.getLeadById(id);
      _updateLocalLead(lead);
      return lead;
    } catch (e) {
      debugPrint('[LeadsViewModel] getLeadDetails error: $e');
      rethrow;
    }
  }

  Future<bool> addNote(String id, String content) async {
    try {
      await _leadService.addNote(id, content);
      ref.invalidate(sharedLeadNotesProvider(id));
      await getLeadDetails(id);
      return true;
    } catch (e) {
      debugPrint('[LeadsViewModel] addNote error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getNotes(String id) async {
    try {
      return await _leadService.getNotes(id);
    } catch (e) {
      debugPrint('[LeadsViewModel] getNotes error: $e');
      return [];
    }
  }

  final Map<String, Future<LeadStatusUpdateResult?>> _stageUpdates = {};

  Future<LeadStatusUpdateResult?> updateStatus(
    String id, {
    required String status,
    int? stageId,
    String? notes,
  }) async {
    final requestKey = '$id:${stageId ?? status}';
    final inFlight = _stageUpdates[requestKey];
    if (inFlight != null) return inFlight;
    debugPrint(
      '[LeadsViewModel] updateStatus leadId: $id, status: $status, stageId: $stageId',
    );
    late final Future<LeadStatusUpdateResult?> request;
    request = () async {
      try {
        final result = await _leadService.updateStatus(
          id,
          status: status,
          stageId: stageId,
          notes: notes,
        );
        addOrUpdateLead(result.lead);
        await refreshLeads();
        return result;
      } catch (e) {
        debugPrint('[LeadsViewModel] updateStatus FAILED: $e');
        rethrow;
      } finally {
        if (identical(_stageUpdates[requestKey], request))
          _stageUpdates.remove(requestKey);
      }
    }();
    _stageUpdates[requestKey] = request;
    return request;
  }

  Future<LeadModel?> manageVisit(
    String id, {
    required String action,
    String? purpose,
    String? date,
    String? time,
    String? location,
    double? latitude,
    double? longitude,
    String? notes,
    dynamic employeeId,
  }) async {
    try {
      final updated = await _leadService.manageVisit(
        id,
        action: action,
        purpose: purpose,
        date: date,
        time: time,
        location: location,
        latitude: latitude,
        longitude: longitude,
        notes: notes,
        employeeId: employeeId,
      );
      addOrUpdateLead(updated);
      if (action == 'SCHEDULE') {
        unawaited(refreshLeads());
        ref.read(leadStagesProvider.notifier).refresh();
      } else {
        unawaited(refreshLeads());
      }
      return updated;
    } catch (e) {
      debugPrint('[LeadsViewModel] manageVisit error: $e');
      rethrow;
    }
  }

  Future<void> deleteLeads(List<String> ids) async {
    await _leadService.deleteLeads(ids);
    final remove = ids.toSet();
    if (_allLeads.isNotEmpty) {
      _allLeads = List<LeadModel>.unmodifiable(
        _allLeads.where((lead) => !remove.contains(lead.id)),
      );
      _updateCounts(_allLeads);
    }
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncValue.data(
        current.where((lead) => !remove.contains(lead.id)).toList(),
      );
    }
    await refreshLeads();
  }

  Future<LeadModel?> updateLead(String id, Map<String, dynamic> data) async {
    final updated = await _leadService.updateLead(id, data);
    addOrUpdateLead(updated);
    final stageTouched = data.containsKey('stageId') || data.containsKey('status');
    if (stageTouched) {
      unawaited(refreshLeads());
    }
    return updated;
  }

  Future<LeadModel?> createLead(Map<String, dynamic> data) async {
    try {
      final created = await _leadService.createLead(data);
      await refreshLeads();
      return created;
    } catch (e) {
      debugPrint('[LeadsViewModel] createLead error: $e');
      rethrow;
    }
  }

  bool _matchesStage(LeadModel lead) {
    if (_lastStageId != null) {
      if (lead.stageId != null) return lead.stageId == _lastStageId;
      return ref
              .read(leadStagesProvider.notifier)
              .resolveLeadStage(null, lead.status)
              ?.id ==
          _lastStageId;
    }
    if (_lastStatus == null || _lastStatus!.isEmpty) return true;
    final stage = ref
        .read(leadStagesProvider.notifier)
        .resolveLeadStage(lead.stageId, lead.status);
    return (stage?.key ?? lead.status).toUpperCase() ==
        _lastStatus!.toUpperCase();
  }

  void addOrUpdateLead(LeadModel lead) {
    if (_allLeads.isNotEmpty) {
      final allIndex = _allLeads.indexWhere((l) => l.id == lead.id);
      final updatedAll = List<LeadModel>.from(_allLeads);
      if (allIndex >= 0) {
        updatedAll[allIndex] = lead;
      } else {
        updatedAll.insert(0, lead);
      }
      _allLeads = List<LeadModel>.unmodifiable(updatedAll);
      _updateCounts(_allLeads);
    }
    final currentList = state.asData?.value;
    if (!_matchesStage(lead)) {
      if (currentList != null)
        state = AsyncValue.data(
          currentList.where((item) => item.id != lead.id).toList(),
        );
      return;
    }
    if (currentList == null) {
      state = AsyncValue.data([lead]);
      return;
    }
    final index = currentList.indexWhere((l) => l.id == lead.id);
    if (index >= 0) {
      final updatedList = List<LeadModel>.from(currentList);
      updatedList[index] = lead;
      state = AsyncValue.data(updatedList);
    } else {
      state = AsyncValue.data([lead, ...currentList]);
    }
  }

  void _updateLocalLead(LeadModel lead) {
    if (_allLeads.isNotEmpty) {
      final allIndex = _allLeads.indexWhere((l) => l.id == lead.id);
      if (allIndex >= 0) {
        final updatedAll = List<LeadModel>.from(_allLeads);
        updatedAll[allIndex] = lead;
        _allLeads = List<LeadModel>.unmodifiable(updatedAll);
        _updateCounts(_allLeads);
      }
    }
    final currentList = state.asData?.value;
    if (!_matchesStage(lead)) {
      if (currentList != null)
        state = AsyncValue.data(
          currentList.where((item) => item.id != lead.id).toList(),
        );
      return;
    }
    if (currentList == null) return;
    final index = currentList.indexWhere((l) => l.id == lead.id);
    if (index >= 0) {
      final updatedList = List<LeadModel>.from(currentList);
      updatedList[index] = lead;
      state = AsyncValue.data(updatedList);
    }
  }
}
