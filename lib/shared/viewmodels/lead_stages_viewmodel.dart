import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import '../models/lead_stage_model.dart';
import '../services/lead_service.dart';

final leadServiceProvider = Provider<LeadService>((ref) {
  return LeadService(ref.watch(apiClientProvider));
});

/// Single source of truth for all CRM lead stages in the app.
/// Fetches the authoritative configuration; failures stay visible to the UI.
final leadStagesProvider =
    AsyncNotifierProvider<LeadStagesNotifier, List<LeadStageModel>>(
      LeadStagesNotifier.new,
      retry: (retryCount, error) => null,
    );

/// Exposes only active stages sorted by sortOrder.
final activeLeadStagesProvider = Provider<List<LeadStageModel>>((ref) {
  final stagesAsync = ref.watch(leadStagesProvider);
  final stages = (stagesAsync.asData?.value ?? const <LeadStageModel>[])
      .where((stage) => stage.isActive)
      .toList();
  stages.sort((a, b) => a.sortOrder.compareTo(b.sortOrder) == 0 ? a.id.compareTo(b.id) : a.sortOrder.compareTo(b.sortOrder));
  return stages;
});

class LeadStagesNotifier extends AsyncNotifier<List<LeadStageModel>> {
  LeadService get _leadService => ref.read(leadServiceProvider);

  List<LeadStageModel> get _effectiveStages =>
      state.asData?.value ?? const <LeadStageModel>[];

  @override
  Future<List<LeadStageModel>> build() async {
    return _fetchStages();
  }

  Future<List<LeadStageModel>>? _refreshing;

  Future<List<LeadStageModel>> _fetchStages() => _leadService.getStages();

  /// Force-refresh from API. A failed refresh is shown as an error so an old stage list is not treated as current.
  Future<void> refresh() {
    final current = _refreshing;
    if (current != null) return current.then((_) {});
    final request = _fetchStages();
    _refreshing = request;
    return () async {
      state = await AsyncValue.guard(() => request);
      if (identical(_refreshing, request)) _refreshing = null;
    }();
  }

  /// Resolve a single stage by its ID or key.
  LeadStageModel? stageById(dynamic stageId) {
    if (stageId == null) return null;
    final stages = _effectiveStages;
    final strId = stageId.toString();
    try {
      return stages.firstWhere((s) => s.id.toString() == strId);
    } catch (_) {
      return null;
    }
  }

  /// Resolve a stage by its ID or fallback to its key.
  LeadStageModel? resolveLeadStage(dynamic stageId, [String? fallbackKey]) {
    final stages = _effectiveStages;
    if (stageId != null) {
      final strId = stageId.toString();
      try {
        return stages.firstWhere((s) => s.id.toString() == strId);
      } catch (_) {}
    }
    if (fallbackKey != null && fallbackKey.isNotEmpty) {
      final cleanKey = fallbackKey.trim().toUpperCase().replaceFirst(
        RegExp(r'^STAGE:\s*'),
        '',
      );

      // Check direct key match
      for (final s in stages) {
        if (s.key.toUpperCase() == cleanKey) return s;
      }

      // Check known aliases
      if (cleanKey == 'DETAILS_SENT') {
        for (final s in stages) {
          if (s.key == 'DETAILS_SEND') return s;
        }
      }
      if (cleanKey == 'VISIT') {
        for (final s in stages) {
          if (s.key == 'VISIT_SCHEDULED') return s;
        }
      }
      if (cleanKey == 'PROPOSAL') {
        for (final s in stages) {
          if (s.key == 'PROPOSAL_SENT') return s;
        }
      }
      if (cleanKey == 'CONVERTED') {
        for (final s in stages) {
          if (s.key == 'WON') return s;
        }
      }
    }
    return null;
  }

  /// Returns the 0-based index of the stage with given stageId.
  int stageIndexById(dynamic stageId) {
    if (stageId == null) return -1;
    final stages = _effectiveStages;
    final strId = stageId.toString();
    return stages.indexWhere((s) => s.id.toString() == strId);
  }

  /// Returns the next stage after current stage (by sortOrder).
  LeadStageModel? nextStage(dynamic currentStageId, [String? fallbackKey]) {
    final stages = _effectiveStages;
    if (stages.isEmpty) return null;
    final current = resolveLeadStage(currentStageId, fallbackKey);
    if (current == null) return null;
    final idx = stages.indexWhere(
      (s) => s.id == current.id || s.key == current.key,
    );
    if (idx < 0 || idx >= stages.length - 1) return null;
    return stages[idx + 1];
  }
}
