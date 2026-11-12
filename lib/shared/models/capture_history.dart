import 'dart:convert';

class CaptureHistorySession {
  final String jobId, keyword, location;
  final DateTime createdAt;
  final int captured;
  final int? found;
  final String? status;

  CaptureHistorySession({
    required this.jobId,
    required this.keyword,
    required this.location,
    required this.createdAt,
    required this.captured,
    this.found,
    this.status,
  });

  factory CaptureHistorySession.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final rawDate = json['createdAt'] ?? json['created_at'];
    if (rawDate is DateTime) {
      parsedDate = rawDate.toLocal();
    } else if (rawDate is String && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final rawCaptured = json['capturedResults'] ?? json['captured'] ?? json['captured_results'];
    final captured = rawCaptured is num
        ? rawCaptured.toInt()
        : (int.tryParse(rawCaptured?.toString() ?? '') ?? 0);

    final rawFound = json['foundResults'] ?? json['found'] ?? json['found_results'];
    final found = rawFound is num
        ? rawFound.toInt()
        : (rawFound != null ? int.tryParse(rawFound.toString()) : null);

    return CaptureHistorySession(
      jobId: json['jobId']?.toString() ?? json['id']?.toString() ?? '',
      keyword: json['keyword']?.toString() ?? json['query']?.toString() ?? json['search']?.toString() ?? '',
      location: json['location']?.toString() ?? json['city']?.toString() ?? '',
      createdAt: parsedDate,
      captured: captured,
      found: found,
      status: json['captureStatus']?.toString() ?? json['status']?.toString(),
    );
  }

  String get statusLabel {
    final s = status?.toUpperCase().trim();
    return switch (s) {
      'COMPLETED' => 'Completed',
      'FAILED' => 'Failed',
      'PARTIALLY_COMPLETED' => 'Partially Completed',
      _ => 'Status unavailable (older session)',
    };
  }
}

class CaptureHistoryPage {
  final List<CaptureHistorySession> sessions;
  final int page, totalPages;
  final int total;

  CaptureHistoryPage({
    required this.sessions,
    required this.page,
    required this.totalPages,
    this.total = 0,
  });

  factory CaptureHistoryPage.fromJson(dynamic raw) {
    dynamic payload = raw;
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } catch (e) {
        throw FormatException('Invalid capture history JSON: $e');
      }
    }

    if (payload is! Map) {
      if (payload is List) {
        final list = payload
            .whereType<Map>()
            .map((e) => CaptureHistorySession.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        return CaptureHistoryPage(
          sessions: list,
          page: 1,
          totalPages: 1,
          total: list.length,
        );
      }
      throw const FormatException('Invalid capture history response');
    }

    final map = Map<String, dynamic>.from(payload);
    if (map['success'] == false) {
      final msg = map['message']?.toString() ?? 'Data Capture request failed';
      throw StateError(msg);
    }

    dynamic rawList;
    if (map['data'] is List) {
      rawList = map['data'];
    } else if (map['data'] is Map) {
      final nested = map['data'] as Map;
      rawList = nested['data'] ?? nested['items'] ?? nested['sessions'] ?? nested['records'] ?? [];
    } else if (map['items'] is List) {
      rawList = map['items'];
    } else if (map['sessions'] is List) {
      rawList = map['sessions'];
    } else if (map['records'] is List) {
      rawList = map['records'];
    } else {
      rawList = [];
    }

    final sessions = (rawList is List)
        ? rawList
            .whereType<Map>()
            .map((e) => CaptureHistorySession.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <CaptureHistorySession>[];

    Map<String, dynamic>? pagination;
    if (map['pagination'] is Map) {
      pagination = Map<String, dynamic>.from(map['pagination'] as Map);
    } else if (map['data'] is Map && (map['data'] as Map)['pagination'] is Map) {
      pagination = Map<String, dynamic>.from((map['data'] as Map)['pagination'] as Map);
    } else if (map['meta'] is Map) {
      pagination = Map<String, dynamic>.from(map['meta'] as Map);
    }

    final page = pagination?['page'] is num
        ? (pagination!['page'] as num).toInt()
        : (int.tryParse(pagination?['page']?.toString() ?? '') ??
            int.tryParse(map['page']?.toString() ?? '') ??
            1);

    final total = pagination?['total'] is num
        ? (pagination!['total'] as num).toInt()
        : (int.tryParse(pagination?['total']?.toString() ?? '') ??
            int.tryParse(map['total']?.toString() ?? '') ??
            sessions.length);

    final totalPages = pagination?['totalPages'] is num
        ? (pagination!['totalPages'] as num).toInt()
        : (int.tryParse(pagination?['totalPages']?.toString() ?? '') ??
            int.tryParse(map['totalPages']?.toString() ?? '') ??
            (total > 0 ? (total / 20).ceil() : 1));

    return CaptureHistoryPage(
      sessions: sessions,
      page: page < 1 ? 1 : page,
      totalPages: totalPages < 1 ? 1 : totalPages,
      total: total,
    );
  }
}
