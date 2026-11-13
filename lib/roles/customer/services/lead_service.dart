import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/services/secure_storage_service.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_status_update_result.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_communication_model.dart';
import 'package:quickboom_crm_customer/roles/customer/repositories/local_lead_repository.dart';

class DuplicateCheckResult {
  final bool isDuplicate;
  final String? matchReason;
  final LeadModel? existingLead;

  DuplicateCheckResult({
    required this.isDuplicate,
    this.matchReason,
    this.existingLead,
  });
}

/// Service class for Lead management.
///
/// Communicates with backend endpoints (/leads, /leads/bulk, etc.) with seamless
/// local fallback to [LocalLeadRepository] when offline.
class LeadService {
  final ApiClient? _providedApiClient;
  int? _lastTotalCount;

  LeadService([this._providedApiClient]);

  ApiClient get _apiClient => _providedApiClient ?? ApiClient();
  LocalLeadRepository get _repo => LocalLeadRepository.instance;

  int? get lastTotalCount => _lastTotalCount ?? _repo.totalCount;

  /// Check if a prospect already exists in CRM
  Future<DuplicateCheckResult> checkDuplicate({
    String? phone,
    String? companyName,
    String? website,
    String? googlePlaceId,
  }) async {
    return _repo.checkDuplicate(
      phone: phone,
      companyName: companyName,
      website: website,
      googlePlaceId: googlePlaceId,
    );
  }

  /// Get paginated list of leads with optional filtering
  Future<List<LeadModel>> getLeads({
    String? status,
    String? search,
    String? stageId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      // Send exactly one stage selector. stageId from GET /leads/stages is
      // authoritative; status is only a fallback when stageId is absent.
      // Sending both lets a stale key disagree with the selected stage.
      final hasStageId = stageId != null && stageId.trim().isNotEmpty;
      if (hasStageId) {
        queryParams['stageId'] = stageId.trim();
      } else if (status != null && status.trim().isNotEmpty) {
        queryParams['status'] = status.trim();
      }

      await _apiClient.ensureAuthLoaded();
      if (_apiClient.token != null && _apiClient.token!.isNotEmpty) {
        final res = await _apiClient.get(
          '/leads',
          queryParameters: queryParams,
        );
        if (res.data != null) {
          final List list = (res.data is Map && res.data['data'] is List)
              ? res.data['data']
              : (res.data is List ? res.data : []);
          final fetched = list.map((json) => LeadModel.fromJson(json)).toList()
            ..sort((a, b) => a.compareCreatedAtDesc(b));

          // Authoritative backend synchronization:
          // When authenticated, the GET response is the source of truth.
          // Do not re-inject local-only rows (deleted on another device, dummy
          // seed leads, or an old stage copy). Backend findAll already enforces
          // employee RBAC — do NOT re-filter by login employeeId string vs DB id.
          final repoStatus = hasStageId ? null : status;
          final repoStageId = hasStageId ? stageId.trim() : null;
          if (queryParams.isEmpty) {
            _repo.replaceLeads(fetched);
          } else {
            _repo.upsertLeads(fetched);
            final fetchedIds = fetched
                .map((l) => l.id.trim().toLowerCase())
                .toSet();
            final localFiltered = await _repo.getLeads(
              status: repoStatus,
              search: search,
              stageId: repoStageId,
            );
            for (final local in localFiltered) {
              if (!fetchedIds.contains(local.id.trim().toLowerCase())) {
                _repo.removeLead(local.id);
              }
            }
          }

          _lastTotalCount = res.data is Map && res.data['meta'] is Map
              ? res.data['meta']['total']
              : (res.data is Map && res.data['pagination'] is Map
                    ? res.data['pagination']['total']
                    : fetched.length);

          final empId = await SecureStorageService.getEmployeeId();
          final compId = await SecureStorageService.getCustomerId();
          debugPrint('''
[LEADS_PIPELINE]
employeeId: ${empId ?? 'unknown'}
companyId: ${compId ?? _apiClient.customerId ?? '1'}
API: GET /api/v1/leads
status: ${res.statusCode}
itemsCount: ${fetched.length}
totalCount: $_lastTotalCount
returnedLeadIds: ${fetched.map((l) => l.id).take(10).toList()}
''');

          return fetched;
        }
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401 &&
          _apiClient.token != null &&
          _apiClient.token!.isNotEmpty) {
        // Allow 401 to trigger token refresh interceptor rather than masking expired session
        rethrow;
      }
      // Fall back to local repository for network/offline errors
    } catch (_) {
      // Fall back to local repository if network request fails
    }
    final hasStageId = stageId != null && stageId.trim().isNotEmpty;
    return _repo.getLeads(
      status: hasStageId ? null : status,
      search: search,
      stageId: hasStageId ? stageId.trim() : null,
    );
  }

  /// Get configured lead stages / metadata from authoritative backend endpoint (with local repo fallback)
  Future<List<Map<String, dynamic>>> getStages() async {
    try {
      await _apiClient.ensureAuthLoaded();
      if (_apiClient.token != null && _apiClient.token!.isNotEmpty) {
        final res = await _apiClient.get('/leads/stages', queryParameters: const {'includeInactive': 'false'});
        if (res.data != null) {
          final List list = (res.data is Map && res.data['data'] is List)
              ? res.data['data']
              : (res.data is List ? res.data : []);
          if (list.isNotEmpty) {
            final stages = List<Map<String, dynamic>>.from(
              list.map((item) => Map<String, dynamic>.from(item as Map)),
            );
            _repo.setConfiguredStages(stages);
            return stages;
          }
        }
      }
    } catch (e) {
      debugPrint(
        '[LeadService] getStages API error, falling back to local repository: $e',
      );
    }
    return _repo.getStages();
  }

  /// Get single lead details.
  ///
  /// Connects to GET /api/v1/leads/:id as the authoritative source of truth,
  /// updating the local cache on success.
  /// Falls back to local cache when offline or if local lead exists.
  Future<LeadModel> getLeadById(String id) async {
    final normId = id.trim();
    if (normId.isEmpty) {
      throw Exception('Invalid lead ID.');
    }

    final localLead = _repo.findLeadLocally(normId);

    await _apiClient.ensureAuthLoaded();
    final hasAuth = _apiClient.token != null && _apiClient.token!.isNotEmpty;

    // In offline or non-authenticated test mode, return local if found
    if (localLead != null && !hasAuth) {
      return localLead;
    }

    if (hasAuth) {
      try {
        final res = await _apiClient.get('/leads/$normId');
        final statusCode = res.statusCode ?? 200;
        debugPrint('[LEAD_API] GET /api/v1/leads/$normId status=$statusCode');

        if (res.data != null) {
          final Map<String, dynamic> json =
              (res.data is Map && res.data['data'] is Map)
              ? Map<String, dynamic>.from(res.data['data'])
              : (res.data is Map
                    ? Map<String, dynamic>.from(res.data)
                    : <String, dynamic>{});
          if (json.isNotEmpty) {
            final lead = LeadModel.fromJson(json);
            _repo.upsertLead(lead);

            debugPrint('''
[LEAD_API]
leadId=${lead.id}
stageId=${lead.stageId}
stageName=${lead.stageName}
assignedEmployee=${lead.assignedToName ?? lead.assignedToId ?? "none"}
''');
            return lead;
          }
        }
      } on DioException catch (dioErr) {
        final statusCode = dioErr.response?.statusCode ?? 500;
        debugPrint('[LEAD_API] GET /api/v1/leads/$normId status=$statusCode');

        if (statusCode == 401) {
          rethrow;
        }
        if (statusCode == 403) {
          throw Exception('You do not have permission to view Lead #$normId.');
        }
        if (statusCode == 404) {
          _repo.removeLead(normId);
          throw Exception('Lead with ID $normId was not found.');
        }

        // For other network/server errors, fallback to local if available
        if (localLead != null) return localLead;

        final serverMsg = dioErr.response?.data?['message'];
        final msg =
            (serverMsg is List
                ? serverMsg.join(', ')
                : serverMsg?.toString()) ??
            dioErr.message ??
            'Failed to load lead details.';
        throw Exception(msg);
      } catch (e) {
        if (e.toString().contains('404') ||
            e.toString().contains('was not found')) {
          _repo.removeLead(normId);
          rethrow;
        }
        if (localLead != null) return localLead;
        rethrow;
      }
    }

    if (localLead != null) return localLead;
    throw Exception('Lead with ID $normId was not found.');
  }

  /// Create a new CRM Lead with authoritative backend synchronization
  Future<LeadModel> createLead(Map<String, dynamic> data) async {
    await _apiClient.ensureAuthLoaded();
    if (_apiClient.token != null && _apiClient.token!.isNotEmpty) {
      try {
        final res = await _apiClient.post('/leads', data: data);
        if (res.data != null) {
          final Map<String, dynamic> json =
              (res.data is Map && res.data['data'] is Map)
              ? Map<String, dynamic>.from(res.data['data'])
              : (res.data is Map
                    ? Map<String, dynamic>.from(res.data)
                    : <String, dynamic>{});
          if (json.isNotEmpty) {
            final lead = LeadModel.fromJson(json);
            _repo.upsertLead(lead);
            return lead;
          }
        }
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 401) rethrow;
        final serverMsg = dioErr.response?.data?['message'];
        final msg =
            (serverMsg is List
                ? serverMsg.join(', ')
                : serverMsg?.toString()) ??
            dioErr.message ??
            'Failed to create lead.';
        throw Exception(msg);
      } catch (e) {
        debugPrint('[LEAD_SERVICE] Remote createLead error: $e');
        rethrow;
      }
    }
    return _repo.createLead(data);
  }

  /// Update lead details
  Future<LeadModel> updateLead(String id, Map<String, dynamic> data) async {
    final normId = id.trim();
    await _apiClient.ensureAuthLoaded();
    final hasAuth = _apiClient.token != null && _apiClient.token!.isNotEmpty;

    if (hasAuth) {
      try {
        final res = await _apiClient.patch('/leads/$normId', data: data);
        if (res.data != null) {
          final Map<String, dynamic> json =
              (res.data is Map && res.data['data'] is Map)
              ? Map<String, dynamic>.from(res.data['data'])
              : (res.data is Map
                    ? Map<String, dynamic>.from(res.data)
                    : <String, dynamic>{});
          if (json.isNotEmpty) {
            // API returned the full updated lead — use it directly.
            final updated = LeadModel.fromJson(json);
            _repo.upsertLead(updated);
            return updated;
          }
          // PATCH succeeded but body has no lead data (e.g. {success:true}).
          // Fetch the authoritative lead via GET to get all updated fields.
          debugPrint(
            '[LEAD_SERVICE] updateLead: PATCH succeeded with empty body, fetching lead $normId',
          );
          return await getLeadById(normId);
        }
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 401) rethrow;
        if (dioErr.response?.statusCode == 403) {
          throw Exception(
            'You do not have permission to update Lead #$normId.',
          );
        }
        if (dioErr.response?.statusCode == 404) {
          throw Exception('Lead with ID $normId was not found.');
        }
        // For other network/transient errors, fall back to local update.
        debugPrint(
          '[LEAD_SERVICE] updateLead: DioException $normId — ${dioErr.message}',
        );
      } catch (e) {
        // Propagate non-network errors; fall back to local for others.
        debugPrint('[LEAD_SERVICE] updateLead: unexpected error $normId — $e');
      }
    }
    // Offline / unauthenticated: apply changes locally.
    return _repo.updateLead(normId, data);
  }

  /// Controlled stage status transition
  ///
  /// Sends PATCH /leads/:id/status with numeric stageId and status.
  /// Authoritative backend response updates local repository cache and returns fresh LeadModel.
  Future<LeadStatusUpdateResult> updateStatus(
    String id, {
    required String status,
    int? stageId,
    String? notes,
  }) async {
    final normId = id.trim();
    if (normId.isEmpty) {
      throw Exception('Invalid lead ID for stage update.');
    }

    final payload = <String, dynamic>{'status': status.toUpperCase()};
    if (stageId != null) {
      payload['stageId'] = stageId;
    }
    if (notes != null && notes.isNotEmpty) {
      payload['notes'] = notes;
    }

    await _apiClient.ensureAuthLoaded();
    final hasAuth = _apiClient.token != null && _apiClient.token!.isNotEmpty;
    final empId = await SecureStorageService.getEmployeeId();
    final compId = await SecureStorageService.getCustomerId();
    final cachedLead = _repo.findLeadLocally(normId);

    debugPrint('''
[LEAD_STATUS_DEBUG]
leadId=$normId
companyName=${cachedLead?.companyName ?? cachedLead?.businessName ?? cachedLead?.title ?? 'unknown'}
source=${cachedLead?.source ?? 'unknown'}
employeeId=${empId ?? 'unknown'}
companyId=${compId ?? 'unknown'}
stageId=$stageId
status=$status
''');

    if (hasAuth) {
      try {
        final res = await _apiClient.patch(
          '/leads/$normId/status',
          data: payload,
        );
        if (res.data != null) {
          final root = res.data is Map
              ? Map<String, dynamic>.from(res.data)
              : <String, dynamic>{};
          if (root.isNotEmpty) {
            final result = LeadStatusUpdateResult.fromApiResponse(root);
            _repo.upsertLead(result.lead);
            return result;
          }
        }
      } on DioException catch (dioErr) {
        final statusCode = dioErr.response?.statusCode;
        if (statusCode == 401) {
          rethrow;
        }
        if (statusCode == 403) {
          throw Exception(
            'You do not have permission to update stage for Lead #$normId.',
          );
        }
        if (statusCode == 404) {
          _repo.removeLead(normId);
          throw Exception('Lead with ID $normId was not found on server.');
        }
        final serverMsg = dioErr.response?.data?['message'];
        final msg =
            (serverMsg is List
                ? serverMsg.join(', ')
                : serverMsg?.toString()) ??
            dioErr.message ??
            'Failed to update lead stage.';
        throw Exception(msg);
      } catch (e) {
        if (e.toString().contains('404') ||
            e.toString().contains('was not found')) {
          _repo.removeLead(normId);
          rethrow;
        }
        if (_repo.findLeadLocally(normId) != null) {
          final offline = await _repo.updateStatus(
            normId,
            status: status,
            stageId: stageId,
            notes: notes,
          );
          return LeadStatusUpdateResult(lead: offline);
        }
        rethrow;
      }
    }

    // Offline / local execution (e.g. tests or unauthenticated local mode)
    final offline = await _repo.updateStatus(
      normId,
      status: status,
      stageId: stageId,
      notes: notes,
    );
    return LeadStatusUpdateResult(lead: offline);
  }

  /// Soft delete a lead via DELETE /leads/:id
  Future<bool> deleteLead(String id) async {
    try {
      await _apiClient.ensureAuthLoaded();
      final res = await _apiClient.delete('/leads/$id');
      await _repo.deleteLead(id);
      return res.statusCode == 200 || res.statusCode == 204;
    } on DioException catch (dioErr) {
      final serverMsg = dioErr.response?.data?['message'];
      final msg =
          (serverMsg is List ? serverMsg.join(', ') : serverMsg?.toString()) ??
          dioErr.message ??
          'Failed to delete lead.';
      throw Exception(msg);
    } catch (_) {
      return _repo.deleteLead(id);
    }
  }

  /// Bulk soft-delete leads via DELETE /leads/bulk
  Future<Map<String, dynamic>> bulkDeleteLeads(List<int> ids) async {
    if (ids.isEmpty) return {'success': true, 'deleted': 0};

    final payload = {'ids': ids};
    final queryStr = ids.join(',');
    debugPrint(
      '[BULK_DELETE_DEBUG]\n'
      'selectedLeadIds=$ids\n'
      'requestUrl=/api/v1/leads/bulk\n'
      'requestMethod=DELETE\n'
      'requestPayload=$payload\n'
      'requestQuery=ids=$queryStr',
    );

    try {
      await _apiClient.ensureAuthLoaded();
      final res = await _apiClient.delete(
        '/leads/bulk',
        data: payload,
        queryParameters: {'ids': queryStr},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      debugPrint(
        '[BULK_DELETE_DEBUG]\n'
        'responseStatus=${res.statusCode}\n'
        'responseData=${res.data}',
      );

      final rawData = res.data;
      final Map<String, dynamic> result = rawData is Map<String, dynamic>
          ? rawData
          : (rawData is Map
                ? Map<String, dynamic>.from(rawData)
                : {'success': true, 'deleted': ids.length});

      // Keep local repository in sync
      for (final id in ids) {
        await _repo.deleteLead(id.toString());
      }
      return result;
    } on DioException catch (dioErr) {
      debugPrint(
        '[BULK_DELETE_DEBUG]\n'
        'responseStatus=${dioErr.response?.statusCode}\n'
        'responseError=${dioErr.response?.data}',
      );

      // If DELETE /leads/bulk encountered 404 due to reverse-proxy route collision,
      // fallback to POST /leads/bulk-delete which is guaranteed not to collide with :id
      if (dioErr.response?.statusCode == 404) {
        try {
          debugPrint(
            '[BULK_DELETE_DEBUG]\n'
            'requestUrl=/api/v1/leads/bulk-delete\n'
            'requestMethod=POST\n'
            'requestPayload=$payload',
          );
          final fallbackRes = await _apiClient.post(
            '/leads/bulk-delete',
            data: payload,
            options: Options(headers: {'Content-Type': 'application/json'}),
          );

          debugPrint(
            '[BULK_DELETE_DEBUG]\n'
            'fallbackResponseStatus=${fallbackRes.statusCode}\n'
            'fallbackResponseData=${fallbackRes.data}',
          );

          final rawData = fallbackRes.data;
          final Map<String, dynamic> result = rawData is Map<String, dynamic>
              ? rawData
              : (rawData is Map
                    ? Map<String, dynamic>.from(rawData)
                    : {'success': true, 'deleted': ids.length});

          for (final id in ids) {
            await _repo.deleteLead(id.toString());
          }
          return result;
        } catch (fallbackErr) {
          debugPrint(
            '[BULK_DELETE_DEBUG] POST fallback also failed: $fallbackErr',
          );
          // If server routes are caught by older backend image, safely delete leads via single delete
          int deletedCount = 0;
          for (final id in ids) {
            try {
              await deleteLead(id.toString());
              deletedCount++;
            } catch (singleErr) {
              debugPrint(
                '[BULK_DELETE_DEBUG] Single delete fallback failed for lead $id: $singleErr',
              );
            }
          }
          if (deletedCount > 0) {
            return {
              'success': true,
              'requested': ids.length,
              'deleted': deletedCount,
              'failed': ids.length - deletedCount,
            };
          }
        }
      }

      final serverMsg = dioErr.response?.data?['message'];
      final msg =
          (serverMsg is List ? serverMsg.join(', ') : serverMsg?.toString()) ??
          dioErr.message ??
          'Failed to delete leads.';
      throw Exception(msg);
    } catch (_) {
      for (final id in ids) {
        await _repo.deleteLead(id.toString());
      }
      return {'success': true, 'deleted': ids.length};
    }
  }

  /// Add a note to lead
  Future<LeadNoteModel?> addNote(String id, String content) async {
    final normId = id.trim();
    if (content.trim().isEmpty) {
      throw Exception('Note content cannot be empty');
    }
    await _apiClient.ensureAuthLoaded();
    final hasAuth = _apiClient.token != null && _apiClient.token!.isNotEmpty;

    if (hasAuth) {
      final res = await _apiClient.post(
        '/leads/$normId/notes',
        data: {'content': content.trim()},
      );
      if (res.data != null && res.data is Map) {
        final map = Map<String, dynamic>.from(res.data as Map);
        if (map['data'] is Map) {
          final note = LeadNoteModel.fromJson(Map<String, dynamic>.from(map['data'] as Map));
          await _repo.addNote(normId, content);
          return note;
        }
      }
      await _repo.addNote(normId, content);
      return null;
    }
    await _repo.addNote(normId, content);
    return null;
  }

  /// Get notes for lead
  Future<List<LeadNoteModel>> getNotes(String id) async {
    final normId = id.trim();
    await _apiClient.ensureAuthLoaded();
    final hasAuth = _apiClient.token != null && _apiClient.token!.isNotEmpty;

    if (hasAuth) {
      try {
        final res = await _apiClient.get('/leads/$normId/notes');
        if (res.data != null && res.data is Map) {
          final map = Map<String, dynamic>.from(res.data as Map);
          final dynamic items = map['data'] ?? map['notes'];
          if (items is List) {
            final notes = items
                .whereType<Map>()
                .map((m) => LeadNoteModel.fromJson(Map<String, dynamic>.from(m)))
                .toList();
            return notes;
          }
        }
      } catch (e) {
        debugPrint('[LEAD_SERVICE] getNotes error: $e, falling back to getLeadById');
      }
    }
    final lead = await getLeadById(normId);
    return lead.notes;
  }

  /// Log follow-up call outcome, next follow up date/time, and update status to FOLLOW_UP
  Future<LeadModel> logFollowUp(
    String id, {
    required String outcome,
    String? notes,
    String? nextFollowUpDate,
    String? nextFollowUpTime,
  }) async {
    final normId = id.trim();
    if (normId.isEmpty) {
      throw Exception('Invalid lead ID');
    }

    final payload = <String, dynamic>{'outcome': outcome};
    if (notes != null && notes.isNotEmpty) {
      payload['notes'] = notes;
    }
    if (nextFollowUpDate != null && nextFollowUpDate.isNotEmpty) {
      payload['nextFollowUpDate'] = nextFollowUpDate;
    }
    if (nextFollowUpTime != null && nextFollowUpTime.isNotEmpty) {
      payload['nextFollowUpTime'] = nextFollowUpTime;
    }

    await _apiClient.ensureAuthLoaded();
    final hasAuth = _apiClient.token != null && _apiClient.token!.isNotEmpty;

    if (hasAuth) {
      try {
        final res = await _apiClient.post(
          '/leads/$normId/follow-ups',
          data: payload,
        );
        if (res.data != null) {
          final Map<String, dynamic> json =
              (res.data is Map && res.data['data'] is Map)
              ? Map<String, dynamic>.from(res.data['data'])
              : (res.data is Map
                    ? Map<String, dynamic>.from(res.data)
                    : <String, dynamic>{});
          if (json.isNotEmpty) {
            final updated = LeadModel.fromJson(json);
            _repo.upsertLead(updated);
            return updated;
          }
        }
      } catch (e) {
        debugPrint('[LEAD_SERVICE] logFollowUp API error: $e');
      }
    }

    return _repo.logFollowUp(
      normId,
      outcome: outcome,
      notes: notes,
      nextFollowUpDate: nextFollowUpDate,
      nextFollowUpTime: nextFollowUpTime,
    );
  }

  /// Manage field visit
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
    dynamic employeeId,
  }) async {
    final normId = id.trim();
    await _apiClient.ensureAuthLoaded();
    final hasAuth = _apiClient.token != null && _apiClient.token!.isNotEmpty;

    if (hasAuth) {
      try {
        final payload = <String, dynamic>{
          'action': action,
          if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
          if (date != null && date.isNotEmpty) 'date': date,
          if (time != null && time.isNotEmpty) 'time': time,
          if (location != null && location.isNotEmpty) 'location': location,
          'latitude': ?latitude,
          'longitude': ?longitude,
          if (summary != null && summary.isNotEmpty) 'summary': summary,
          if (customerResponse != null && customerResponse.isNotEmpty)
            'customerResponse': customerResponse,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'employeeId': ?employeeId,
        };

        final res = await _apiClient.post(
          '/leads/$normId/visits',
          data: payload,
        );

        if (res.data != null) {
          final Map<String, dynamic> json =
              (res.data is Map && res.data['data'] is Map)
              ? Map<String, dynamic>.from(res.data['data'])
              : (res.data is Map
                    ? Map<String, dynamic>.from(res.data)
                    : <String, dynamic>{});
          if (json.isNotEmpty) {
            final updated = LeadModel.fromJson(json);
            _repo.upsertLead(updated);
            return updated;
          }
        }
      } catch (e) {
        debugPrint('[LeadService.manageVisit] API error: $e');
        rethrow;
      }
    }

    return _repo.manageVisit(
      normId,
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
    );
  }

  /// Create commercial proposal
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
    return _repo.createProposal(
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
  }

  /// Log final negotiation call outcome
  Future<LeadModel> recordFinalCall(
    String id, {
    double? proposalAmount,
    required String customerResponse,
    String? negotiationNotes,
    String? expectedClosingDate,
    String? nextAction,
  }) async {
    final normId = id.trim();
    if (normId.isEmpty) {
      throw Exception('Invalid lead ID');
    }

    final payload = <String, dynamic>{'customerResponse': customerResponse};
    if (proposalAmount != null) {
      payload['proposalAmount'] = proposalAmount;
    }
    if (negotiationNotes != null && negotiationNotes.isNotEmpty) {
      payload['negotiationNotes'] = negotiationNotes;
    }
    if (expectedClosingDate != null && expectedClosingDate.isNotEmpty) {
      payload['expectedClosingDate'] = expectedClosingDate;
    }

    await _apiClient.ensureAuthLoaded();
    final hasAuth = _apiClient.token != null && _apiClient.token!.isNotEmpty;

    if (hasAuth) {
      try {
        final res = await _apiClient.post(
          '/leads/$normId/final-call',
          data: payload,
        );
        if (res.data != null) {
          final Map<String, dynamic> json =
              (res.data is Map && res.data['data'] is Map)
              ? Map<String, dynamic>.from(res.data['data'])
              : (res.data is Map
                    ? Map<String, dynamic>.from(res.data)
                    : <String, dynamic>{});
          if (json.isNotEmpty) {
            final updated = LeadModel.fromJson(json);
            _repo.upsertLead(updated);
            return updated;
          }
        }
      } catch (e) {
        debugPrint('[LEAD_SERVICE] recordFinalCall API error: $e');
      }
    }

    return _repo.recordFinalCall(
      normId,
      proposalAmount: proposalAmount,
      customerResponse: customerResponse,
      negotiationNotes: negotiationNotes,
      expectedClosingDate: expectedClosingDate,
      nextAction: nextAction,
    );
  }

  /// Record verified payment
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
    return _repo.recordPayment(
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
  }

  /// Kickoff project work
  Future<LeadModel> startWork(
    String id, {
    required String workStartDate,
    String? assignedTeam,
    String? serviceName,
    String? notes,
  }) async {
    return _repo.startWork(
      id,
      workStartDate: workStartDate,
      assignedTeam: assignedTeam,
      serviceName: serviceName,
      notes: notes,
    );
  }

  /// Get unified communication history and status tracking for a lead
  Future<LeadCommunicationsResponse> getLeadCommunications(
    String leadId,
  ) async {
    return _repo.getLeadCommunications(leadId);
  }

  /// Send email to lead
  Future<Map<String, dynamic>> sendLeadEmail(
    String leadId, {
    String? subject,
    String? message,
  }) async {
    return _repo.sendLeadEmail(leadId, subject: subject, message: message);
  }

  /// Send WhatsApp message or stage template to lead
  Future<Map<String, dynamic>> sendLeadWhatsApp(
    String leadId, {
    String? message,
    String? templateName,
    String? stageName,
  }) async {
    return _repo.sendLeadWhatsApp(
      leadId,
      message: message,
      templateName: templateName,
      stageName: stageName,
    );
  }

  /// Get available WhatsApp templates
  Future<List<WhatsAppTemplateModel>> getWhatsAppTemplates() async {
    return _repo.getWhatsAppTemplates();
  }
}
