import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_stage_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_communication_model.dart';
import 'package:quickboom_crm_customer/roles/customer/services/lead_service.dart'
    show DuplicateCheckResult;
import 'package:quickboom_crm_customer/shared/models/data_capture_model.dart';

/// Local in-memory repository for CRM Leads.
///
/// Provides a self-contained, frontend-only data layer for:
/// - Lead Pipeline (all stages, search, filters, drag-and-drop / stage update)
/// - Lead Details (complete business details, contact info, images, timeline, notes)
/// - Data Capture import (single 'Add Lead' & bulk 'Import Selected Leads')
///
/// Zero backend HTTP/API requests are made.
class LocalLeadRepository {
  static final LocalLeadRepository instance = LocalLeadRepository._internal();

  LocalLeadRepository._internal() {
    _leads = _initInitialLeads();
  }

  late List<LeadModel> _leads;

  /// Unmodifiable view of currently cached local leads
  List<LeadModel> get allLeads => List<LeadModel>.unmodifiable(_leads);

  /// Authoritative lead stages fetched from backend GET /leads/stages
  List<LeadStageModel> _configuredStages = [];

  /// Stages last received from Stage Management. No local catalog is substituted.
  List<LeadStageModel> get currentStages => _configuredStages;

  LeadStageModel? _matchStage(List<String> keys) {
    final wanted = keys.map((key) => key.toUpperCase()).toSet();
    for (final stage in currentStages) {
      if (wanted.contains(stage.key.toUpperCase())) return stage;
    }
    return null;
  }

  /// Updates local repository with authoritative stages from backend
  void setConfiguredStages(List<Map<String, dynamic>> rawStages) {
    try {
      final parsed = rawStages
          .map((json) => LeadStageModel.fromJson(json))
          .toList();
      if (parsed.isNotEmpty) {
        _configuredStages = parsed;
      }
    } catch (_) {}
  }

  /// Replace cached leads with the authoritative server list.
  /// Successful GET /leads is the source of truth — do not keep extra local rows
  /// (deleted-on-another-device, dummy seed leads, or stale stage copies).
  void replaceLeads(List<LeadModel> leads) {
    _leads = List<LeadModel>.from(leads);
  }

  /// Remove a specific lead from local cache (e.g. upon backend 404 or deletion)
  bool removeLead(String id) {
    final normId = id.trim().toLowerCase();
    final initialLen = _leads.length;
    _leads.removeWhere((l) => l.id.trim().toLowerCase() == normId);
    return _leads.length < initialLen;
  }

  void clearCache() {
    _leads = _initInitialLeads();
  }

  int get totalCount => _leads.length;

  /// Returns stages with dynamically calculated [leadsCount] matching [_leads].
  Future<List<Map<String, dynamic>>> getStages() async {
    final stages = currentStages;
    return stages.map((stage) {
      final count = _leads.where((l) {
        if (l.stageId != null && l.stageId == stage.id.toString()) return true;
        return l.status.trim().toUpperCase() == stage.key.trim().toUpperCase();
      }).length;

      return {
        'id': stage.id,
        'key': stage.key,
        'name': stage.name,
        'sortOrder': stage.sortOrder,
        'isActive': stage.isActive,
        'isSystem': stage.isSystem,
        'color': stage.color,
        'bgColor': stage.bgColor,
        'borderColor': stage.borderColor,
        'leadsCount': count,
      };
    }).toList();
  }

  /// Get filtered leads list based on status/stage and search query.
  ///
  /// When filtering by stageId, uses the same triple-fallback matching logic
  /// as the pipeline count (countInLoaded in leads_view.dart):
  ///   1. l.stageId == stageId (numeric string match)
  ///   2. l.stageId == stageKey (stage key string match, e.g. VISIT_SCHEDULED)
  ///   3. l.status == stageKey / stageName (status field match, normalized)
  ///   4. l.stageNameConfig == stageName / stageKey (stage name match, normalized)
  ///   5. Special handling for Visit Scheduled stage matching
  /// This ensures the list and count always use the same semantics.
  Future<List<LeadModel>> getLeads({
    String? status,
    String? search,
    String? stageId,
  }) async {
    Iterable<LeadModel> result = _leads;

    String norm(String? s) =>
        (s ?? '').trim().toUpperCase().replaceAll(RegExp(r'[\s_\-]+'), '');

    final normStageId = (stageId ?? '').trim();
    final normStatusKey = (status ?? '').trim().toUpperCase();
    final cleanStatusKey = norm(normStatusKey);

    final stagesPool = currentStages;

    // Match by key or name first to prevent numeric ID collisions across tenants
    LeadStageModel? matchedStage;
    if (cleanStatusKey.isNotEmpty) {
      matchedStage = stagesPool.cast<LeadStageModel?>().firstWhere(
        (s) =>
            s != null &&
            (norm(s.key) == cleanStatusKey || norm(s.name) == cleanStatusKey),
        orElse: () => null,
      );
    }
    if (matchedStage == null && normStageId.isNotEmpty) {
      matchedStage = stagesPool.cast<LeadStageModel?>().firstWhere(
        (s) => s != null && s.id.toString() == normStageId,
        orElse: () => null,
      );
    }

    bool leadMatchesFilter(LeadModel l) {
      final resolved = LeadStageModel.resolve(
        stages: stagesPool,
        stageId: l.stageId,
        status: l.status,
        stageName: l.stageNameConfig,
      );
      final filterStage = matchedStage;
      if (filterStage != null) {
        return resolved != null && resolved.id == filterStage.id;
      }
      if (normStageId.isNotEmpty && normStageId.toUpperCase() != 'ALL') {
        if (resolved != null) return resolved.id.toString() == normStageId;
        return (l.stageId ?? '').trim() == normStageId;
      }
      if (cleanStatusKey.isNotEmpty) {
        if (resolved != null) {
          return LeadStageModel.normalizeToken(resolved.key) ==
                  cleanStatusKey ||
              LeadStageModel.normalizeToken(resolved.name) == cleanStatusKey;
        }
        return LeadStageModel.normalizeToken(l.status) == cleanStatusKey;
      }
      return true;
    }

    if (matchedStage != null ||
        (stageId != null && stageId.trim().isNotEmpty && stageId != 'ALL') ||
        (status != null && status.trim().isNotEmpty && status != 'ALL')) {
      result = result.where(leadMatchesFilter);
    }

    if (search != null && search.trim().isNotEmpty) {
      final query = search.trim().toLowerCase();
      result = result.where((l) {
        final bName = (l.businessName ?? '').toLowerCase();
        final cName = (l.companyName ?? '').toLowerCase();
        final title = l.title.toLowerCase();
        final phone = (l.phone ?? '').toLowerCase();
        final email = (l.email ?? '').toLowerCase();
        final city = (l.city ?? '').toLowerCase();
        return bName.contains(query) ||
            cName.contains(query) ||
            title.contains(query) ||
            phone.contains(query) ||
            email.contains(query) ||
            city.contains(query);
      });
    }

    final list = result.toList();
    list.sort((a, b) => a.compareCreatedAtDesc(b));
    return list;
  }

  /// Safe local cache lookup by lead ID
  LeadModel? findLeadLocally(String id) {
    final normId = id.trim().toLowerCase();
    return _leads.cast<LeadModel?>().firstWhere(
      (l) => l?.id.trim().toLowerCase() == normId,
      orElse: () => null,
    );
  }

  /// Upsert a single lead into the local cache, preventing duplicates
  void upsertLead(LeadModel lead) {
    final normId = lead.id.trim().toLowerCase();
    final index = _leads.indexWhere((l) => l.id.trim().toLowerCase() == normId);
    if (index != -1) {
      _leads.removeAt(index);
    }
    _leads.insert(0, lead);
    _leads.sort((a, b) => a.compareCreatedAtDesc(b));
  }

  /// Upsert multiple leads into the local cache
  void upsertLeads(List<LeadModel> leads) {
    for (final lead in leads) {
      upsertLead(lead);
    }
  }

  /// Find single lead by ID
  Future<LeadModel> getLeadById(String id) async {
    final normId = id.trim();
    final lead = findLeadLocally(normId);
    debugPrint(
      '[LEAD_REPOSITORY] cacheLookup id=$normId cacheFound=${lead != null}',
    );
    if (lead != null) return lead;
    throw Exception('Lead with ID $id not found in local repository.');
  }

  /// Create a new Lead locally from payload
  Future<LeadModel> createLead(Map<String, dynamic> data) async {
    final targetName =
        data['businessName'] ??
        data['companyName'] ??
        data['title'] ??
        data['name'] ??
        'New Business Lead';

    final resolvedStageKey = (data['status']?.toString() ?? '').toUpperCase();
    final matchedStage = _matchStage([resolvedStageKey]);

    final id =
        'lead_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';
    final nowIso = DateTime.now().toIso8601String();

    final lead = LeadModel(
      id: id,
      stageId: (data['stageId'] ?? matchedStage?.id ?? '').toString(),
      stageNameConfig: matchedStage?.name ?? data['status']?.toString(),
      stageColorHex: matchedStage?.color,
      title: targetName.toString(),
      businessName: targetName.toString(),
      companyName: targetName.toString(),
      firstName: data['firstName']?.toString() ?? '',
      lastName: data['lastName']?.toString() ?? '',
      phone: data['phone']?.toString(),
      email: data['email']?.toString(),
      website: data['website']?.toString(),
      address: data['address']?.toString(),
      city: data['city']?.toString() ?? 'Vadodara',
      state: data['state']?.toString() ?? 'Gujarat',
      pincode: data['pincode']?.toString(),
      country: data['country']?.toString() ?? 'India',
      category: data['category']?.toString(),
      source: data['source']?.toString() ?? 'MANUAL',
      status: matchedStage?.key ?? data['status']?.toString() ?? '',
      priority: data['priority']?.toString() ?? 'MEDIUM',
      value: (data['value'] as num?)?.toDouble() ?? 0.0,
      createdAt: nowIso,
      rating: (data['rating'] as num?)?.toDouble(),
      reviewCount: (data['reviewCount'] as num?)?.toInt(),
      googlePlaceId: data['googlePlaceId']?.toString(),
      sourceRecordId: data['sourceRecordId']?.toString(),
      captureRequestId: data['captureRequestId']?.toString(),
      socialMedia: data['socialMedia'] is Map
          ? LeadSocialMediaModel.fromJson(
              Map<String, dynamic>.from(data['socialMedia'] as Map),
            )
          : null,
      timeline: [
        LeadTimelineItemModel(
          id: 'tl_init_$id',
          leadId: id,
          action: 'CREATE',
          description: 'Lead created via mobile application.',
          createdAt: nowIso,
        ),
      ],
    );

    _leads.insert(0, lead);
    return lead;
  }

  /// Directly add a prepared [LeadModel] to the local store
  void addLead(LeadModel lead) {
    _leads.removeWhere((l) => l.id == lead.id);
    _leads.insert(0, lead);
  }

  /// Bulk import businesses from Data Capture
  ImportResultSummary importFromCapturedPlaces(
    List<CapturedBusiness> places,
    String jobId,
  ) {
    int importedCount = 0;
    int skippedCount = 0;
    final List<String> duplicateNames = [];
    final List<ImportedRecordResult> recordResults = [];

    for (var i = 0; i < places.length; i++) {
      final p = places[i];
      final targetName = p.businessName.trim().isNotEmpty
          ? p.businessName.trim()
          : 'Lead ${i + 1}';

      // Check if duplicate already exists by place ID or phone
      final isDup = _leads.any(
        (l) =>
            (p.googlePlaceId.isNotEmpty &&
                l.googlePlaceId == p.googlePlaceId) ||
            (p.phone.isNotEmpty &&
                p.phone != 'N/A' &&
                l.phone != null &&
                l.phone!.replaceAll(RegExp(r'\D'), '') ==
                    p.phone.replaceAll(RegExp(r'\D'), '')),
      );

      if (isDup) {
        skippedCount++;
        duplicateNames.add(targetName);
        recordResults.add(
          ImportedRecordResult(
            sourceRecordId: p.sourceRecordId ?? p.googlePlaceId,
            googlePlaceId: p.googlePlaceId,
            businessName: targetName,
            imported: false,
            duplicate: true,
            duplicateMatchReason: 'Lead already exists in CRM',
          ),
        );
        continue;
      }

      final numericId = DateTime.now().millisecondsSinceEpoch + i;
      final leadId = numericId.toString();
      final nowIso = DateTime.now().toIso8601String();
      final resolvedSource =
          p.source ??
          (p.googlePlaceId.isNotEmpty ? 'GOOGLE_PLACES' : 'GOOGLE_DISCOVERY');

      final List<LeadImageModel> leadImages = [];
      if (p.photos != null && p.photos!.isNotEmpty) {
        for (var imgIdx = 0; imgIdx < p.photos!.length; imgIdx++) {
          leadImages.add(
            LeadImageModel(
              id: 'img_${leadId}_$imgIdx',
              leadId: leadId,
              url: p.photos![imgIdx],
              caption: imgIdx == 0
                  ? '$targetName (Primary)'
                  : '$targetName Photo ${imgIdx + 1}',
              isPrimary: imgIdx == 0,
              createdAt: nowIso,
            ),
          );
        }
      }

      final newLead = LeadModel(
        id: leadId,
        stageId: '1',
        stageNameConfig: 'New',
        stageColorHex: '#0284C7',
        title: targetName,
        businessName: targetName,
        companyName: targetName,
        firstName: '',
        lastName: '',
        phone: p.phone != 'N/A' && p.phone.trim().isNotEmpty
            ? p.phone.trim()
            : null,
        email: p.email != null && p.email!.trim().isNotEmpty
            ? p.email!.trim()
            : null,
        website: p.website != null && p.website!.trim().isNotEmpty
            ? p.website!.trim()
            : null,
        address: p.address.trim().isNotEmpty ? p.address.trim() : null,
        city: _extractCity(p.address),
        state: 'Gujarat',
        country: 'India',
        category: p.category.isNotEmpty ? p.category : null,
        source: resolvedSource,
        status: 'NEW',
        priority: (p.rating != null && p.rating! >= 4.5) ? 'HIGH' : 'MEDIUM',
        value: 0.0,
        createdAt: nowIso,
        images: leadImages,
        rating: p.rating,
        reviewCount: p.reviewCount,
        googlePlaceId: p.googlePlaceId.isNotEmpty ? p.googlePlaceId : null,
        sourceRecordId:
            p.sourceRecordId ??
            (p.googlePlaceId.isNotEmpty ? p.googlePlaceId : null),
        captureRequestId: jobId,
        socialMedia: p.socialMedia != null
            ? LeadSocialMediaModel.fromJson(p.socialMedia!)
            : null,
        timeline: [
          LeadTimelineItemModel(
            id: 'tl_import_$leadId',
            leadId: leadId,
            action: 'IMPORT',
            description: 'Imported from Data Capture ($resolvedSource)',
            createdAt: nowIso,
          ),
        ],
      );

      _leads.insert(0, newLead);
      importedCount++;
      recordResults.add(
        ImportedRecordResult(
          leadId: int.tryParse(leadId),
          sourceRecordId: p.sourceRecordId ?? p.googlePlaceId,
          googlePlaceId: p.googlePlaceId,
          businessName: targetName,
          imported: true,
          duplicate: false,
        ),
      );
    }

    return ImportResultSummary(
      totalRequested: places.length,
      imported: importedCount,
      skippedDuplicates: skippedCount,
      duplicateNames: duplicateNames,
      records: recordResults,
      message:
          'Successfully imported $importedCount leads into CRM pipeline${skippedCount > 0 ? " ($skippedCount duplicates skipped)." : "."}',
    );
  }

  /// Update lead details
  Future<LeadModel> updateLead(String id, Map<String, dynamic> data) async {
    final index = _leads.indexWhere((l) => l.id == id);
    if (index == -1) {
      throw Exception('Lead $id not found for update.');
    }
    final existing = _leads[index];
    final targetName =
        data['businessName'] ?? data['companyName'] ?? data['title'];

    // Build socialMedia from data if provided
    LeadSocialMediaModel? updatedSocialMedia = existing.socialMedia;
    if (data['socialMedia'] is Map) {
      final smMap = Map<String, dynamic>.from(data['socialMedia'] as Map);
      updatedSocialMedia = LeadSocialMediaModel.fromJson(smMap);
    }

    final updated = existing.copyWith(
      businessName: targetName?.toString() ?? existing.businessName,
      companyName: targetName?.toString() ?? existing.companyName,
      title: targetName?.toString() ?? existing.title,
      firstName: data['firstName']?.toString() ?? existing.firstName,
      lastName: data['lastName']?.toString() ?? existing.lastName,
      phone: data['phone']?.toString() ?? existing.phone,
      email: data['email']?.toString() ?? existing.email,
      website: data['website']?.toString() ?? existing.website,
      address: data['address']?.toString() ?? existing.address,
      city: data['city']?.toString() ?? existing.city,
      state: data['state']?.toString() ?? existing.state,
      pincode: data['pincode']?.toString() ?? existing.pincode,
      priority: data['priority']?.toString() ?? existing.priority,
      value: (data['value'] as num?)?.toDouble() ?? existing.value,
      workNotes: data['workNotes']?.toString() ?? existing.workNotes,
      category: data['category']?.toString() ?? existing.category,
      source: data['source']?.toString() ?? existing.source,
      socialMedia: updatedSocialMedia,
    );

    _leads[index] = updated;
    return updated;
  }

  /// Controlled stage transition
  Future<LeadModel> updateStatus(
    String id, {
    required String status,
    int? stageId,
    String? notes,
  }) async {
    final normId = id.trim();
    var index = _leads.indexWhere(
      (l) => l.id.trim().toLowerCase() == normId.toLowerCase(),
    );
    LeadModel existing;
    if (index == -1) {
      existing = LeadModel(
        id: normId,
        title: 'Lead #$normId',
        firstName: '',
        lastName: '',
        source: 'MANUAL',
        status: status.toUpperCase(),
        priority: 'MEDIUM',
        value: 0.0,
        createdAt: DateTime.now().toIso8601String(),
      );
      _leads.insert(0, existing);
      index = 0;
    } else {
      existing = _leads[index];
    }
    String norm(String? s) =>
        (s ?? '').trim().toUpperCase().replaceAll(RegExp(r'[\s_\-]+'), '');
    final cleanStatus = norm(status);

    final stagesPool = currentStages;
    final matchedStage = stagesPool.cast<LeadStageModel?>().firstWhere(
      (s) =>
          s != null &&
          (norm(s.key) == cleanStatus ||
              norm(s.name) == cleanStatus ||
              s.id == stageId),
      orElse: () => null,
    );

    final resolvedStageName = matchedStage?.name ?? status;
    final resolvedColor = matchedStage?.color ?? existing.stageColorHex;
    final resolvedStageId = (stageId ?? matchedStage?.id ?? 1).toString();

    final nowIso = DateTime.now().toIso8601String();
    final updatedTimeline = List<LeadTimelineItemModel>.from(existing.timeline)
      ..add(
        LeadTimelineItemModel(
          id: 'tl_stage_${DateTime.now().millisecondsSinceEpoch}',
          leadId: id,
          action: 'STAGE_CHANGE',
          description: notes != null && notes.isNotEmpty
              ? notes
              : 'Moved to $resolvedStageName stage.',
          createdAt: nowIso,
        ),
      );

    final updated = existing.copyWith(
      status: status.toUpperCase(),
      stageId: resolvedStageId,
      stageNameConfig: resolvedStageName,
      stageColorHex: resolvedColor,
      timeline: updatedTimeline,
      workNotes: notes ?? existing.workNotes,
      updatedAt: nowIso,
    );

    _leads[index] = updated;
    return updated;
  }

  /// Delete a lead
  Future<bool> deleteLead(String id) async {
    removeLead(id);
    return true;
  }

  /// Add a note to a lead
  Future<void> addNote(String id, String content) async {
    final index = _leads.indexWhere((l) => l.id == id);
    if (index != -1) {
      final lead = _leads[index];
      final newNotes = List<LeadNoteModel>.from(lead.notes)
        ..insert(
          0,
          LeadNoteModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            leadId: id,
            content: content,
            authorName: 'Agent',
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
      _leads[index] = lead.copyWith(notes: newNotes);
    }
  }

  Future<LeadModel> logFollowUp(
    String id, {
    required String outcome,
    String? notes,
    String? nextFollowUpDate,
    String? nextFollowUpTime,
  }) async {
    final index = _leads.indexWhere((l) => l.id == id);
    if (index != -1) {
      final updated = _leads[index].copyWith(
        status: 'FOLLOW_UP',
        stageNameConfig: 'Follow-Up',
        nextFollowUpDate: nextFollowUpDate,
        nextFollowUpTime: nextFollowUpTime,
        workNotes: notes,
      );
      _leads[index] = updated;
      return updated;
    }
    throw Exception('Lead $id not found');
  }

  Future<LeadModel> manageVisit(
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
  }) async {
    final index = _leads.indexWhere((l) => l.id == id);
    if (index != -1) {
      final existing = _leads[index];
      LeadModel updated;
      final nowIso = DateTime.now().toIso8601String();

      if (action.toUpperCase() == 'SCHEDULE') {
        final visit = LeadVisitModel(
          id: 'v_${DateTime.now().millisecondsSinceEpoch}',
          customerName:
              existing.companyName ?? existing.businessName ?? existing.title,
          purpose: purpose ?? 'Field Visit',
          date: date ?? DateTime.now().toIso8601String().split('T').first,
          time: time ?? '11:00 AM',
          location: location ?? existing.address ?? 'Client Site',
          status: 'SCHEDULED',
          notes: notes,
          createdAt: nowIso,
        );
        final newVisits = List<LeadVisitModel>.from(existing.visits)
          ..insert(0, visit);
        final visitStage = _matchStage(['VISIT_SCHEDULED', 'VISIT']);
        updated = existing.copyWith(
          status: visitStage?.key ?? existing.status,
          stageNameConfig: visitStage?.name ?? existing.stageNameConfig,
          stageId: visitStage?.id.toString() ?? existing.stageId,
          visits: newVisits,
          address: location ?? existing.address,
          workNotes: notes ?? summary,
          updatedAt: nowIso,
        );
      } else if (action.toUpperCase() == 'COMPLETE') {
        final visitStage = _matchStage(['VISIT_DONE']);
        updated = existing.copyWith(
          status: visitStage?.key ?? existing.status,
          stageNameConfig: visitStage?.name ?? existing.stageNameConfig,
          stageId: visitStage?.id.toString() ?? existing.stageId,
          workNotes: summary ?? notes,
          updatedAt: nowIso,
        );
      } else {
        updated = existing.copyWith(
          address: location ?? existing.address,
          workNotes: notes ?? summary,
          updatedAt: nowIso,
        );
      }
      _leads[index] = updated;
      return updated;
    }
    throw Exception('Lead $id not found');
  }

  Future<LeadModel> createProposal(
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
    final index = _leads.indexWhere((l) => l.id == id);
    if (index != -1) {
      final updated = _leads[index].copyWith(
        value: totalAmount,
        workNotes: notes,
      );
      _leads[index] = updated;
      return updated;
    }
    throw Exception('Lead $id not found');
  }

  Future<LeadModel> recordFinalCall(
    String id, {
    double? proposalAmount,
    required String customerResponse,
    String? negotiationNotes,
    String? expectedClosingDate,
    String? nextAction,
  }) async {
    final index = _leads.indexWhere((l) => l.id == id);
    if (index != -1) {
      final isAccepted = customerResponse.toLowerCase().contains('accept');
      final newStatus = isAccepted ? 'PAYMENT' : 'FINAL_CALL';
      final newStage = isAccepted ? 'Payment Pending' : 'Final Call';
      final updated = _leads[index].copyWith(
        status: newStatus,
        stageNameConfig: newStage,
        value: proposalAmount ?? _leads[index].value,
        workNotes: negotiationNotes,
      );
      _leads[index] = updated;
      return updated;
    }
    throw Exception('Lead $id not found');
  }

  Future<LeadModel> recordPayment(
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
    final index = _leads.indexWhere((l) => l.id == id);
    if (index != -1) {
      final updated = _leads[index].copyWith(
        paidAmount: paidAmount,
        paymentStatus: status,
        paymentMethod: paymentMethod,
        paymentRef: transactionRef,
        workNotes: notes,
      );
      _leads[index] = updated;
      return updated;
    }
    throw Exception('Lead $id not found');
  }

  Future<LeadModel> startWork(
    String id, {
    required String workStartDate,
    String? assignedTeam,
    String? serviceName,
    String? notes,
  }) async {
    final index = _leads.indexWhere((l) => l.id == id);
    if (index != -1) {
      final updated = _leads[index].copyWith(
        workStartDate: workStartDate,
        assignedTeam: assignedTeam,
        workNotes: notes,
      );
      _leads[index] = updated;
      return updated;
    }
    throw Exception('Lead $id not found');
  }

  Future<DuplicateCheckResult> checkDuplicate({
    String? phone,
    String? companyName,
    String? website,
    String? googlePlaceId,
  }) async {
    for (final l in _leads) {
      if (googlePlaceId != null &&
          googlePlaceId.isNotEmpty &&
          l.googlePlaceId == googlePlaceId) {
        return DuplicateCheckResult(
          isDuplicate: true,
          matchReason: 'Google Place ID already registered',
          existingLead: l,
        );
      }
      if (phone != null &&
          phone.isNotEmpty &&
          l.phone != null &&
          l.phone!.replaceAll(RegExp(r'\D'), '') ==
              phone.replaceAll(RegExp(r'\D'), '')) {
        return DuplicateCheckResult(
          isDuplicate: true,
          matchReason: 'Phone number already exists in CRM',
          existingLead: l,
        );
      }
      if (website != null &&
          website.isNotEmpty &&
          l.website != null &&
          l.website!.toLowerCase() == website.toLowerCase()) {
        return DuplicateCheckResult(
          isDuplicate: true,
          matchReason: 'Website domain already in CRM',
          existingLead: l,
        );
      }
    }
    return DuplicateCheckResult(isDuplicate: false);
  }

  Future<LeadCommunicationsResponse> getLeadCommunications(
    String leadId,
  ) async {
    return LeadCommunicationsResponse(
      leadId: int.tryParse(leadId) ?? 0,
      summary: const LeadCommunicationSummary(
        totalCommunications: 2,
        totalEmails: 1,
        totalWhatsApp: 1,
      ),
      communications: [
        LeadCommunicationItem(
          id: 'comm_1',
          channel: LeadCommChannel.email,
          direction: LeadCommDirection.outbound,
          action: 'EMAIL_SENT',
          status: LeadCommStatus.delivered,
          title: 'Introduction to QuikBoom CRM Solutions',
          content:
              'Thank you for your interest in our corporate software services.',
          recipient: 'contact@lead.com',
          sender: 'Agent',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        LeadCommunicationItem(
          id: 'comm_2',
          channel: LeadCommChannel.whatsapp,
          direction: LeadCommDirection.outbound,
          action: 'WHATSAPP_SENT',
          status: LeadCommStatus.read,
          title: 'Welcome Message',
          content:
              'Hello! We have reviewed your business requirements. Let us connect today.',
          recipient: '+91 98200 12345',
          sender: 'Agent',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> sendLeadEmail(
    String leadId, {
    String? subject,
    String? message,
  }) async {
    return {
      'success': true,
      'message': 'Email dispatched successfully via CRM mailer (demo mode).',
    };
  }

  Future<Map<String, dynamic>> sendLeadWhatsApp(
    String leadId, {
    String? message,
    String? templateName,
    String? stageName,
  }) async {
    return {
      'success': true,
      'message': 'WhatsApp message sent successfully (demo mode).',
    };
  }

  Future<List<WhatsAppTemplateModel>> getWhatsAppTemplates() async {
    return const [
      WhatsAppTemplateModel(
        key: 'new_lead_welcome',
        templateName: 'new_lead_welcome',
        title: 'Welcome Message',
        name: 'Welcome Message',
        body:
            'Hello, thank you for reaching out to us. We will assist you shortly.',
      ),
      WhatsAppTemplateModel(
        key: 'follow_up_reminder',
        templateName: 'follow_up_reminder',
        title: 'Follow-Up Reminder',
        name: 'Follow-Up Reminder',
        body:
            'Hi, following up on our discussion. Let us know a convenient time to talk.',
      ),
      WhatsAppTemplateModel(
        key: 'proposal_sent_notice',
        templateName: 'proposal_sent_notice',
        title: 'Proposal Sent',
        name: 'Proposal Sent',
        body:
            'Dear customer, we have sent across the customized proposal for your review.',
      ),
    ];
  }

  static String _extractCity(String address) {
    final parts = address.split(',');
    if (parts.length > 2) {
      return parts[parts.length - 2].trim();
    }
    return 'Vadodara';
  }

  static List<LeadModel> _initInitialLeads() {
    return [
      LeadModel(
        id: '101',
        stageId: '1',
        stageNameConfig: 'New',
        stageColorHex: '#0284C7',
        title: 'Apex Multi-Speciality Hospital',
        businessName: 'Apex Multi-Speciality Hospital',
        companyName: 'Apex Multi-Speciality Hospital',
        firstName: 'Dr. Rajesh',
        lastName: 'Patel',
        phone: '+91 98200 12345',
        email: 'contact@apexhealth.in',
        website: 'https://www.apexhealth.in',
        address: '101, RC Dutt Road, Alkapuri, Vadodara, Gujarat',
        city: 'Vadodara',
        state: 'Gujarat',
        pincode: '390007',
        country: 'India',
        category: 'Healthcare & Hospital',
        source: 'GOOGLE_PLACES',
        status: 'NEW',
        priority: 'HIGH',
        value: 150000.0,
        rating: 4.8,
        reviewCount: 245,
        googlePlaceId: 'ChIJ_apex_hospital_vadodara',
        createdAt: DateTime.now()
            .subtract(const Duration(hours: 4))
            .toIso8601String(),
        images: const [],
        notes: [
          LeadNoteModel(
            id: 'n_101_1',
            leadId: '101',
            content:
                'Interested in hospital management CRM and patient appointment automation.',
            authorName: 'System Import',
            createdAt: DateTime.now()
                .subtract(const Duration(hours: 3))
                .toIso8601String(),
          ),
        ],
        timeline: [
          LeadTimelineItemModel(
            id: 'tl_101_1',
            leadId: '101',
            action: 'CAPTURE',
            description: 'Captured via Google Places search.',
            createdAt: DateTime.now()
                .subtract(const Duration(hours: 4))
                .toIso8601String(),
          ),
        ],
      ),
      LeadModel(
        id: '102',
        stageId: '1',
        stageNameConfig: 'New',
        stageColorHex: '#0284C7',
        title: 'Cult.fit Pro Fitness Arena',
        businessName: 'Cult.fit Pro Fitness Arena',
        companyName: 'Cult.fit Pro Fitness Arena',
        firstName: 'Amit',
        lastName: 'Shah',
        phone: '+91 98210 23456',
        email: 'vadodara@cultfit.in',
        website: 'https://www.cultfit.in',
        address: '204, Atlantis K-10, Sarabhai Campus, Vadodara, Gujarat',
        city: 'Vadodara',
        state: 'Gujarat',
        pincode: '390023',
        country: 'India',
        category: 'Gym & Fitness',
        source: 'GOOGLE_PLACES',
        status: 'NEW',
        priority: 'HIGH',
        value: 85000.0,
        rating: 4.7,
        reviewCount: 180,
        googlePlaceId: 'ChIJ_cultfit_vadodara',
        createdAt: DateTime.now()
            .subtract(const Duration(hours: 6))
            .toIso8601String(),
        images: const [],
      ),
      LeadModel(
        id: '103',
        stageId: '2',
        stageNameConfig: 'Contacted',
        stageColorHex: '#D97706',
        title: 'The Grand Heritage Restaurant',
        businessName: 'The Grand Heritage Restaurant',
        companyName: 'The Grand Heritage Restaurant',
        firstName: 'Vikram',
        lastName: 'Desai',
        phone: '+91 98220 34567',
        email: 'events@grandheritage.com',
        website: 'https://www.grandheritage.com',
        address: 'Sayajigunj, Near Railway Station, Vadodara, Gujarat',
        city: 'Vadodara',
        state: 'Gujarat',
        pincode: '390005',
        country: 'India',
        category: 'Restaurant & Dining',
        source: 'GOOGLE_DISCOVERY',
        status: 'CONTACTED',
        priority: 'MEDIUM',
        value: 120000.0,
        rating: 4.5,
        reviewCount: 310,
        googlePlaceId: 'ChIJ_grandheritage_vadodara',
        createdAt: DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      ),
      LeadModel(
        id: '104',
        stageId: '3',
        stageNameConfig: 'Call Back',
        stageColorHex: '#8B5CF6',
        title: 'NextGen Cloud Innovations Pvt Ltd',
        businessName: 'NextGen Cloud Innovations Pvt Ltd',
        companyName: 'NextGen Cloud Innovations Pvt Ltd',
        firstName: 'Siddharth',
        lastName: 'Mehta',
        phone: '+91 98230 45678',
        email: 'info@nextgeninnovations.io',
        website: 'https://www.nextgeninnovations.io',
        address: 'B-Wing, Sun Pharma Road, Vadodara, Gujarat',
        city: 'Vadodara',
        state: 'Gujarat',
        pincode: '390012',
        country: 'India',
        category: 'Software & Technology',
        source: 'GOOGLE_PLACES',
        status: 'CALL_BACK',
        priority: 'HIGH',
        value: 250000.0,
        rating: 4.9,
        reviewCount: 88,
        googlePlaceId: 'ChIJ_nextgen_vadodara',
        createdAt: DateTime.now()
            .subtract(const Duration(days: 1, hours: 4))
            .toIso8601String(),
      ),
      LeadModel(
        id: '105',
        stageId: '4',
        stageNameConfig: 'Details Sent',
        stageColorHex: '#4F46E5',
        title: 'Enrich Luxury Salon & Bridal Spa',
        businessName: 'Enrich Luxury Salon & Bridal Spa',
        companyName: 'Enrich Luxury Salon & Bridal Spa',
        firstName: 'Pooja',
        lastName: 'Joshi',
        phone: '+91 98240 56789',
        email: 'alkapuri@enrichsalon.com',
        website: 'https://www.enrichsalon.com',
        address: 'Shop 12, Express Tower, Alkapuri, Vadodara, Gujarat',
        city: 'Vadodara',
        state: 'Gujarat',
        pincode: '390007',
        country: 'India',
        category: 'Beauty & Salon',
        source: 'GOOGLE_DISCOVERY',
        status: 'DETAILS_SENT',
        priority: 'MEDIUM',
        value: 65000.0,
        rating: 4.6,
        reviewCount: 154,
        googlePlaceId: 'ChIJ_enrich_vadodara',
        createdAt: DateTime.now()
            .subtract(const Duration(days: 2))
            .toIso8601String(),
      ),
      LeadModel(
        id: '106',
        stageId: '5',
        stageNameConfig: 'Follow-Up',
        stageColorHex: '#06B6D4',
        title: 'Maruti Suzuki Arena Velocity Motors',
        businessName: 'Maruti Suzuki Arena Velocity Motors',
        companyName: 'Maruti Suzuki Arena Velocity Motors',
        firstName: 'Gaurav',
        lastName: 'Sharma',
        phone: '+91 98250 67890',
        email: 'sales@velocitymaruti.in',
        website: 'https://www.velocitymaruti.in',
        address: 'Opp. Central Bus Depot, Station Road, Vadodara, Gujarat',
        city: 'Vadodara',
        state: 'Gujarat',
        pincode: '390002',
        country: 'India',
        category: 'Automotive Dealership',
        source: 'GOOGLE_PLACES',
        status: 'FOLLOW_UP',
        priority: 'HIGH',
        value: 320000.0,
        rating: 4.4,
        reviewCount: 420,
        googlePlaceId: 'ChIJ_velocity_maruti_vadodara',
        nextFollowUpDate: '2026-09-30',
        nextFollowUpTime: '11:00 AM',
        createdAt: DateTime.now()
            .subtract(const Duration(days: 2, hours: 6))
            .toIso8601String(),
      ),
      LeadModel(
        id: '107',
        stageId: '8',
        stageNameConfig: 'Proposal Sent',
        stageColorHex: '#7C3AED',
        title: 'Tata Consultancy Digital Hub',
        businessName: 'Tata Consultancy Digital Hub',
        companyName: 'Tata Consultancy Digital Hub',
        firstName: 'Nilesh',
        lastName: 'Rao',
        phone: '+91 98280 90123',
        email: 'corp@tcsdigital.in',
        website: 'https://www.tcsdigital.in',
        address: 'IT SEZ Tower, Gotri-Sevasi Road, Vadodara, Gujarat',
        city: 'Vadodara',
        state: 'Gujarat',
        pincode: '390021',
        country: 'India',
        category: 'Enterprise IT Services',
        source: 'GOOGLE_DISCOVERY',
        status: 'PROPOSAL_SENT',
        priority: 'HIGH',
        value: 500000.0,
        rating: 4.9,
        reviewCount: 520,
        googlePlaceId: 'ChIJ_tcs_vadodara',
        createdAt: DateTime.now()
            .subtract(const Duration(days: 3))
            .toIso8601String(),
      ),
      LeadModel(
        id: '108',
        stageId: '11',
        stageNameConfig: 'Won',
        stageColorHex: '#15803D',
        title: 'Barbeque Nation Dining & Grill',
        businessName: 'Barbeque Nation Dining & Grill',
        companyName: 'Barbeque Nation Dining & Grill',
        firstName: 'Rakesh',
        lastName: 'Verma',
        phone: '+91 98300 12345',
        email: 'gm.vadodara@barbequenation.com',
        website: 'https://www.barbequenation.com',
        address: 'Inorbit Mall, Gorwa, Vadodara, Gujarat',
        city: 'Vadodara',
        state: 'Gujarat',
        pincode: '390016',
        country: 'India',
        category: 'Hospitality & Dining',
        source: 'GOOGLE_PLACES',
        status: 'WON',
        priority: 'HIGH',
        value: 200000.0,
        paidAmount: 200000.0,
        paymentStatus: 'PAID',
        rating: 4.7,
        reviewCount: 890,
        googlePlaceId: 'ChIJ_bbq_nation_vadodara',
        createdAt: DateTime.now()
            .subtract(const Duration(days: 4))
            .toIso8601String(),
      ),
    ];
  }
}
