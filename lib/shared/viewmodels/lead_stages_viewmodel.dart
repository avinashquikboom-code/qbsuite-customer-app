import 'package:flutter/foundation.dart';
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
  ref.watch(leadStagesProvider);
  return ref.read(leadStagesProvider.notifier).activePipelineStages;
});

class LeadStagesNotifier extends AsyncNotifier<List<LeadStageModel>> {
  LeadService get _leadService => ref.read(leadServiceProvider);

  List<LeadStageModel> get _effectiveStages =>
      state.asData?.value ?? const <LeadStageModel>[];

  List<LeadStageModel> get activePipelineStages {
    final stages = _effectiveStages.where((stage) => stage.isActive).toList();
    stages.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder == 0 ? a.id.compareTo(b.id) : byOrder;
    });
    return stages;
  }

  Future<List<LeadStageModel>>? _refreshing;

  @override
  Future<List<LeadStageModel>> build() async {
    return _fetchStages();
  }

  Future<List<LeadStageModel>> _fetchStages() => _leadService.getStages();

  /// Refresh stages without dropping cached data or entering a perpetual loading state.
  Future<void> refresh() async {
    final inFlight = _refreshing;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final previous = state.asData?.value ?? const <LeadStageModel>[];
    final request = _fetchStages();
    _refreshing = request;

    try {
      final fresh = await request;
      if (!ref.mounted) return;
      state = AsyncValue.data(fresh);
    } catch (e, st) {
      debugPrint('[LeadStagesNotifier] refresh failed: $e');
      if (!ref.mounted) return;
      if (previous.isNotEmpty) {
        state = AsyncValue.data(previous);
      } else {
        state = AsyncValue.error(e, st);
      }
    } finally {
      if (identical(_refreshing, request)) {
        _refreshing = null;
      }
    }
  }

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

      for (final s in stages) {
        if (s.key.toUpperCase() == cleanKey) return s;
      }

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

  int stageIndexInPipeline(dynamic stageId) {
    if (stageId == null) return -1;
    final strId = stageId.toString();
    return activePipelineStages.indexWhere((s) => s.id.toString() == strId);
  }

  int stageIndexById(dynamic stageId) => stageIndexInPipeline(stageId);

  /// Next stage in the active pipeline (sortOrder), not alphabetically.
  LeadStageModel? nextStage(dynamic currentStageId, [String? fallbackKey]) {
    final stages = activePipelineStages;
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
