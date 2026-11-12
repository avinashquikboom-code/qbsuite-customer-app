import 'dart:convert';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import 'package:flutter/foundation.dart';
import '../models/lead_model.dart';
import '../models/lead_stage_model.dart';
import '../models/lead_status_update_result.dart';

class LeadPage {
  final List<LeadModel> leads;
  final int page;
  final int total;
  final int totalPages;
  final Map<String, int> counts;
  final int? durationMs;

  const LeadPage({
    required this.leads,
    required this.page,
    required this.total,
    required this.totalPages,
    this.counts = const {},
    this.durationMs,
  });
}

class LeadService {
  final ApiClient? _apiClient;
  final Map<int, LeadPage> _pages = {};
  int _pageToken = 0;
  Map<int, List<String>>? _photosByLead;
  Map<String, List<String>>? _photosByPlace;
  DateTime? _photosLoadedAt;

  bool _missingImage(Map item) {
    final url = item['imageUrl']?.toString() ?? '';
    final images = item['images'];
    return url.isEmpty && (images is! List || images.isEmpty);
  }

  String? _capturePhoto(dynamic item) {
    final url = item is String
        ? item
        : (item is Map ? item['url']?.toString() ?? '' : '');
    final name = item is Map
        ? '${item['name'] ?? item['photoReference'] ?? ''}'
        : '';
    if (RegExp(
      r'unsplash|pexels|placeholder|dummy|sample',
      caseSensitive: false,
    ).hasMatch('$url $name')) {
      return null;
    }
    if (url.startsWith('/api/v1/data-capture/photo')) return url;
    if (RegExp(
      r'^places\/[^/]+\/photos\/(?!\d{1,3}$)[^/?&]+$',
    ).hasMatch(name)) {
      return '/api/v1/data-capture/photo?ref=${Uri.encodeComponent(name)}';
    }
    if (url.startsWith('https://lh3.googleusercontent.com/')) {
      return '/api/v1/data-capture/photo?ref=${Uri.encodeComponent(url)}';
    }
    if (url.contains('AIzaSy') || url.contains('places.googleapis.com'))
      return null;
    if (url.startsWith('https://') ||
        url.startsWith('http://') ||
        url.startsWith('/uploads/'))
      return url;
    return null;
  }

  Future<void> _attachCapturePhotos(Map<String, dynamic> item) async {
    if (_apiClient == null || !_missingImage(item)) return;
    final fresh =
        _photosLoadedAt != null &&
        DateTime.now().difference(_photosLoadedAt!).inMinutes < 2;
    if (!fresh) {
      final byLead = <int, List<String>>{};
      final byPlace = <String, List<String>>{};
      try {
        for (var page = 1; page <= 8; page++) {
          final res = await _apiClient.get(
            '/data-capture',
            queryParameters: {'page': page, 'limit': 100},
          );
          final raw = res.data;
          final payload = raw is Map && raw['data'] is Map ? raw['data'] : raw;
          final rows = payload is List
              ? payload
              : payload is Map
              ? payload['data'] ?? payload['items']
              : null;
          if (rows is! List || rows.isEmpty) break;
          for (final row in rows.whereType<Map>()) {
            final photos = <String>[];
            final stored = <dynamic>[
              if (row['googlePhotos'] is List) ...row['googlePhotos'] as List,
              if (row['photos'] is List) ...row['photos'] as List,
            ];
            for (final photo in stored) {
              final url = _capturePhoto(photo);
              if (url != null && !photos.contains(url)) photos.add(url);
            }
            if (photos.isEmpty) continue;
            final leadId = int.tryParse('${row['importedLeadId']}');
            if (leadId != null) byLead[leadId] = photos;
            final placeId = row['googlePlaceId']?.toString() ?? '';
            if (placeId.isNotEmpty && !placeId.startsWith('custom_'))
              byPlace[placeId] = photos;
          }
          final pageInfo = payload is Map
              ? payload['pagination'] ?? payload['meta']
              : null;
          final pages = pageInfo is Map ? pageInfo['totalPages'] : null;
          if (pages is num && page >= pages) break;
        }
      } catch (_) {
        _photosByLead = {};
        _photosByPlace = {};
        _photosLoadedAt = DateTime.now();
        return;
      }
      _photosByLead = byLead;
      _photosByPlace = byPlace;
      _photosLoadedAt = DateTime.now();
    }
    final leadId = int.tryParse('${item['id']}');
    final placeId = item['googlePlaceId']?.toString();
    final byLead = _photosByLead;
    final byPlace = _photosByPlace;
    final photos =
        (leadId != null && byLead != null ? byLead[leadId] : null) ??
        (placeId != null && byPlace != null ? byPlace[placeId] : null);
    if (photos == null || photos.isEmpty) return;
    item['imageUrl'] = photos.first;
    item['images'] = photos
        .map((url) => {'url': url, 'source': 'GOOGLE_PLACES'})
        .toList();
  }

  /// Looks up persisted capture photos for leads missing a primary image.
  /// The backend photo proxy hydrates Places images when they are not stored yet.
  Future<List<LeadModel>> mergeCapturePhotos(List<LeadModel> leads) async {
    final missing = leads.where((lead) {
      final placeId = lead.googlePlaceId ?? '';
      return (lead.imageUrl ?? '').isEmpty &&
          placeId.isNotEmpty &&
          !placeId.startsWith('custom_');
    }).toList();
    if (missing.isEmpty || _apiClient == null) return leads;

    final output = List<LeadModel>.from(leads);
    for (final lead in missing) {
      final encodedPlaceId = Uri.encodeComponent(lead.googlePlaceId!);
      // This endpoint resolves by place ID using the tenant's configured Maps key.
      final url =
          '${_apiClient!.dio.options.baseUrl}/data-capture/places/$encodedPlaceId/photo';
      final index = output.indexWhere((item) => item.id == lead.id);
      if (index >= 0) {
        output[index] = lead.copyWith(imageUrl: url, images: [url]);
      }
    }
    return output;
  }

  LeadService([this._apiClient]);

  /// One server page. The list screen uses this so opening Leads does not
  /// download every later page before the first cards can render.
  Future<LeadPage> getLeadPage({
    String? status,
    int? stageId,
    String? search,
    String? source,
    String? category,
    int? assignedToId,
    String? from,
    String? to,
    int page = 1,
    int limit = 20,
    bool includeCounts = false,
  }) async {
    final token = ++_pageToken;
    final leads = await getLeads(
      status: status,
      stageId: stageId,
      search: search,
      source: source,
      category: category,
      assignedToId: assignedToId,
      from: from,
      to: to,
      page: page,
      limit: limit,
      allPages: false,
      includeCounts: includeCounts,
      pageToken: token,
    );
    return _pages.remove(token) ??
        LeadPage(leads: leads, page: page, total: leads.length, totalPages: 1);
  }

  /// Fetch all configured pipeline stages from backend GET /leads/stages.
  Future<List<LeadStageModel>> getStages() async {
    if (_apiClient == null) throw StateError('API Client unavailable');
    final res = await _apiClient.get(
      '/leads/stages',
      queryParameters: const {'includeInactive': 'false'},
    );
    final items = _stageItems(res.data);
    if (items == null) {
      throw const FormatException('Invalid pipeline stages response');
    }
    final stages = <LeadStageModel>[];
    final seenIds = <int>{};
    for (final item in items) {
      if (item is! Map) continue;
      final stage = LeadStageModel.fromJson(Map<String, dynamic>.from(item));
      if (stage.id <= 0 || stage.name.trim().isEmpty || !seenIds.add(stage.id))
        continue;
      stages.add(stage);
    }
    stages.sort(
      (a, b) => a.sortOrder.compareTo(b.sortOrder) == 0
          ? a.id.compareTo(b.id)
          : a.sortOrder.compareTo(b.sortOrder),
    );
    return stages;
  }

  List<dynamic>? _stageItems(dynamic raw) {
    if (raw is List) return raw;
    if (raw is! Map) return null;
    if (raw['success'] == false) {
      throw FormatException(
        raw['message']?.toString() ?? 'Lead stages could not be loaded',
      );
    }
    final data = raw['data'];
    if (data is List) return data;
    if (data is Map) {
      if (data['stages'] is List) return data['stages'] as List;
      if (data['items'] is List) return data['items'] as List;
      if (data['data'] is List) return data['data'] as List;
    }
    if (raw['stages'] is List) return raw['stages'] as List;
    if (raw['items'] is List) return raw['items'] as List;
    return null;
  }

  /// Fetch paginated leads from GET /leads.
  Future<List<LeadModel>> getLeads({
    String? status,
    int? stageId,
    String? search,
    String? source,
    String? category,
    int? assignedToId,
    String? from,
    String? to,
    int page = 1,
    int limit = 50,
    bool allPages = true,
    bool includeCounts = false,
    int? pageToken,
  }) async {
    if (_apiClient == null) throw StateError('API Client unavailable');
    final leads = <LeadModel>[];
    final seen = <String>{};
    var currentPage = page;
    var totalPages = page;
    do {
      final stopwatch = Stopwatch()..start();
      final res = await _apiClient.get(
        '/leads',
        queryParameters: {
          'page': currentPage,
          'limit': limit,
          if (stageId != null) 'stageId': stageId,
          if (stageId == null &&
              status != null &&
              status.isNotEmpty &&
              status != 'ALL')
            'status': status,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          if (source != null && source.trim().isNotEmpty)
            'source': source.trim(),
          if (category != null && category.trim().isNotEmpty)
            'category': category.trim(),
          if (assignedToId != null) 'assignedToId': assignedToId,
          if (from != null && from.isNotEmpty) 'from': from,
          if (to != null && to.isNotEmpty) 'to': to,
          if (includeCounts && currentPage == page) 'includeCounts': 'true',
        },
      );
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint(
          '[LEADS_TIMING] page=$currentPage ms=${stopwatch.elapsedMilliseconds} decodedBytes=${utf8.encode(jsonEncode(res.data)).length}',
        );
      }
      final raw = res.data;
      final payload = raw is Map && raw['data'] is Map ? raw['data'] : raw;
      final dynamic items = payload is List
          ? payload
          : payload is Map
          ? payload['data'] ?? payload['items']
          : null;
      if (items is! List) {
        throw const FormatException('Invalid lead list response');
      }
      if (kDebugMode) {
        debugPrint(
          '[LEADS_RESPONSE] endpoint=/leads page=$currentPage '
          'limit=$limit status=${status ?? 'ALL'} '
          'hasSearch=${search?.trim().isNotEmpty == true} '
          'httpStatus=${res.statusCode} returned=${items.length} '
          'total=${payload is Map ? payload['total'] : null} '
          'records=${items.whereType<Map>().map((item) => {'id': item['id'], 'assignedToId': item['assignedToId'], 'status': item['status'], 'stageId': item['stageId']}).toList()}',
        );
      }
      for (final item in items) {
        final json = Map<String, dynamic>.from(item as Map);
        final lead = LeadModel.fromJson(json);
        if (lead.id.isEmpty) throw const FormatException('Lead ID is missing');
        if (seen.add(lead.id)) leads.add(lead);
      }
      final dynamic pagination = payload is Map
          ? payload['pagination'] ??
                payload['meta'] ??
                (raw is Map ? raw['pagination'] ?? raw['meta'] : null)
          : raw is Map
          ? raw['pagination'] ?? raw['meta']
          : null;
      final dynamic pages = pagination is Map
          ? pagination['totalPages']
          : payload is Map
          ? payload['totalPages']
          : null;
      if (pages != null) {
        if (pages is! num ||
            !pages.isFinite ||
            pages.toInt() != pages ||
            pages < 0) {
          throw const FormatException('Invalid lead pagination');
        }
        totalPages = pages.toInt();
      }
      if (!allPages && pageToken != null) {
        final counts = <String, int>{};
        final rawCounts = pagination is Map ? pagination['counts'] : null;
        if (rawCounts is List) {
          var totalCount = 0;
          for (final row in rawCounts.whereType<Map>()) {
            final count = (row['count'] as num?)?.toInt() ?? 0;
            totalCount += count;
            final statusKey = row['status']?.toString().toUpperCase();
            if (statusKey != null && statusKey.isNotEmpty) {
              counts[statusKey] = (counts[statusKey] ?? 0) + count;
            }
            final stageKey = row['stageId']?.toString();
            if (stageKey != null && stageKey.isNotEmpty && stageKey != 'null') {
              counts[stageKey] = (counts[stageKey] ?? 0) + count;
            }
          }
          counts[''] = totalCount;
          counts['ALL'] = totalCount;
        }
        _pages[pageToken] = LeadPage(
          leads: leads,
          page: currentPage,
          total: pagination is Map && pagination['total'] is num
              ? (pagination['total'] as num).toInt()
              : leads.length,
          totalPages: totalPages,
          counts: counts,
          durationMs: pagination is Map && pagination['durationMs'] is num
              ? (pagination['durationMs'] as num).toInt()
              : null,
        );
      }
      currentPage++;
    } while (allPages && currentPage <= totalPages);
    return leads;
  }

  /// Get lead details by ID from GET /leads/$id.
  Future<LeadModel> getLeadById(String id) async {
    if (_apiClient != null) {
      final res = await _apiClient.get('/leads/$id');
      final raw = res.data;
      final map = (raw is Map && raw['data'] is Map)
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
      await _attachCapturePhotos(map);
      return LeadModel.fromJson(map);
    }
    throw Exception('API Client unavailable');
  }

  /// Update lead stage / status with the registered PATCH /leads/$id/status.
  Future<LeadStatusUpdateResult> updateStatus(
    String id, {
    required String status,
    int? stageId,
    String? notes,
  }) async {
    if (_apiClient != null) {
      final payload = <String, dynamic>{
        'status': status,
        if (stageId != null) 'stageId': stageId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      final res = await _apiClient.patch('/leads/$id/status', data: payload);
      final raw = res.data;
      final root = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final result = LeadStatusUpdateResult.fromApiResponse(root);
      final updated = result.lead;
      String norm(String value) =>
          value.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
      final requestedKey = norm(status);
      final returnedKey = norm(updated.stage?.key ?? '');
      final returnedStatus = norm(updated.status);
      final savedId = updated.id == id;
      final savedStage = stageId != null && updated.stageId == stageId;
      final savedKey = returnedKey.isNotEmpty && returnedKey == requestedKey;
      final savedLegacyStatus = returnedStatus == requestedKey;
      // stageId is authoritative. A dynamic stage may keep the previous legacy status.
      final accepted = stageId != null
          ? savedStage || savedKey
          : savedLegacyStatus || savedKey;
      if (!savedId || !accepted) {
        throw FormatException(
          'Stage update response does not match the saved Lead (stageId ${updated.stageId}, status ${updated.status}, stage ${updated.stage?.key ?? 'none'})',
        );
      }
      return result;
    }
    throw Exception('API Client unavailable');
  }

  /// Soft-delete one lead with DELETE /leads/:id, or several with DELETE /leads/bulk.
  Future<void> deleteLeads(List<String> ids) async {
    if (_apiClient == null) throw Exception('API Client unavailable');
    final numbers = ids
        .map(int.tryParse)
        .whereType<int>()
        .where((id) => id > 0)
        .toList();
    if (numbers.isEmpty) throw Exception('Select a lead to delete');
    if (numbers.length == 1) {
      await _apiClient.delete('/leads/${numbers.first}');
      return;
    }
    await _apiClient.delete('/leads/bulk', data: {'ids': numbers});
  }

  /// Create lead with POST /leads.
  Future<LeadModel> createLead(Map<String, dynamic> data) async {
    if (_apiClient != null) {
      final res = await _apiClient.post('/leads', data: data);
      final raw = res.data;
      final map = (raw is Map && raw['data'] is Map)
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
      return LeadModel.fromJson(map);
    }
    throw Exception('API Client unavailable');
  }

  /// Update lead fields with PATCH /leads/:id.
  Future<LeadModel> updateLead(String id, Map<String, dynamic> data) async {
    if (_apiClient == null) throw Exception('API Client unavailable');
    final res = await _apiClient.patch('/leads/$id', data: data);
    final raw = res.data;
    final map = (raw is Map && raw['data'] is Map)
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
    await _attachCapturePhotos(map);
    return LeadModel.fromJson(map);
  }

  /// Add a note to lead with POST /leads/:id/notes.
  Future<Map<String, dynamic>> addNote(String id, String content) async {
    if (_apiClient != null) {
      final res = await _apiClient.post(
        '/leads/$id/notes',
        data: {'content': content.trim()},
      );
      final raw = res.data;
      return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    }
    throw StateError('API Client unavailable');
  }

  /// Get notes for lead with GET /leads/:id/notes.
  Future<List<Map<String, dynamic>>> getNotes(String id) async {
    if (_apiClient != null) {
      final res = await _apiClient.get('/leads/$id/notes');
      final raw = res.data;
      final payload = raw is Map && raw['data'] is Map ? raw['data'] : raw;
      final dynamic items = payload is List
          ? payload
          : payload is Map
          ? payload['data'] ?? payload['notes']
          : null;
      if (items is List) {
        return items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    }
    throw StateError('API Client unavailable');
  }

  /// Manage field visit: schedule, start, or complete via POST /leads/:id/visits
  Future<LeadModel> manageVisit(
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
    if (_apiClient != null) {
      final payload = <String, dynamic>{
        'action': action,
        if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
        if (date != null && date.isNotEmpty) 'date': date,
        if (time != null && time.isNotEmpty) 'time': time,
        if (location != null && location.isNotEmpty) 'location': location,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (employeeId != null) 'employeeId': employeeId,
      };

      final res = await _apiClient.post('/leads/$id/visits', data: payload);
      final raw = res.data;
      final map = (raw is Map && raw['data'] is Map)
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
      return LeadModel.fromJson(map);
    }
    throw StateError('API Client unavailable');
  }
}
