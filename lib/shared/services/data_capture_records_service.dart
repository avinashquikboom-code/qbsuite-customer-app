import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../core/network/app_url.dart';
import '../models/data_capture_record.dart';
import 'lead_service.dart';

/// Saved-record operations; authentication and tenant headers use ApiClient.
class DataCaptureRecordsService {
  final ApiClient _client;
  DataCaptureRecordsService([ApiClient? client])
    : _client = client ?? ApiClient();

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    await _client.ensureAuthLoaded();
    final Response response;
    switch (method) {
      case 'POST':
        response = await _client.post(path, data: body);
        break;
      case 'PATCH':
        response = await _client.patch(path, data: body);
        break;
      case 'DELETE':
        response = await _client.delete(path);
        break;
      default:
        response = await _client.get(path, queryParameters: query);
    }
    final result = Map<String, dynamic>.from(response.data as Map);
    if (result['success'] == false) {
      throw StateError(result['message'] is List
          ? (result['message'] as List).join('\n')
          : result['message']?.toString() ?? 'Data Capture request failed');
    }
    if (kDebugMode) {
      debugPrint(
        '[DATA_CAPTURE_API] method=$method API=$path '
        'params=${query?.keys.toList()} requestFields=${body?.keys.toList()} '
        'statusCode=${response.statusCode} '
        'records=${result['data'] is List ? (result['data'] as List).length : 1}',
      );
    }
    return result;
  }

  Future<DataCapturePage> list({
    int page = 1,
    int limit = 20,
    String search = '',
    String status = 'ALL',
    String source = 'ALL',
    String category = '',
    String? jobId,
    bool fromHistory = false,
  }) async => DataCapturePage.fromJson(
    await _request(
      'GET',
      AppUrl.dataCapture,
      query: {
        'page': page,
        'limit': limit,
        'search': search,
        'status': status,
        'source': source,
        'category': category,
        if (jobId != null) 'jobId': jobId,
      },
    ),
  );

  /// Reuses the existing validated-record import endpoint and its per-record results.
  Future<Map<String, dynamic>> importSelected(List<int> ids) async {
    final selectedIds = ids.toSet();
    if (selectedIds.isEmpty || selectedIds.any((id) => id < 1)) {
      throw ArgumentError('Select valid captured records');
    }
    // Match the existing extraction client's import contract. The API resolves
    // placeIds as saved Data Capture IDs, for both single and bulk imports.
    final payload = {
      'placeIds': selectedIds.map((id) => id.toString()).toList(),
    };
    if (kDebugMode) {
      debugPrint('[DATA_CAPTURE_IMPORT_REQUEST] '
          'endpoint=${AppUrl.dataCapture}/import-to-leads payload=$payload');
    }
    var result = await _request(
      'POST',
      '${AppUrl.dataCapture}/import-to-leads',
      body: payload,
    );
    while (result['data'] is Map) {
      result = Map<String, dynamic>.from(result['data'] as Map);
      if (result['success'] == false) {
        throw StateError(result['message'] is List
            ? (result['message'] as List).join('\n')
            : result['message']?.toString() ?? 'Import failed');
      }
    }
    if (kDebugMode) {
      debugPrint('[DATA_CAPTURE_IMPORT_CONTRACT] '
          'importedType=${result['imported'].runtimeType} '
          'importedCountType=${result['importedCount'].runtimeType} '
          'alreadyImportedType=${result['alreadyImported'].runtimeType} '
          'recordsType=${result['records'].runtimeType}');
    }
    // Older deployed responses omit per-record outcomes. Verify persisted links
    // with read-only requests rather than retrying the POST or assuming success.
    if (!result.containsKey('imported') || !result.containsKey('importedCount')) {
      final imported = <Map<String, dynamic>>[];
      final failed = <Map<String, dynamic>>[];
      for (final id in selectedIds) {
        final capture = await detail(id);
        final leadId = int.tryParse(capture.fields['importedLeadId'].toString());
        if (leadId == null || leadId < 1) {
          failed.add({'captureId': id, 'reason':
              result['message']?.toString() ?? 'No persisted Lead link was returned for this record.'});
          continue;
        }
        final lead = await LeadService(_client).getLeadById(leadId.toString());
        if (lead.id != leadId.toString()) {
          throw const FormatException('Unable to verify the imported Lead');
        }
        imported.add({'captureId': id, 'leadId': leadId});
      }
      result = {
        'imported': imported, 'importedCount': imported.length,
        'alreadyImported': <Map<String, dynamic>>[], 'alreadyImportedCount': 0,
        'skipped': <Map<String, dynamic>>[], 'skippedCount': 0,
        'failed': failed, 'failedCount': failed.length,
      };
    }
    final returnedIds = <int>{};
    for (final entry in const {
      'imported': 'importedCount',
      'alreadyImported': 'alreadyImportedCount',
      'skipped': 'skippedCount',
      'failed': 'failedCount',
    }.entries) {
      final count = result[entry.value];
      final records = result[entry.key];
      if (count is! int ||
          count < 0 ||
          records is! List ||
          records.length != count) {
        throw const FormatException('Invalid import result');
      }
      for (final record in records) {
        final id = record is Map
            ? int.tryParse(record['captureId'].toString())
            : null;
        if (entry.key == 'imported' || entry.key == 'alreadyImported') {
          final leadId = record is Map
              ? int.tryParse(record['leadId'].toString())
              : null;
          if (leadId == null || leadId < 1) {
            throw const FormatException('Import result is missing a Lead ID');
          }
        }
        if (id == null || !selectedIds.contains(id) || !returnedIds.add(id)) {
          throw const FormatException(
            'Import result does not match selected records',
          );
        }
      }
    }
    if (returnedIds.length != selectedIds.length) {
      throw const FormatException('Incomplete import result');
    }
    return result;
  }

  Future<DataCaptureRecord> detail(int id) async => DataCaptureRecord.fromJson(
    Map<String, dynamic>.from(
      (await _request('GET', '${AppUrl.dataCapture}/$id'))['data'],
    ),
  );
  Future<void> create(Map<String, dynamic> fields) async {
    await _request(
      'POST',
      AppUrl.dataCapture,
      body: {...fields, 'createdFrom': 'MOBILE_APP'},
    );
  }

  Future<void> update(int id, Map<String, dynamic> fields) async {
    await _request('PATCH', '${AppUrl.dataCapture}/$id', body: fields);
  }

  Future<void> delete(int id) async {
    await _request('DELETE', '${AppUrl.dataCapture}/$id');
  }

  Future<void> status(int id, String action, {String? reason}) async {
    await _request(
      'POST',
      '${AppUrl.dataCapture}/$id/$action',
      body: {if (reason != null) 'reason': reason},
    );
  }
}

String dataCaptureError(Object error) {
  if (kDebugMode) {
    debugPrint('[DATA_CAPTURE_ERROR_DETAILS] ${error.runtimeType}: $error');
  }

  if (error is DioException) {
    final status = error.response?.statusCode;

    // 1. Unauthorized / Session Expired
    if (status == 401) return 'Please sign in again.';

    // 2. Forbidden / Permission Denied
    if (status == 403) return 'You do not have permission for this action.';

    // 3. Not Found
    if (status == 404) return 'This record is no longer available.';

    // 4. Network / Connection Errors
    if (status == null ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Unable to connect. Check your connection and retry.';
    }

    // 5. Server Errors (500+)
    if (status >= 500) {
      return 'Data Capture is unavailable. Please retry.';
    }

    // 6. Validation / Client Errors (400, 422, etc.)
    dynamic body = error.response?.data;
    if (body is String && body.trim().startsWith('{')) {
      try {
        body = jsonDecode(body);
      } catch (_) {}
    }
    if (body is Map) {
      final message = body['message'] ?? body['errors'] ?? body['errorDetails'];
      if (message is List && message.isNotEmpty) {
        return message.map((m) => m.toString()).join('\n');
      }
      if (message is String && message.isNotEmpty && message.length < 250) {
        return message;
      }
    }
  }

  // 7. Parsing & Format Errors
  if (error is FormatException) {
    return 'Unable to process server data. Please retry.';
  }
  if (error is TypeError) {
    return 'Data format mismatch. Please retry.';
  }

  // 8. StateError (e.g. backend response success: false)
  if (error is StateError && error.message.isNotEmpty) {
    return error.message;
  }

  return 'Unable to complete the Data Capture request. Please retry.';
}
