import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_status_update_result.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_communication_model.dart';
import 'package:quickboom_crm_customer/roles/customer/repositories/local_lead_repository.dart';
import 'package:quickboom_crm_customer/roles/customer/services/lead_service.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/roles/customer/services/customer_service.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/lead_limit_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/lead_stages_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_profile_viewmodel.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_stage_model.dart';

final leadServiceProvider = Provider<LeadService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return LeadService(apiClient);
});

class LeadsFilterState {
  final String? stageId;
  final String? stageKey;
  final String search;
  final bool isInitialized;

  const LeadsFilterState({
    this.stageId,
    this.stageKey,
    this.search = '',
    this.isInitialized = false,
  });

  bool get isAll =>
      (stageId == null || stageId!.isEmpty) &&
      (stageKey == null || stageKey!.isEmpty);

  LeadsFilterState copyWith({
    String? stageId,
    String? stageKey,
    String? search,
    bool clearStage = false,
    bool clearSearch = false,
    bool? isInitialized,
  }) {
    return LeadsFilterState(
      stageId: clearStage ? null : (stageId ?? this.stageId),
      stageKey: clearStage ? null : (stageKey ?? this.stageKey),
      search: clearSearch ? '' : (search ?? this.search),
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class LeadsFilterNotifier extends Notifier<LeadsFilterState> {
  static const String prefStageIdKey = 'leads_filter_selected_stage_id';
  static const String prefStageKeyKey = 'leads_filter_selected_stage_key';
  static SharedPreferences? _cachedPrefs;

  bool _disposed = false;

  static void setCachedPrefs(SharedPreferences? prefs) {
    _cachedPrefs = prefs;
  }

  @override
  LeadsFilterState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
    });

    String? initialId;
    String? initialKey;
    if (_cachedPrefs != null) {
      initialId = _cachedPrefs!.getString(prefStageIdKey);
      initialKey = _cachedPrefs!.getString(prefStageKeyKey);
    } else {
      Future.microtask(_initFromPrefs);
    }

    return LeadsFilterState(
      stageId: initialId,
      stageKey: initialKey,
      isInitialized: _cachedPrefs != null,
    );
  }

  Future<void> _initFromPrefs() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      if (_disposed) return;
      if (state.isInitialized) return;

      final savedId = prefs.getString(prefStageIdKey);
      final savedKey = prefs.getString(prefStageKeyKey);
      if (_disposed) return;

      state = state.copyWith(
        stageId: savedId,
        stageKey: savedKey,
        clearStage:
            (savedId == null || savedId.isEmpty) &&
            (savedKey == null || savedKey.isEmpty),
        isInitialized: true,
      );
    } catch (e) {
      debugPrint('[LeadsFilterNotifier] _initFromPrefs error: $e');
    }
  }

  Future<void> setStage({String? stageId, String? stageKey}) async {
    final cleanId = (stageId != null && stageId.trim().isNotEmpty)
        ? stageId.trim()
        : null;
    final cleanKey = (stageKey != null && stageKey.trim().isNotEmpty)
        ? stageKey.trim()
        : null;
    state = state.copyWith(
      stageId: cleanId,
      stageKey: cleanKey,
      clearStage: cleanId == null && cleanKey == null,
      isInitialized: true,
    );
    await _saveToPrefs(cleanId, cleanKey);
  }

  Future<void> clearStage() async {
    state = state.copyWith(clearStage: true, isInitialized: true);
    await _saveToPrefs(null, null);
  }

  void setSearch(String search) {
    state = state.copyWith(search: search.trim());
  }

  Future<void> clearFilter() async {
    state = state.copyWith(
      clearStage: true,
      clearSearch: true,
      isInitialized: true,
    );
    await _saveToPrefs(null, null);
  }

  Future<void> _saveToPrefs(String? stageId, String? stageKey) async {
    try {
      _cachedPrefs ??= await SharedPreferences.getInstance();
      if (stageId != null && stageId.isNotEmpty) {
        await _cachedPrefs?.setString(prefStageIdKey, stageId);
      } else {
        await _cachedPrefs?.remove(prefStageIdKey);
      }
      if (stageKey != null && stageKey.isNotEmpty) {
        await _cachedPrefs?.setString(prefStageKeyKey, stageKey);
      } else {
        await _cachedPrefs?.remove(prefStageKeyKey);
      }
    } catch (e) {
      debugPrint('[LeadsFilterNotifier] _saveToPrefs error: $e');
    }
  }

  /// Validates the persisted filter against configured stages from GET /leads/stages.
  /// Returns true when the in-memory/persisted filter was reset or repaired.
  bool validateAgainstStages(List<LeadStageModel> stages) {
    if (state.isAll) return false;
    if (stages.isEmpty) return false;

    LeadStageModel? byId;
    LeadStageModel? byKey;
    final savedId = state.stageId?.trim();
    final savedKey = state.stageKey?.trim();

    if (savedId != null && savedId.isNotEmpty) {
      for (final s in stages) {
        if (s.id.toString() == savedId) {
          byId = s;
          break;
        }
      }
    }
    if (savedKey != null && savedKey.isNotEmpty) {
      final keyNorm = savedKey.toUpperCase();
      for (final s in stages) {
        if (s.key.toUpperCase() == keyNorm) {
          byKey = s;
          break;
        }
      }
    }

    if (byId != null && byKey != null && byId.id != byKey.id) {
      debugPrint(
        '[LeadsFilterNotifier] Saved stageId ${state.stageId} and stageKey '
        '${state.stageKey} refer to different stages. Resetting filter to All.',
      );
      clearStage();
      return true;
    }

    final canonical = byId ?? byKey;
    if (canonical == null) {
      debugPrint(
        '[LeadsFilterNotifier] Saved stage ${state.stageKey} (${state.stageId}) '
        'no longer matches any active stage. Resetting filter to All.',
      );
      clearStage();
      return true;
    }

    if (state.stageId != canonical.id.toString() ||
        (state.stageKey ?? '').toUpperCase() != canonical.key.toUpperCase()) {
      setStage(stageId: canonical.id.toString(), stageKey: canonical.key);
      return true;
    }
    return false;
  }
}

final leadsFilterProvider =
    NotifierProvider<LeadsFilterNotifier, LeadsFilterState>(() {
      return LeadsFilterNotifier();
    });

final leadsProvider =
    NotifierProvider<LeadsViewModel, AsyncValue<List<LeadModel>>>(() {
      return LeadsViewModel();
    });

final leadCommunicationsProvider = FutureProvider.autoDispose
    .family<LeadCommunicationsResponse, String>((ref, leadId) async {
      final service = ref.watch(leadServiceProvider);
      return service.getLeadCommunications(leadId);
    });

final whatsAppTemplatesProvider =
    FutureProvider.autoDispose<List<WhatsAppTemplateModel>>((ref) async {
      final service = ref.watch(leadServiceProvider);
      return service.getWhatsAppTemplates();
    });

final leadNotesProvider = FutureProvider.autoDispose
    .family<List<LeadNoteModel>, String>((ref, leadId) async {
      final service = ref.watch(leadServiceProvider);
      return service.getNotes(leadId);
    });

class LeadsViewModel extends Notifier<AsyncValue<List<LeadModel>>> {
  LeadService get _leadService => ref.read(leadServiceProvider);
  int _currentRequestId = 0;
  Future<void>? _inFlightFetch;

  String? _activeStatus;
  String? _activeSearch;
  String? _activeStageId;

  String? get activeStatus => _activeStatus;
  String? get activeSearch => _activeSearch;
  String? get activeStageId => _activeStageId;

  @override
  AsyncValue<List<LeadModel>> build() {
    Future.microtask(() {
      if (!ref.mounted) return;
      _initAndFetch();
    });
    return const AsyncValue.loading();
  }

  Future<void> _initAndFetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;

      final savedId = prefs.getString(LeadsFilterNotifier.prefStageIdKey);
      final savedKey = prefs.getString(LeadsFilterNotifier.prefStageKeyKey);

      // Check visitor status from permissions
      if (!ref.mounted) return;
      final perms = ref.read(permissionManagerProvider);
      final role = (perms.role ?? '').toUpperCase();
      final profile = ref.read(employeeProfileProvider).asData?.value;
      final desig = (profile?.designation ?? '').toUpperCase();
      final isVisitorInit =
          role.contains('VISITOR') ||
          role.contains('FIELD_VISIT') ||
          role.contains('FIELD VISIT') ||
          desig.contains('VISITOR') ||
          desig.contains('FIELD_VISIT') ||
          desig.contains('FIELD VISIT');

      final hasSavedId = savedId != null && savedId.trim().isNotEmpty;
      final effectiveStatus = isVisitorInit
          ? 'VISIT_SCHEDULED'
          : (hasSavedId ? null : savedKey);
      final effectiveStageId = isVisitorInit ? null : savedId;

      if (!ref.mounted) return;
      await refreshLeads(status: effectiveStatus, stageId: effectiveStageId);
    } catch (_) {
      if (!ref.mounted) return;
      await refreshLeads();
    }
  }

  Future<void> fetchLeads({
    String? status,
    String? search,
    String? stageId,
  }) async {
    if (!ref.mounted) return;
    return _fetchLeadsInternal(
      status: status,
      search: search,
      stageId: stageId,
      isRefresh: true,
    );
  }

  bool _isVisitorUser() {
    String desigName = '';
    try {
      final profile = ref.read(employeeProfileProvider).asData?.value;
      desigName = (profile?.designation ?? '').trim().toUpperCase();
    } catch (_) {}
    final roleName = (ref.read(permissionManagerProvider).role ?? '')
        .trim()
        .toUpperCase();
    return desigName.contains('VISITOR') ||
        desigName.contains('FIELD VISIT') ||
        desigName.contains('FIELD_VISIT') ||
        desigName == 'VISIT' ||
        roleName.contains('VISITOR') ||
        roleName.contains('FIELD VISIT') ||
        roleName.contains('FIELD_VISIT') ||
        roleName == 'VISIT';
  }

  /// Resolves GET /leads params. All = no stage query. A specific stage sends
  /// only configured stageId. Status is used only when stageId is missing
  /// (or for Visitor Visit Scheduled). Never merge a previous _active* stage
  /// after the user switched to All.
  void _resolveLeadQuery({
    required String? status,
    required String? search,
    required String? stageId,
    required void Function(String? status, String? search, String? stageId)
    emit,
  }) {
    final filter = ref.read(leadsFilterProvider);
    final resolvedSearch = search ?? filter.search;

    if (_isVisitorUser()) {
      emit('VISIT_SCHEDULED', resolvedSearch, null);
      return;
    }

    final explicitId = (stageId != null && stageId.trim().isNotEmpty)
        ? stageId.trim()
        : null;
    final filterId =
        !filter.isAll &&
            filter.stageId != null &&
            filter.stageId!.trim().isNotEmpty
        ? filter.stageId!.trim()
        : null;
    final resolvedId = explicitId ?? filterId;

    if (resolvedId != null) {
      emit(null, resolvedSearch, resolvedId);
      return;
    }

    final explicitStatus = (status != null && status.trim().isNotEmpty)
        ? status.trim()
        : null;
    final filterStatus =
        !filter.isAll &&
            filter.stageKey != null &&
            filter.stageKey!.trim().isNotEmpty
        ? filter.stageKey!.trim()
        : null;
    emit(explicitStatus ?? filterStatus, resolvedSearch, null);
  }

  Future<void> refreshLeads({
    String? status,
    String? search,
    String? stageId,
  }) async {
    if (!ref.mounted) return;
    String? resolvedStatus;
    String? resolvedSearch;
    String? resolvedStageId;
    _resolveLeadQuery(
      status: status,
      search: search,
      stageId: stageId,
      emit: (s, q, id) {
        resolvedStatus = s;
        resolvedSearch = q;
        resolvedStageId = id;
      },
    );
    return fetchLeads(
      status: resolvedStatus,
      search: resolvedSearch,
      stageId: resolvedStageId,
    );
  }

  Future<void> refreshCurrentList() async {
    if (!ref.mounted) return;
    return refreshLeads();
  }

  Future<void> _fetchLeadsInternal({
    String? status,
    String? search,
    String? stageId,
    bool isRefresh = false,
  }) async {
    if (!ref.mounted) return;
    // Coalesce only duplicate unfiltered loads that are already in flight.
    // Screen open / resume / pull-to-refresh must use isRefresh so a prior
    // in-flight call (including a permissions-abort) cannot skip a new GET.
    if (_inFlightFetch != null &&
        status == null &&
        search == null &&
        stageId == null &&
        !isRefresh &&
        state.hasValue) {
      await _inFlightFetch;
      return;
    }

    final future = _doFetch(
      status: status,
      search: search,
      stageId: stageId,
      isRefresh: isRefresh,
    );
    _inFlightFetch = future;
    try {
      await future;
      // If a newer fetch started while this one ran, wait for it so callers
      // (and tests) observe the latest GET result instead of a discarded load.
      var latest = _inFlightFetch;
      while (latest != null && latest != future) {
        await latest;
        if (_inFlightFetch == latest) break;
        latest = _inFlightFetch;
      }
    } finally {
      if (_inFlightFetch == future) {
        _inFlightFetch = null;
      }
    }
  }

  Future<void> _doFetch({
    String? status,
    String? search,
    String? stageId,
    required bool isRefresh,
  }) async {
    if (!ref.mounted) return;
    final requestId = ++_currentRequestId;

    // The authenticated API enforces RBAC. Do not abandon a request in a
    // loading state while the independent permissions provider initializes.

    final isVisitor = _isVisitorUser();

    if (!isRefresh || !state.hasValue) {
      state = const AsyncValue.loading();
    }

    try {
      final localLeads = await _leadService.getLeads(
        status: status,
        search: search,
        stageId: stageId,
      );

      if (!ref.mounted || requestId != _currentRequestId) {
        return;
      }

      _activeStatus = status;
      _activeSearch = search;
      _activeStageId = stageId;

      final effectiveLeads = isVisitor
          ? localLeads.where((l) => _isLeadInVisitScheduledStage(l)).toList()
          : localLeads;

      effectiveLeads.sort((a, b) => a.compareCreatedAtDesc(b));

      state = AsyncValue.data(effectiveLeads);
    } catch (e, st) {
      if (!ref.mounted || requestId != _currentRequestId) {
        return;
      }
      debugPrint('[LEADS_VIEWMODEL] fetchLeads error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  int? get totalCount => _leadService.lastTotalCount;

  Future<LeadModel?> createLead(Map<String, dynamic> leadData) async {
    try {
      final created = await _leadService.createLead(leadData);
      ref.invalidate(leadLimitProvider);
      ref.invalidate(leadStagesProvider);
      await refreshCurrentList();
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<LeadModel?> updateLead(
    String id,
    Map<String, dynamic> leadData,
  ) async {
    try {
      final updated = await _leadService.updateLead(id, leadData);
      _updateLocalLead(updated);
      ref.invalidate(leadCommunicationsProvider(id));
      return updated;
    } catch (e) {
      debugPrint('[LEADS_VIEWMODEL] updateLead error: $e');
      rethrow;
    }
  }

  Future<DuplicateCheckResult> checkDuplicate({
    String? phone,
    String? companyName,
    String? website,
    String? googlePlaceId,
  }) async {
    return _leadService.checkDuplicate(
      phone: phone,
      companyName: companyName,
      website: website,
      googlePlaceId: googlePlaceId,
    );
  }

  Future<LeadModel?> getLeadDetails(String id) async {
    try {
      final lead = await _leadService.getLeadById(id);
      _updateLocalLead(lead);
      return lead;
    } catch (e) {
      debugPrint('[LEADS_VIEWMODEL] getLeadDetails error: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('not found') || errStr.contains('404')) {
        removeLocalLead(id);
      }
      return null;
    }
  }

  Future<LeadModel?> logFollowUp(
    String id, {
    required String outcome,
    String? notes,
    String? nextFollowUpDate,
    String? nextFollowUpTime,
  }) async {
    try {
      final updated = await _leadService.logFollowUp(
        id,
        outcome: outcome,
        notes: notes,
        nextFollowUpDate: nextFollowUpDate,
        nextFollowUpTime: nextFollowUpTime,
      );
      _updateLocalLead(updated);
      ref.invalidate(customersDirectoryProvider);
      ref.invalidate(customersListProvider);
      return updated;
    } catch (e) {
      return null;
    }
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
    String? summary,
    String? customerResponse,
    String? notes,
    dynamic employeeId,
  }) async {
    final updated = await _leadService.manageVisit(
      id,
      action: action,
      purpose: purpose,
      date: date,
      time: time,
      location: location,
      latitude: latitude,
      longitude: longitude,
      summary: summary,
      customerResponse: customerResponse,
      notes: notes,
      employeeId: employeeId,
    );
    _updateLocalLead(updated);
    ref.invalidate(customersDirectoryProvider);
      ref.invalidate(customersListProvider);
    return updated;
  }

  Future<LeadModel?> createProposal(
    String id, {
    String? proposalNo,
    List<Map<String, dynamic>>? items,
    required double subTotal,
    required double taxAmount,
    double discount = 0.0,
    required double totalAmount,
    String? validUntil,
    String? notes,
  }) async {
    try {
      final updated = await _leadService.createProposal(
        id,
        proposalNo: proposalNo,
        items: items,
        subTotal: subTotal,
        taxAmount: taxAmount,
        discount: discount,
        totalAmount: totalAmount,
        validUntil: validUntil,
        notes: notes,
      );
      _updateLocalLead(updated);
      ref.invalidate(customersDirectoryProvider);
      ref.invalidate(customersListProvider);
      return updated;
    } catch (e) {
      return null;
    }
  }

  Future<LeadModel?> recordFinalCall(
    String id, {
    double? proposalAmount,
    required String customerResponse,
    String? negotiationNotes,
    String? expectedClosingDate,
    String? nextAction,
  }) async {
    try {
      final updated = await _leadService.recordFinalCall(
        id,
        proposalAmount: proposalAmount,
        customerResponse: customerResponse,
        negotiationNotes: negotiationNotes,
        expectedClosingDate: expectedClosingDate,
        nextAction: nextAction,
      );
      _updateLocalLead(updated);
      ref.invalidate(customersDirectoryProvider);
      ref.invalidate(customersListProvider);
      return updated;
    } catch (e) {
      return null;
    }
  }

  Future<LeadModel?> recordPayment(
    String id, {
    required double totalAmount,
    required double paidAmount,
    double pendingAmount = 0.0,
    required String paymentMethod,
    String? paymentDate,
    String? transactionRef,
    required String status,
    String? notes,
  }) async {
    try {
      final updated = await _leadService.recordPayment(
        id,
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        pendingAmount: pendingAmount,
        paymentMethod: paymentMethod,
        paymentDate: paymentDate,
        transactionRef: transactionRef,
        status: status,
        notes: notes,
      );
      _updateLocalLead(updated);
      ref.invalidate(customersDirectoryProvider);
      ref.invalidate(customersListProvider);
      return updated;
    } catch (e) {
      return null;
    }
  }

  Future<LeadModel?> startWork(
    String id, {
    required String workStartDate,
    String? assignedTeam,
    String? serviceName,
    String? notes,
  }) async {
    try {
      final updated = await _leadService.startWork(
        id,
        workStartDate: workStartDate,
        assignedTeam: assignedTeam,
        serviceName: serviceName,
        notes: notes,
      );
      _updateLocalLead(updated);
      ref.invalidate(customersDirectoryProvider);
      ref.invalidate(customersListProvider);
      return updated;
    } catch (e) {
      return null;
    }
  }

  /// Update lead stage in local store with immediate Riverpod synchronization
  Future<LeadStatusUpdateResult?> updateStatus(
    String id, {
    required String status,
    int? stageId,
    String? notes,
  }) async {
    try {
      final result = await _leadService.updateStatus(
        id,
        status: status,
        stageId: stageId,
        notes: notes,
      );

      _updateLocalLead(result.lead);
      ref.invalidate(leadCommunicationsProvider(id));
      ref.invalidate(customersDirectoryProvider);
      ref.invalidate(customersListProvider);
      ref.invalidate(leadStagesProvider);
      return result;
    } catch (e) {
      debugPrint('[LEADS_VIEWMODEL] updateStatus error: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('not found') || errStr.contains('404')) {
        removeLocalLead(id);
      }
      rethrow;
    }
  }

  /// Evict a deleted or non-existent lead from local state and synchronize all providers
  void removeLocalLead(String id) {
    final normId = id.trim().toLowerCase();
    state.whenData((currentList) {
      final newList = currentList
          .where((l) => l.id.trim().toLowerCase() != normId)
          .toList();
      state = AsyncValue.data(newList);
    });
    LocalLeadRepository.instance.removeLead(id);
    ref.invalidate(leadCommunicationsProvider(id));
    ref.invalidate(leadNotesProvider(id));
    ref.invalidate(customersDirectoryProvider);
      ref.invalidate(customersListProvider);
    ref.invalidate(leadLimitProvider);
    ref.invalidate(leadStagesProvider);
  }

  Future<bool> addNote(String id, String content) async {
    try {
      await _leadService.addNote(id, content);
      ref.invalidate(leadNotesProvider(id));
      await getLeadDetails(id);
      return true;
    } catch (e) {
      debugPrint('[LEADS_VIEWMODEL] addNote error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> sendLeadEmail(
    String leadId, {
    String? subject,
    String? message,
  }) async {
    final res = await _leadService.sendLeadEmail(
      leadId,
      subject: subject,
      message: message,
    );
    ref.invalidate(leadCommunicationsProvider(leadId));
    return res;
  }

  Future<Map<String, dynamic>> sendLeadWhatsApp(
    String leadId, {
    String? message,
    String? templateName,
    String? stageName,
  }) async {
    final res = await _leadService.sendLeadWhatsApp(
      leadId,
      message: message,
      templateName: templateName,
      stageName: stageName,
    );
    ref.invalidate(leadCommunicationsProvider(leadId));
    return res;
  }

  Future<bool> deleteLead(String id) async {
    try {
      final success = await _leadService.deleteLead(id);
      if (success) {
        state.whenData((currentList) {
          final newList = currentList.where((l) => l.id != id).toList();
          state = AsyncValue.data(newList);
        });
        ref.invalidate(leadCommunicationsProvider(id));
        ref.invalidate(leadNotesProvider(id));
        ref.invalidate(customersDirectoryProvider);
      ref.invalidate(customersListProvider);
        ref.invalidate(leadLimitProvider);
        ref.invalidate(leadStagesProvider);
      }
      return success;
    } catch (e) {
      debugPrint('[LEADS_VIEWMODEL] deleteLead error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> bulkDeleteLeads(List<String> ids) async {
    try {
      final numericIds = ids
          .map((id) => int.tryParse(id))
          .whereType<int>()
          .where((n) => n > 0)
          .toList();

      final result = await _leadService.bulkDeleteLeads(numericIds);

      state.whenData((currentList) {
        final remaining = currentList
            .where((l) => !ids.contains(l.id))
            .toList();
        state = AsyncValue.data(remaining);
      });

      for (final id in ids) {
        ref.invalidate(leadCommunicationsProvider(id));
        ref.invalidate(leadNotesProvider(id));
      }
      ref.invalidate(customersDirectoryProvider);
      ref.invalidate(customersListProvider);
      ref.invalidate(leadLimitProvider);
      ref.invalidate(leadStagesProvider);

      return result;
    } catch (e) {
      debugPrint('[LEADS_VIEWMODEL] bulkDeleteLeads error: $e');
      rethrow;
    }
  }

  void refreshLeadCommunications(String leadId) {
    ref.invalidate(leadCommunicationsProvider(leadId));
  }

  void addOrUpdateLead(LeadModel lead) {
    _updateLocalLead(lead);
    ref.invalidate(leadLimitProvider);
    ref.invalidate(leadStagesProvider);
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

    // Direct status / stage string match
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

    // Cross-reference with the stages list (by numeric id or key)
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

  void _updateLocalLead(LeadModel updated) {
    LocalLeadRepository.instance.upsertLead(updated);
    state.whenData((currentList) {
      final profile = ref.read(employeeProfileProvider).asData?.value;
      final permsState = ref.read(permissionManagerProvider);
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

      final index = currentList.indexWhere((l) => l.id == updated.id);

      if (isVisitor) {
        final isVisitScheduled = _isLeadInVisitScheduledStage(updated);
        final newList = List<LeadModel>.from(currentList);
        if (isVisitScheduled) {
          if (index != -1) {
            newList.removeAt(index);
          }
          newList.insert(0, updated);
          newList.sort((a, b) => a.compareCreatedAtDesc(b));
        } else {
          // If stage moved away from Visit Scheduled, remove immediately from Visitor pipeline
          if (index != -1) {
            newList.removeAt(index);
          }
        }
        state = AsyncValue.data(newList);
        return;
      }

      // Non-visitor employee:
      final newList = List<LeadModel>.from(currentList);
      if (index != -1) {
        newList.removeAt(index);
      }

      bool matchesFilter = true;
      if (_activeStageId != null || _activeStatus != null) {
        final stagesNotifier = ref.read(leadStagesProvider.notifier);
        final currentStage = stagesNotifier.resolveLeadStage(
          _activeStageId,
          _activeStatus,
        );
        if (currentStage != null) {
          matchesFilter = stagesNotifier.leadMatchesStage(
            updated,
            currentStage,
          );
        } else {
          if (_activeStatus != null &&
              updated.status.toUpperCase() != _activeStatus!.toUpperCase()) {
            matchesFilter = false;
          }
        }
      }

      if (matchesFilter) {
        newList.insert(0, updated);
      }
      newList.sort((a, b) => a.compareCreatedAtDesc(b));
      state = AsyncValue.data(newList);
    });
  }
}
