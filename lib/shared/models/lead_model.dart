import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import 'lead_stage_model.dart';
import 'social_media_model.dart';

class LeadModel {
  final String id;
  final String companyName;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final String? website;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? pincode;
  final String? category;
  final String? googlePlaceId;
  final double? latitude;
  final double? longitude;
  final String source;
  final String createdFrom;
  final String status;
  final int? stageId;
  final LeadStageModel? stage;
  final String? notes;
  final String? priority;
  final double? value;
  final String? nextFollowUpDate;
  final String? nextFollowUpTime;
  final String? workStartDate;
  final String? workNotes;
  final String? assignedTeam;
  final int? assignedToId;
  final String? assignedToName;
  final String? createdAt;
  final dynamic socialMedia;
  final List<LeadVisitModel> visits;
  final String? visitStatus;
  final String? visitScheduledAt;
  final int? assignedVisitorId;
  final String? imageUrl;
  final List<String> images;
  final List<String> photoCredits;

  const LeadModel({
    required this.id,
    required this.companyName,
    this.firstName,
    this.lastName,
    this.phone,
    this.email,
    this.website,
    this.address,
    this.city,
    this.state,
    this.country,
    this.pincode,
    this.category,
    this.googlePlaceId,
    this.latitude,
    this.longitude,
    required this.source,
    required this.createdFrom,
    required this.status,
    this.stageId,
    this.stage,
    this.notes,
    this.priority,
    this.value,
    this.nextFollowUpDate,
    this.nextFollowUpTime,
    this.workStartDate,
    this.workNotes,
    this.assignedTeam,
    this.assignedToId,
    this.assignedToName,
    this.createdAt,
    this.socialMedia,
    this.visits = const [],
    this.visitStatus,
    this.visitScheduledAt,
    this.assignedVisitorId,
    this.imageUrl,
    this.images = const [],
    this.photoCredits = const [],
  });

  String get displayName => companyName.isNotEmpty ? companyName : fullName;
  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return parts.isEmpty ? 'L' : parts;
  }

  LeadVisitModel? get nextScheduledVisit {
    for (final visit in visits) {
      final status = visit.status.toUpperCase();
      if (status == 'SCHEDULED' || status == 'IN_PROGRESS') return visit;
    }
    final status = (visitStatus ?? '').toUpperCase();
    if (status == 'SCHEDULED' || status == 'IN_PROGRESS') {
      return LeadVisitModel(
        id: '',
        customerName: displayName,
        purpose: 'Field Visit',
        date: visitScheduledAt ?? '',
        location: [address, city].where((part) => part != null && part.isNotEmpty).join(', '),
        status: status,
        createdAt: '',
        assignedEmployee: assignedToName,
        employeeId: assignedVisitorId,
      );
    }
    return null;
  }
  String get fullName => [
    firstName,
    lastName,
  ].where((s) => s != null && s.trim().isNotEmpty).join(' ').trim();

  String? get contactPerson {
    final name = fullName;
    if (name.isNotEmpty && name != companyName) return name;
    return null;
  }

  String get stageName => stage?.name ?? _fallbackStageName(status);
  Color get stageColor => stage?.stageColor ?? const Color(0xFF0284C7);
  Color get stageBgColor => stage?.stageBgColor ?? const Color(0xFFE0F2FE);
  Color get stageBorderColor =>
      stage?.stageBorderColor ?? const Color(0xFFBAE6FD);

  static String _fallbackStageName(String status) {
    return status;
  }

  static String? resolveMediaUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('/')) {
      final origin = AppUrl.baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
      return '$origin$value';
    }
    return null;
  }

  static bool _fakeImage(String value) {
    return RegExp(r'unsplash|pexels|placeholder|dummy|_sample|sample\d|default_avatar', caseSensitive: false).hasMatch(value);
  }

  static List<String> _imageUrls(Map<String, dynamic> json) {
    final urls = <String>[];
    void add(dynamic value) {
      final raw = value?.toString() ?? '';
      if (raw.isEmpty || _fakeImage(raw)) return;
      final resolved = resolveMediaUrl(raw);
      if (resolved != null && !urls.contains(resolved)) urls.add(resolved);
    }

    void addList(dynamic list) {
      if (list is! List) return;
      for (final image in list) {
        add(image is Map ? (image['url'] ?? image['imageUrl'] ?? image['photoUrl'] ?? image['thumbnail']) : image);
      }
    }

    add(json['imageUrl'] ?? json['photoUrl'] ?? json['thumbnail']);
    addList(json['images']);
    addList(json['placePhotos']);
    addList(json['googlePhotos']);
    addList(json['photos']);
    addList(json['visitPhotos']);
    final captures = json['dataCaptureRecords'];
    if (captures is List) {
      for (final record in captures.whereType<Map>()) {
        addList(record['photos']);
        addList(record['googlePhotos']);
        add(record['imageUrl']);
      }
    }
    return urls;
  }

  static List<String> _photoCredits(Map<String, dynamic> json) {
    final credits = <String>[];
    final images = json['images'];
    if (images is! List) return credits;
    for (final image in images.whereType<Map>()) {
      final authors = image['attributions'] ?? image['authorAttributions'];
      if (authors is! List) continue;
      for (final author in authors) {
        final name = author is Map ? author['displayName']?.toString() ?? '' : author.toString();
        if (name.trim().isNotEmpty && !credits.contains(name.trim())) credits.add(name.trim());
      }
    }
    return credits;
  }

  static String? _parseNotesToString(dynamic rawNotes) {
    if (rawNotes == null) return null;
    if (rawNotes is String) {
      final str = rawNotes.trim();
      if (!str.startsWith('[')) return str.isEmpty ? null : str;
      try {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          final contents = decoded
              .whereType<Map>()
              .map((m) => m['content']?.toString() ?? '')
              .where((s) => s.trim().isNotEmpty)
              .toList();
          return contents.isNotEmpty ? contents.join('\n') : null;
        }
      } catch (_) {}
      return str.isEmpty ? null : str;
    }
    if (rawNotes is List) {
      final contents = rawNotes
          .whereType<Map>()
          .map((m) => m['content']?.toString() ?? '')
          .where((s) => s.trim().isNotEmpty)
          .toList();
      return contents.isNotEmpty ? contents.join('\n') : null;
    }
    return rawNotes.toString();
  }

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    int? readId(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty) return null;
      return int.tryParse(text.split('.').first);
    }

    LeadStageModel? parsedStage;
    if (json['stage'] is Map<String, dynamic>) {
      parsedStage = LeadStageModel.fromJson(
        json['stage'] as Map<String, dynamic>,
      );
    } else if (json['stage'] is Map) {
      parsedStage = LeadStageModel.fromJson(
        Map<String, dynamic>.from(json['stage'] as Map),
      );
    }

    String? assignedName;
    if (json['assignedTo'] is Map) {
      final a = json['assignedTo'] as Map;
      assignedName = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim();
    }

    List<LeadVisitModel> parsedVisits = [];
    if (json['visits'] is List) {
      parsedVisits = (json['visits'] as List)
          .whereType<Map>()
          .map((m) => LeadVisitModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    return LeadModel(
      id: json['id']?.toString() ?? '',
      companyName:
          json['companyName']?.toString() ??
          json['title']?.toString() ??
          'Unnamed Business',
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      website: json['website']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      pincode: json['pincode']?.toString(),
      category: json['category']?.toString(),
      googlePlaceId: json['googlePlaceId']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      source: json['source']?.toString() ?? 'MANUAL',
      createdFrom: json['createdFrom']?.toString() ?? 'ADMIN_PANEL',
      status: json['status']?.toString() ?? 'NEW',
      stageId: readId(json['stageId']) ?? parsedStage?.id,
      stage: parsedStage,
      notes: _parseNotesToString(json['notes'] ?? json['rawNotes']),
      priority: json['priority']?.toString(),
      value: (json['value'] as num?)?.toDouble(),
      nextFollowUpDate: json['nextFollowUpDate']?.toString(),
      nextFollowUpTime: json['nextFollowUpTime']?.toString(),
      workStartDate: json['workStartDate']?.toString(),
      workNotes: json['workNotes']?.toString(),
      assignedTeam: json['assignedTeam']?.toString(),
      assignedToId: (json['assignedToId'] as num?)?.toInt(),
      assignedToName: assignedName,
      createdAt: json['createdAt']?.toString(),
      socialMedia: SocialMediaModel.from(
        json['socialMedia'] ??
            (json['rawData'] is Map
                ? (json['rawData'] as Map)['socialMedia']
                : null) ??
            (json['dataCaptureRecords'] is List &&
                    (json['dataCaptureRecords'] as List).isNotEmpty &&
                    (json['dataCaptureRecords'] as List).first is Map
                ? (json['dataCaptureRecords'] as List).first['socialMedia']
                : null),
      ),
      visits: parsedVisits,
      imageUrl: _imageUrls(json).isEmpty ? null : _imageUrls(json).first,
      images: _imageUrls(json),
      photoCredits: _photoCredits(json),
      visitStatus: json['visitStatus']?.toString() ?? (parsedVisits.isNotEmpty ? parsedVisits.first.status : null),
      visitScheduledAt: json['visitScheduledAt']?.toString() ?? (parsedVisits.isNotEmpty ? parsedVisits.first.date : null),
      assignedVisitorId: (json['assignedVisitorId'] as num?)?.toInt() ?? (parsedVisits.isNotEmpty ? parsedVisits.first.employeeId : null),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'companyName': companyName,
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    'email': email,
    'website': website,
    'address': address,
    'city': city,
    'state': state,
    'country': country,
    'pincode': pincode,
    'category': category,
    'googlePlaceId': googlePlaceId,
    'latitude': latitude,
    'longitude': longitude,
    'source': source,
    'createdFrom': createdFrom,
    'status': status,
    'stageId': stageId,
    'stage': stage?.toJson(),
    'notes': notes,
    'priority': priority,
    'value': value,
    'nextFollowUpDate': nextFollowUpDate,
    'nextFollowUpTime': nextFollowUpTime,
    'workStartDate': workStartDate,
    'workNotes': workNotes,
    'assignedTeam': assignedTeam,
    'assignedToId': assignedToId,
    'createdAt': createdAt,
    'visits': visits.map((v) => v.toJson()).toList(),
    'visitStatus': visitStatus,
    'visitScheduledAt': visitScheduledAt,
    'assignedVisitorId': assignedVisitorId,
    if (socialMedia != null)
      'socialMedia': socialMedia is SocialMediaModel
          ? (socialMedia as SocialMediaModel).toJson()
          : socialMedia,
  };

  LeadModel copyWith({
    String? id,
    String? companyName,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? website,
    String? address,
    String? city,
    String? state,
    String? country,
    String? pincode,
    String? category,
    String? googlePlaceId,
    double? latitude,
    double? longitude,
    String? source,
    String? createdFrom,
    String? status,
    int? stageId,
    LeadStageModel? stage,
    String? notes,
    String? priority,
    double? value,
    String? nextFollowUpDate,
    String? nextFollowUpTime,
    String? workStartDate,
    String? workNotes,
    String? assignedTeam,
    int? assignedToId,
    String? assignedToName,
    String? createdAt,
    dynamic socialMedia,
    List<LeadVisitModel>? visits,
    String? visitStatus,
    String? visitScheduledAt,
    int? assignedVisitorId,
    String? imageUrl,
    List<String>? images,
    List<String>? photoCredits,
  }) {
    return LeadModel(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      pincode: pincode ?? this.pincode,
      category: category ?? this.category,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      source: source ?? this.source,
      createdFrom: createdFrom ?? this.createdFrom,
      status: status ?? this.status,
      stageId: stageId ?? this.stageId,
      stage: stage ?? this.stage,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      value: value ?? this.value,
      nextFollowUpDate: nextFollowUpDate ?? this.nextFollowUpDate,
      nextFollowUpTime: nextFollowUpTime ?? this.nextFollowUpTime,
      workStartDate: workStartDate ?? this.workStartDate,
      workNotes: workNotes ?? this.workNotes,
      assignedTeam: assignedTeam ?? this.assignedTeam,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
      createdAt: createdAt ?? this.createdAt,
      socialMedia: socialMedia ?? this.socialMedia,
      visits: visits ?? this.visits,
      visitStatus: visitStatus ?? this.visitStatus,
      visitScheduledAt: visitScheduledAt ?? this.visitScheduledAt,
      assignedVisitorId: assignedVisitorId ?? this.assignedVisitorId,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      photoCredits: photoCredits ?? this.photoCredits,
    );
  }
}

class LeadVisitModel {
  final String id;
  final int? employeeId;
  final String customerName;
  final String purpose;
  final String date;
  final String? time;
  final String location;
  final double? latitude;
  final double? longitude;
  final String status;
  final String? notes;
  final String? outcome;
  final String? assignedEmployee;
  final String? completedBy;
  final String? completedAt;
  final String createdAt;

  const LeadVisitModel({
    required this.id,
    this.employeeId,
    required this.customerName,
    required this.purpose,
    required this.date,
    this.time,
    required this.location,
    this.latitude,
    this.longitude,
    required this.status,
    this.notes,
    this.outcome,
    this.assignedEmployee,
    this.completedBy,
    this.completedAt,
    required this.createdAt,
  });

  factory LeadVisitModel.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'];
    final empName = emp is Map
        ? '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim()
        : null;
    final resolvedAssigned =
        json['assignedEmployee']?.toString() ??
        (empName != null && empName.isNotEmpty ? empName : null);

    final rawCompleted = json['completedBy']?.toString().trim();
    final resolvedCompletedBy =
        (rawCompleted != null &&
            rawCompleted.isNotEmpty &&
            rawCompleted.toLowerCase() != 'visitor')
        ? rawCompleted
        : null;

    return LeadVisitModel(
      id: json['id']?.toString() ?? '',
      employeeId: (json['employeeId'] as num?)?.toInt(),
      customerName: json['customerName']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? 'Field Visit',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString(),
      location: json['location']?.toString() ?? 'Client Site',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'SCHEDULED',
      notes: json['notes']?.toString(),
      outcome: json['outcome']?.toString(),
      assignedEmployee: resolvedAssigned,
      completedBy: resolvedCompletedBy,
      completedAt: json['completedAt']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'employeeId': employeeId,
    'customerName': customerName,
    'purpose': purpose,
    'date': date,
    'time': time,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'status': status,
    'notes': notes,
    'outcome': outcome,
    'assignedEmployee': assignedEmployee,
    'completedBy': completedBy,
    'completedAt': completedAt,
    'createdAt': createdAt,
  };
}
