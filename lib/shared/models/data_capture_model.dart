import 'package:quickboom_crm_customer/core/network/app_url.dart';

class CapturedBusiness {
  final int? id;
  final String googlePlaceId;
  final String businessName;
  final String category;
  final String address;
  final String phone;
  final String? email;
  final String? website;
  final double? rating;
  final int? reviewCount;
  final double? latitude;
  final double? longitude;
  final String? googleMapsUrl;
  final String? sourceRecordId;
  final String? sourceUrl;
  final String? source;
  final String businessStatus;
  final DateTime capturedAt;
  final List<dynamic>? googlePhotos;
  final List<String>? photos;
  final Map<String, dynamic>? socialMedia;
  bool isSelected;
  bool isImported;

  String? get primaryPhotoUrl {
    String? raw;
    if (googlePhotos != null && googlePhotos!.isNotEmpty) {
      final first = googlePhotos!.first;
      if (first is Map && first['url'] != null) {
        raw = first['url'].toString();
      } else if (first is String) {
        raw = first;
      }
    }
    if ((raw == null || raw.isEmpty) && photos != null && photos!.isNotEmpty) {
      raw = photos!.first;
    }
    if (raw == null || raw.trim().isEmpty) return null;
    raw = raw.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('/')) {
      final base = AppUrl.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
      return '$base$raw';
    }
    return raw;
  }

  CapturedBusiness({
    this.id,
    required this.googlePlaceId,
    required this.businessName,
    required this.category,
    required this.address,
    required this.phone,
    this.email,
    this.website,
    this.rating,
    this.reviewCount,
    this.latitude,
    this.longitude,
    this.googleMapsUrl,
    this.sourceRecordId,
    this.sourceUrl,
    this.source,
    this.businessStatus = 'OPERATIONAL',
    required this.capturedAt,
    this.googlePhotos,
    this.photos,
    this.socialMedia,
    this.isSelected = true,
    this.isImported = false,
  });

  factory CapturedBusiness.fromJson(Map<String, dynamic> rawJson) {
    final json = (rawJson['data'] is Map<String, dynamic>)
        ? rawJson['data'] as Map<String, dynamic>
        : rawJson;

    final placeId =
        json['googlePlaceId']?.toString() ??
        json['sourceRecordId']?.toString() ??
        json['id']?.toString() ??
        '';

    final webUrl =
        json['website']?.toString() ?? json['websiteUri']?.toString();
    final mapUrl =
        json['googleMapsUrl']?.toString() ?? json['googleMapsUri']?.toString();

    bool isValidName(dynamic v) {
      if (v == null) return false;
      final s = v.toString().trim();
      if (s.isEmpty) return false;
      final l = s.toLowerCase();
      return l != 'business lead' &&
          l != 'unnamed business' &&
          l != 'unknown business' &&
          l != 'direct lead' &&
          l != 'new lead' &&
          l != 'null' &&
          l != 'n/a' &&
          l != 'undefined' &&
          l != '.' &&
          !s.startsWith('places/');
    }

    String resolvedBusinessName = '';
    if (isValidName(json['businessName'])) {
      resolvedBusinessName = json['businessName'].toString().trim();
    } else if (isValidName(json['companyName'])) {
      resolvedBusinessName = json['companyName'].toString().trim();
    } else if (json['displayName'] is Map &&
        isValidName(json['displayName']['text'])) {
      resolvedBusinessName = json['displayName']['text'].toString().trim();
    } else if (isValidName(json['displayName'])) {
      resolvedBusinessName = json['displayName'].toString().trim();
    } else if (isValidName(json['business_name'])) {
      resolvedBusinessName = json['business_name'].toString().trim();
    } else if (isValidName(json['company_name'])) {
      resolvedBusinessName = json['company_name'].toString().trim();
    } else if (isValidName(json['placeName'])) {
      resolvedBusinessName = json['placeName'].toString().trim();
    } else if (isValidName(json['establishmentName'])) {
      resolvedBusinessName = json['establishmentName'].toString().trim();
    } else if (isValidName(json['organizationName'])) {
      resolvedBusinessName = json['organizationName'].toString().trim();
    } else if (isValidName(json['formattedName'])) {
      resolvedBusinessName = json['formattedName'].toString().trim();
    } else if (isValidName(json['title'])) {
      resolvedBusinessName = json['title'].toString().trim();
    } else if (isValidName(json['name'])) {
      resolvedBusinessName = json['name'].toString().trim();
    } else if (json['rawData'] is Map) {
      final raw = json['rawData'] as Map;
      if (raw['displayName'] is Map &&
          isValidName(raw['displayName']['text'])) {
        resolvedBusinessName = raw['displayName']['text'].toString().trim();
      } else if (isValidName(raw['displayName'])) {
        resolvedBusinessName = raw['displayName'].toString().trim();
      } else if (isValidName(raw['businessName'])) {
        resolvedBusinessName = raw['businessName'].toString().trim();
      } else if (isValidName(raw['companyName'])) {
        resolvedBusinessName = raw['companyName'].toString().trim();
      } else if (isValidName(raw['name'])) {
        resolvedBusinessName = raw['name'].toString().trim();
      } else {
        resolvedBusinessName = '';
      }
    } else {
      resolvedBusinessName = '';
    }

    // Extract photos
    List<dynamic>? parsedGooglePhotos;
    if (json['googlePhotos'] is List) {
      parsedGooglePhotos = json['googlePhotos'] as List<dynamic>;
    } else if (json['rawData'] is Map &&
        json['rawData']['googlePhotos'] is List) {
      parsedGooglePhotos = json['rawData']['googlePhotos'] as List<dynamic>;
    }

    List<String>? parsedPhotos;
    if (json['photos'] is List) {
      parsedPhotos = (json['photos'] as List)
          .map(
            (item) =>
                item is Map ? (item['url']?.toString() ?? '') : item.toString(),
          )
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (json['rawData'] is Map && json['rawData']['photos'] is List) {
      parsedPhotos = (json['rawData']['photos'] as List)
          .map(
            (item) =>
                item is Map ? (item['url']?.toString() ?? '') : item.toString(),
          )
          .where((s) => s.isNotEmpty)
          .toList();
    }

    // Extract social media
    Map<String, dynamic>? parsedSocialMedia;
    if (json['socialMedia'] is Map) {
      parsedSocialMedia = Map<String, dynamic>.from(json['socialMedia'] as Map);
    }

    final int? dbId = json['id'] != null
        ? int.tryParse(json['id'].toString())
        : (json['dataCapturePlaceId'] != null
              ? int.tryParse(json['dataCapturePlaceId'].toString())
              : null);

    return CapturedBusiness(
      id: dbId,
      googlePlaceId: placeId,
      sourceRecordId:
          json['sourceRecordId']?.toString() ??
          (dbId != null ? dbId.toString() : placeId),
      sourceUrl: json['sourceUrl']?.toString() ?? webUrl ?? mapUrl,
      source:
          json['source']?.toString() ??
          json['sourceType']?.toString() ??
          (placeId.isNotEmpty ? 'GOOGLE_PLACES' : 'GOOGLE_DISCOVERY'),
      businessName: resolvedBusinessName,
      category:
          json['category']?.toString() ??
          json['primaryType']?.toString() ??
          'General',
      address:
          json['address']?.toString() ??
          json['formattedAddress']?.toString() ??
          '',
      phone:
          json['phone']?.toString() ?? json['phoneNumber']?.toString() ?? 'N/A',
      email: json['email']?.toString(),
      website: webUrl,
      rating: json['rating'] != null
          ? (json['rating'] as num).toDouble()
          : null,
      reviewCount: json['reviewCount'] != null
          ? (json['reviewCount'] as num).toInt()
          : (json['userRatingCount'] != null
                ? (json['userRatingCount'] as num).toInt()
                : null),
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      googleMapsUrl: mapUrl,
      businessStatus: json['businessStatus']?.toString() ?? 'OPERATIONAL',
      capturedAt: json['capturedAt'] != null
          ? DateTime.tryParse(json['capturedAt'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
                ? DateTime.tryParse(json['createdAt'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
      googlePhotos: parsedGooglePhotos,
      photos: parsedPhotos,
      socialMedia: parsedSocialMedia,
      isSelected: json['isSelected'] != false,
      isImported:
          json['isImported'] == true ||
          json['status'] == 'LEAD_CREATED' ||
          json['status'] == 'IMPORTED',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'googlePlaceId': googlePlaceId,
      'sourceRecordId': sourceRecordId ?? googlePlaceId,
      'sourceUrl': sourceUrl,
      'source': source,
      'businessName': businessName,
      'category': category,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'rating': rating,
      'reviewCount': reviewCount,
      'latitude': latitude,
      'longitude': longitude,
      'googleMapsUrl': googleMapsUrl,
      'businessStatus': businessStatus,
      'capturedAt': capturedAt.toIso8601String(),
      'isImported': isImported,
      'googlePhotos': googlePhotos,
      'photos': photos,
      'socialMedia': socialMedia,
    };
  }
}

class ExtractionJobRecord {
  final String jobId;
  final String keyword;
  final String location;
  final int requestedResults;
  final int capturedResults;
  final int googleApiRequests;
  final DateTime createdAt;
  final List<CapturedBusiness> places;

  ExtractionJobRecord({
    required this.jobId,
    required this.keyword,
    required this.location,
    required this.requestedResults,
    required this.capturedResults,
    this.googleApiRequests = 1,
    required this.createdAt,
    this.places = const [],
  });

  factory ExtractionJobRecord.fromJson(Map<String, dynamic> rawJson) {
    final json = (rawJson['data'] is Map<String, dynamic>)
        ? rawJson['data'] as Map<String, dynamic>
        : rawJson;

    var rawPlaces =
        json['places'] as List<dynamic>? ??
        json['records'] as List<dynamic>? ??
        [];
    List<CapturedBusiness> parsedPlaces = rawPlaces
        .whereType<Map<String, dynamic>>()
        .map((p) => CapturedBusiness.fromJson(p))
        .toList();

    return ExtractionJobRecord(
      jobId: json['jobId']?.toString() ?? json['id']?.toString() ?? '',
      keyword: json['keyword']?.toString() ?? json['query']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      requestedResults: json['requestedResults'] != null
          ? (json['requestedResults'] as num).toInt()
          : (json['requested'] != null
                ? (json['requested'] as num).toInt()
                : 20),
      capturedResults: json['capturedResults'] != null
          ? (json['capturedResults'] as num).toInt()
          : (json['captured'] != null
                ? (json['captured'] as num).toInt()
                : parsedPlaces.length),
      googleApiRequests: json['googleApiRequests'] != null
          ? (json['googleApiRequests'] as num).toInt()
          : 1,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      places: parsedPlaces,
    );
  }
}

class DataCaptureUsage {
  final int totalExtractions;
  final int totalLeadsCaptured;
  final int totalGoogleApiCalls;
  final int quotaLimit;
  final int quotaRemaining;
  final int searches;

  DataCaptureUsage({
    required this.totalExtractions,
    required this.totalLeadsCaptured,
    required this.totalGoogleApiCalls,
    required this.quotaLimit,
    required this.quotaRemaining,
    this.searches = 0,
  });

  factory DataCaptureUsage.fromJson(Map<String, dynamic> rawJson) {
    final json = (rawJson['data'] is Map<String, dynamic>)
        ? rawJson['data'] as Map<String, dynamic>
        : rawJson;

    return DataCaptureUsage(
      totalExtractions: json['totalExtractions'] != null
          ? (json['totalExtractions'] as num).toInt()
          : 0,
      totalLeadsCaptured: json['totalLeadsCaptured'] != null
          ? (json['totalLeadsCaptured'] as num).toInt()
          : 0,
      totalGoogleApiCalls: json['totalGoogleApiCalls'] != null
          ? (json['totalGoogleApiCalls'] as num).toInt()
          : 0,
      quotaLimit: json['quotaLimit'] != null
          ? (json['quotaLimit'] as num).toInt()
          : 1000,
      quotaRemaining: json['quotaRemaining'] != null
          ? (json['quotaRemaining'] as num).toInt()
          : 1000,
      searches: json['searches'] != null
          ? (json['searches'] as num).toInt()
          : (json['totalSearches'] != null
                ? (json['totalSearches'] as num).toInt()
                : 0),
    );
  }

  factory DataCaptureUsage.initial() {
    return DataCaptureUsage(
      totalExtractions: 0,
      totalLeadsCaptured: 0,
      totalGoogleApiCalls: 0,
      quotaLimit: 1000,
      quotaRemaining: 1000,
      searches: 0,
    );
  }
}

class ImportedRecordResult {
  final String? sourceRecordId;
  final String? googlePlaceId;
  final String businessName;
  final bool imported;
  final int? leadId;
  final bool duplicate;
  final int? existingLeadId;
  final String? duplicateMatchReason;

  const ImportedRecordResult({
    this.sourceRecordId,
    this.googlePlaceId,
    required this.businessName,
    required this.imported,
    this.leadId,
    required this.duplicate,
    this.existingLeadId,
    this.duplicateMatchReason,
  });

  factory ImportedRecordResult.fromJson(Map<String, dynamic> json) {
    return ImportedRecordResult(
      sourceRecordId: json['sourceRecordId']?.toString(),
      googlePlaceId: json['googlePlaceId']?.toString(),
      businessName: json['businessName']?.toString() ?? '',
      imported: json['imported'] == true,
      leadId: json['leadId'] != null ? (json['leadId'] as num).toInt() : null,
      duplicate: json['duplicate'] == true,
      existingLeadId: json['existingLeadId'] != null
          ? (json['existingLeadId'] as num).toInt()
          : null,
      duplicateMatchReason: json['duplicateMatchReason']?.toString(),
    );
  }
}

class ImportResultSummary {
  final int totalRequested;
  final int imported;
  final int skippedDuplicates;
  final List<String> duplicateNames;
  final List<ImportedRecordResult> records;
  final String message;
  final Map<String, dynamic>? lead;
  final List<dynamic>? leads;

  ImportResultSummary({
    required this.totalRequested,
    required this.imported,
    required this.skippedDuplicates,
    this.duplicateNames = const [],
    this.records = const [],
    required this.message,
    this.lead,
    this.leads,
  });

  factory ImportResultSummary.fromJson(Map<String, dynamic> rawJson) {
    final Map<String, dynamic> json = Map<String, dynamic>.from(rawJson);
    if (rawJson['data'] is Map) {
      final inner = Map<String, dynamic>.from(rawJson['data'] as Map);
      inner.forEach((k, v) => json.putIfAbsent(k, () => v));
    }

    var rawDuplicates = json['duplicateNames'] as List<dynamic>? ?? [];
    var rawRecords = json['records'] as List<dynamic>? ?? [];
    final parsedRecords = rawRecords
        .whereType<Map>()
        .map((r) => ImportedRecordResult.fromJson(Map<String, dynamic>.from(r)))
        .toList();

    final parsedImported = json['imported'] != null
        ? (json['imported'] as num).toInt()
        : (json['importedCount'] != null
              ? (json['importedCount'] as num).toInt()
              : parsedRecords.where((r) => r.imported).length);

    final parsedDuplicates = json['skippedDuplicates'] != null
        ? (json['skippedDuplicates'] as num).toInt()
        : parsedRecords.where((r) => r.duplicate).length;

    return ImportResultSummary(
      totalRequested: json['totalRequested'] != null
          ? (json['totalRequested'] as num).toInt()
          : (json['total'] != null
                ? (json['total'] as num).toInt()
                : (parsedImported + parsedDuplicates)),
      imported: parsedImported,
      skippedDuplicates: parsedDuplicates,
      duplicateNames: rawDuplicates.map((e) => e.toString()).toList(),
      records: parsedRecords,
      message: json['message']?.toString() ?? 'Import complete',
      lead: json['lead'] is Map
          ? Map<String, dynamic>.from(json['lead'] as Map)
          : null,
      leads: json['leads'] is List ? json['leads'] as List : null,
    );
  }
}
