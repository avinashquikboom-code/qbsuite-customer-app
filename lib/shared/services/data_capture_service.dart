import '../models/capture_history.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/services/secure_storage_service.dart';

import 'package:quickboom_crm_customer/shared/models/data_capture_model.dart';
import 'package:quickboom_crm_customer/shared/repositories/local_data_capture_repository.dart';

/// Existing extraction client. Saved-record CRUD uses DataCaptureRecordsService.
class DataCaptureService {
  final ApiClient? _providedApiClient;

  LocalDataCaptureRepository get _repo => LocalDataCaptureRepository.instance;
  ApiClient get _apiClient => _providedApiClient ?? ApiClient();

  static void clearCache() {
    LocalDataCaptureRepository.instance.clearCache();
  }

  DataCaptureService([this._providedApiClient]);

  Future<CaptureHistoryPage> getHistory({
    int page = 1,
    String search = '',
    DateTime? from,
    DateTime? to,
  }) async {
    await _apiClient.ensureAuthLoaded();
    final safePage = page < 1 ? 1 : page;
    final query = <String, dynamic>{
      'page': safePage,
      'limit': 20,
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };
    if (kDebugMode) {
      debugPrint('[DATA_CAPTURE_HISTORY] GET /data-capture/history params=$query');
    }
    final response = await _apiClient.get(
      '/data-capture/history',
      queryParameters: query,
    );
    return CaptureHistoryPage.fromJson(response.data);
  }

  /// Check if the employee/customer has data capture permission & access
  Future<bool> checkAccess() async {
    await getUsageSummary();
    return true;
  }

  /// Extracts verified businesses from Google Places API via backend
  Future<ExtractionJobRecord> extractPlaces({
    required String keyword,
    required String location,
    int maxResults = 20,
    String? requestId,
  }) async {
    try {
      await _apiClient.ensureAuthLoaded();
      if (_apiClient.token != null && _apiClient.token!.isNotEmpty) {
        final payload = <String, dynamic>{
          'keyword': keyword.trim(),
          'location': location.trim(),
          'maxResults': maxResults,
          'source': 'GOOGLE_PLACES',
          'requestId': ?requestId,
        };

        final res = await _apiClient.post(
          '/data-capture/extract',
          data: payload,
          options: Options(
            receiveTimeout: const Duration(seconds: 45),
            sendTimeout: const Duration(seconds: 15),
          ),
        );

        if (res.data != null) {
          final resData = res.data is Map<String, dynamic>
              ? res.data as Map<String, dynamic>
              : (res.data is Map
                    ? Map<String, dynamic>.from(res.data as Map)
                    : <String, dynamic>{});
          final record = ExtractionJobRecord.fromJson(resData);
          return record;
        }
      }
    } catch (e) {
      debugPrint('[DATA_CAPTURE_SERVICE] Remote extractPlaces error: $e');
      rethrow;
    }

    throw StateError('Please sign in to extract businesses.');
  }

  /// Imports selected business records into CRM Leads pipeline with authoritative backend persistence
  Future<ImportResultSummary> importToLeads({
    required String jobId,
    List<String>? placeIds,
    List<CapturedBusiness>? places,
    dynamic assignedToId,
    dynamic employeeId,
  }) async {
    try {
      final resolvedEmpId =
          employeeId ?? await SecureStorageService.getEmployeeId();
      final tenantId = await SecureStorageService.getCustomerId();

      await _apiClient.ensureAuthLoaded();
      if (_apiClient.token != null && _apiClient.token!.isNotEmpty) {
        // Send only supported fields accepted by production ImportToLeadsDto
        final payload = <String, dynamic>{
          if (jobId.isNotEmpty) 'jobId': jobId,
          if (placeIds != null && placeIds.isNotEmpty) 'placeIds': placeIds,
        };

        debugPrint('''
[DATA_CAPTURE_IMPORT]
dataCaptureId=${placeIds?.join(',') ?? 'batch'}
employeeId=${resolvedEmpId ?? 'N/A'}
companyId=${tenantId ?? 'N/A'}
''');

        debugPrint('''
[DATA_CAPTURE_IMPORT_REQUEST]
endpoint=/data-capture/import-to-leads
method=POST
''');

        final res = await _apiClient.post(
          '/data-capture/import-to-leads',
          data: payload,
        );

        if (res.data != null) {
          final resData = res.data is Map ? res.data as Map : {};
          final dataObj = resData['data'] is Map
              ? resData['data'] as Map
              : resData;

          final rawRecords = dataObj['records'] ?? resData['records'];
          final List<ImportedRecordResult> recordResults = [];
          if (rawRecords is List) {
            for (final r in rawRecords) {
              if (r is Map) {
                recordResults.add(
                  ImportedRecordResult(
                    sourceRecordId: r['sourceRecordId']?.toString() ?? '',
                    googlePlaceId: r['googlePlaceId']?.toString(),
                    businessName: r['businessName']?.toString() ?? '',
                    imported: r['imported'] == true,
                    duplicate: r['duplicate'] == true,
                    leadId: r['leadId'] != null
                        ? int.tryParse(r['leadId'].toString())
                        : null,
                    duplicateMatchReason: r['duplicateMatchReason']?.toString(),
                  ),
                );
              }
            }
          }

          final leadId = recordResults.isNotEmpty
              ? recordResults.first.leadId?.toString()
              : 'batch';

          debugPrint('''
[DATA_CAPTURE_IMPORT_RESPONSE]
status=${res.statusCode ?? 200}
leadId=$leadId
''');

          debugPrint('''
[DATA_CAPTURE_IMPORT_RESULT]
status=SUCCESS
''');

          if (places != null) {
            for (final p in places) {
              p.isImported = true;
              p.isSelected = false;
            }
          }

          final summaryMap = Map<String, dynamic>.from(dataObj);
          summaryMap.putIfAbsent(
            'message',
            () => resData['message'] ?? 'Import completed successfully',
          );
          return ImportResultSummary.fromJson(summaryMap);
        }
      }
    } catch (e) {
      debugPrint('''
[DATA_CAPTURE_IMPORT_RESPONSE]
status=500
leadId=null
''');
      debugPrint('''
[DATA_CAPTURE_IMPORT_RESULT]
status=FAILED
''');
      debugPrint('[DATA_CAPTURE_SERVICE] Remote importToLeads failed: $e');
      if (e is DioException && e.response?.data != null) {
        debugPrint(
          '[DATA_CAPTURE_SERVICE] importToLeads error details: ${e.response?.data}',
        );
      }
      rethrow;
    }

    return _repo.importToLeads(
      jobId: jobId,
      placeIds: placeIds,
      places: places,
    );
  }

  /// Converts a single Data Capture record to a CRM Lead with authoritative backend persistence
  Future<Map<String, dynamic>> createLeadFromPlace(
    dynamic id, {
    String? captureRequestId,
    CapturedBusiness? business,
    dynamic assignedToId,
    dynamic employeeId,
  }) async {
    final resolvedEmpId =
        employeeId ?? await SecureStorageService.getEmployeeId();
    final tenantId = await SecureStorageService.getCustomerId();

    // Safe debug request logging (Section 22 of prompt)
    debugPrint('''
[DATA_CAPTURE_IMPORT]
dataCaptureId=$id
employeeId=${resolvedEmpId ?? 'N/A'}
companyId=${tenantId ?? 'N/A'}
''');

    debugPrint('''
[DATA_CAPTURE_IMPORT_REQUEST]
endpoint=/data-capture/$id/create-lead
method=POST
''');

    await _apiClient.ensureAuthLoaded();
    if (_apiClient.token == null || _apiClient.token!.isEmpty) {
      debugPrint('''
[DATA_CAPTURE_IMPORT_RESPONSE]
status=401
leadId=null
''');
      debugPrint('''
[DATA_CAPTURE_IMPORT_RESULT]
status=FAILED
''');
      throw Exception('Authentication token not found. Please log in again.');
    }

    try {
      // Send ONLY supported fields accepted by CreateLeadFromPlaceDto.
      // Backend loads the Data Capture record from DB using :id.
      final payload = <String, dynamic>{
        if (captureRequestId != null && captureRequestId.trim().isNotEmpty)
          'captureRequestId': captureRequestId.trim(),
      };

      final res = await _apiClient.post(
        '/data-capture/$id/create-lead',
        data: payload,
      );

      final resData = res.data is Map ? res.data as Map : {};
      final dataObj = resData['data'] is Map ? resData['data'] as Map : resData;
      final leadObj =
          dataObj['lead'] ??
          resData['lead'] ??
          (dataObj['id'] != null ? dataObj : null);
      final rawLeadId =
          dataObj['leadId'] ??
          resData['leadId'] ??
          (leadObj is Map ? leadObj['id'] : null);
      final leadId = rawLeadId?.toString();
      final isDup =
          resData['isDuplicate'] == true ||
          dataObj['isDuplicate'] == true ||
          (resData['message']?.toString().contains('already') == true);

      debugPrint('''
[DATA_CAPTURE_IMPORT_RESPONSE]
status=${res.statusCode ?? 200}
leadId=${leadId ?? 'N/A'}
''');

      final resultStatus = isDup
          ? 'DUPLICATE'
          : (resData['success'] == true ? 'SUCCESS' : 'FAILED');
      debugPrint('''
[DATA_CAPTURE_IMPORT_RESULT]
status=$resultStatus
''');

      if (leadObj is Map) {
        try {} catch (parseErr) {
          debugPrint('[DATA_CAPTURE_SERVICE] LeadModel parse error: $parseErr');
        }
      }

      if (business != null && (resData['success'] == true || isDup)) {
        business.isImported = true;
        business.isSelected = false;
      }

      return {
        'success': resData['success'] ?? true,
        'leadId': leadId,
        'leadModel': leadObj,
        'data': dataObj,
        'isDuplicate': isDup,
        'message':
            resData['message'] ??
            (isDup
                ? 'Lead already exists in CRM'
                : 'Lead created successfully'),
      };
    } catch (e) {
      debugPrint('''
[DATA_CAPTURE_IMPORT_RESPONSE]
status=500
leadId=null
''');
      debugPrint('''
[DATA_CAPTURE_IMPORT_RESULT]
status=FAILED
''');

      String errorMessage = 'Failed to import lead.';
      final rawErrStr = e.toString();
      if (rawErrStr.contains('message:')) {
        errorMessage = rawErrStr;
      } else {
        errorMessage = rawErrStr;
      }

      debugPrint(
        '[DATA_CAPTURE_SERVICE] createLeadFromPlace failed: $errorMessage',
      );
      throw Exception(errorMessage);
    }
  }

  /// Retrieves usage from the authenticated backend; failures remain errors.
  Future<DataCaptureUsage> getUsageSummary() async {
    await _apiClient.ensureAuthLoaded();
    final response = await _apiClient.get('/data-capture/usage');
    return DataCaptureUsage.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
