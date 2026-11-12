import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_stage_model.dart';
import 'package:quickboom_crm_customer/roles/customer/services/lead_service.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/leads_viewmodel.dart';

/// Single source of truth for all lead stages in the app.
///
/// Loads from GET /leads/stages and caches for the session.
/// All stage UI (dropdowns, pipeline, kanban, details) must watch this provider.
///
/// STRICTLY PROHIBITED in UI code:
///   - Hardcoded stage names
///   - Hardcoded stage arrays
///   - Hardcoded stage colors
///   - switch(status) for stage display
///
/// CORRECT USAGE:
///   final stagesAsync = ref.watch(leadStagesProvider);
///   stagesAsync.when(data: (stages) => ..., loading: ..., error: ...)
final leadStagesProvider =
    AsyncNotifierProvider<LeadStagesNotifier, List<LeadStageModel>>(
      LeadStagesNotifier.new,
    );

/// Exposes only active stages (for dropdowns, new-lead creation).
final activeLeadStagesProvider = Provider<List<LeadStageModel>>((ref) {
  final stagesAsync = ref.watch(leadStagesProvider);
  final stages = stagesAsync.asData?.value.where((s) => s.isActive).toList() ?? [];
  stages.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return stages;
});

class LeadStagesNotifier extends AsyncNotifier<List<LeadStageModel>> {
  LeadService get _leadService => ref.read(leadServiceProvider);

  @override
  Future<List<LeadStageModel>> build() async {
    return _fetchStages();
  }

  Future<List<LeadStageModel>> _fetchStages() async {
    try {
      final rawList = await _leadService.getStages();
      final stages =
          rawList.map((item) => LeadStageModel.fromJson(item)).toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return stages;
    } catch (e) {
      debugPrint('[LeadStagesNotifier] Failed to load stages: $e');
      rethrow;
    }
  }

  /// Force-refresh from API (call after admin creates/edits/reorders a stage).
  Future<void> refresh() async {
    final previous = state.asData?.value;
    try {
      final fresh = await _fetchStages();
      state = AsyncValue.data(fresh);
    } catch (e, st) {
      if (previous != null && previous.isNotEmpty) {
        state = AsyncValue.data(previous);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Resolve a single stage by its ID string, or fallback to matching by key.
  /// Returns null if stages not loaded or ID/key not found.
  LeadStageModel? stageById(String? stageId) {
    if (stageId == null || stageId.isEmpty) return null;
    final stages = state.asData?.value;
    if (stages == null) return null;
    try {
      return stages.firstWhere((s) => s.id.toString() == stageId);
    } catch (_) {
      return null;
    }
  }

  /// Resolve a stage by ID, key, status, or display name using configured stages.
  LeadStageModel? resolveLeadStage(
    String? stageId, [
    String? fallbackKey,
    String? fallbackName,
  ]) {
    final stages = state.asData?.value;
    if (stages == null) return null;
    return LeadStageModel.resolve(
      stages: stages,
      stageId: stageId,
      status: fallbackKey,
      stageName: fallbackName,
    );
  }

  bool leadMatchesStage(LeadModel lead, LeadStageModel stage) {
    final resolved = resolveLeadStage(
      lead.stageId,
      lead.status,
      lead.stageNameConfig,
    );
    return resolved != null && resolved.id == stage.id;
  }

  /// Returns the index (0-based) of the stage with the given stageId,
  /// among the active stages sorted by sortOrder.
  int stageIndexById(String? stageId) {
    if (stageId == null) return -1;
    final stages = state.asData?.value;
    if (stages == null) return -1;
    final idx = stages.indexWhere((s) => s.id.toString() == stageId);
    return idx;
  }

  /// Returns the next stage after the given stage (by sortOrder).
  /// Returns null if this is the last stage.
  LeadStageModel? nextStage(String? currentStageId, [String? fallbackKey]) {
    final stages = state.asData?.value;
    if (stages == null || stages.isEmpty) return null;
    final current = resolveLeadStage(currentStageId, fallbackKey);
    if (current == null) return null;
    final idx = stages.indexWhere((s) => s.id == current.id);
    if (idx < 0 || idx >= stages.length - 1) return null;
    return stages[idx + 1];
  }
}
