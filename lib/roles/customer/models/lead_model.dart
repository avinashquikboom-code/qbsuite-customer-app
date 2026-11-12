import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';

class LeadModel {
  final String id;
  final String? stageId;
  final String? stageNameConfig;
  final String? stageColorHex;
  final String title;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? companyName;
  final String? website;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? category;
  final String source;
  final String status;
  final String priority;
  final double value;
  final String? assignedToId;
  final String? assignedToName;
  final String? createdById;
  final String? createdByName;
  final String? nextFollowUpDate;
  final String? nextFollowUpTime;
  final String? workStartDate;
  final String? workNotes;
  final String? assignedTeam;
  final double paidAmount;
  final String paymentStatus;
  final String? paymentMethod;
  final String? paymentRef;
  final String createdAt;
  final String? updatedAt;
  final List<LeadImageModel> images;
  final LeadSocialMediaModel? socialMedia;
  final List<LeadNoteModel> notes;
  final List<LeadTimelineItemModel> timeline;
  final List<LeadStatusHistoryModel> statusHistory;
  final List<LeadVisitModel> visits;
  final List<LeadProposalModel> quotations;
  final String? googlePlaceId;
  final double? rating;
  final int? reviewCount;
  final String? businessStatus;
  final double? upcomingCommission;
  final ConvertedCustomerModel? convertedCustomer;
  final String? sourceRecordId;
  final String? captureRequestId;
  final String? businessName;
  final String? employeeId;
  final String? employeeName;
  final String? convertedByEmployeeId;
  final String? convertedByEmployeeName;

  LeadModel({
    required this.id,
    this.stageId,
    this.stageNameConfig,
    this.stageColorHex,
    required this.title,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.companyName,
    this.businessName,
    this.website,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.country,
    this.latitude,
    this.longitude,
    this.category,
    required this.source,
    required this.status,
    required this.priority,
    required this.value,
    this.assignedToId,
    this.assignedToName,
    this.createdById,
    this.createdByName,
    this.nextFollowUpDate,
    this.nextFollowUpTime,
    this.workStartDate,
    this.workNotes,
    this.assignedTeam,
    this.paidAmount = 0.0,
    this.paymentStatus = 'PENDING',
    this.paymentMethod,
    this.paymentRef,
    required this.createdAt,
    this.updatedAt,
    this.images = const [],
    this.socialMedia,
    this.notes = const [],
    this.timeline = const [],
    this.statusHistory = const [],
    this.visits = const [],
    this.quotations = const [],
    this.googlePlaceId,
    this.rating,
    this.reviewCount,
    this.businessStatus,
    this.upcomingCommission,
    this.convertedCustomer,
    this.sourceRecordId,
    this.captureRequestId,
    this.employeeId,
    this.employeeName,
    this.convertedByEmployeeId,
    this.convertedByEmployeeName,
  });

  bool get isWon {
    final s = status.trim().toUpperCase();
    if (s == 'WON' ||
        s == 'CONVERTED' ||
        s == 'WORK_STARTED' ||
        s == 'CLOSED') {
      return true;
    }
    final key = (stageNameConfig ?? '').trim().toUpperCase().replaceAll(
      RegExp(r'\s+'),
      '_',
    );
    if (key == 'WON' || key == 'CONVERTED' || key == 'WORK_STARTED') {
      return true;
    }
    final name = stageName.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '_');
    return name == 'WON' || name == 'CONVERTED' || name == 'WORK_STARTED';
  }

  bool get isConverted =>
      convertedCustomer != null || status.toUpperCase() == 'CONVERTED';
  bool get hasCommission =>
      upcomingCommission != null && upcomingCommission! > 0;

  DateTime get createdAtDate =>
      DateTime.tryParse(createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Newest-first pipeline order. Uses creation time only (not updates/visits).
  int compareCreatedAtDesc(LeadModel other) {
    final byTime = other.createdAtDate.compareTo(createdAtDate);
    if (byTime != 0) return byTime;
    return other.id.compareTo(id);
  }

  DateTime get effectiveTimestamp {
    DateTime latest =
        DateTime.tryParse(createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (updatedAt != null) {
      final u = DateTime.tryParse(updatedAt!);
      if (u != null && u.isAfter(latest)) {
        latest = u;
      }
    }
    for (final v in visits) {
      final vc = DateTime.tryParse(v.createdAt);
      if (vc != null && vc.isAfter(latest)) {
        latest = vc;
      }
      final vd = DateTime.tryParse(v.date);
      if (vd != null && vd.isAfter(latest)) {
        latest = vd;
      }
    }
    for (final h in statusHistory) {
      final hc = DateTime.tryParse(h.createdAt);
      if (hc != null && hc.isAfter(latest)) {
        latest = hc;
      }
    }
    for (final t in timeline) {
      final tc = DateTime.tryParse(t.createdAt);
      if (tc != null && tc.isAfter(latest)) {
        latest = tc;
      }
    }
    return latest;
  }

  static bool isPlaceholder(String? val) {
    if (val == null) return true;
    final s = val.trim();
    if (s.isEmpty) return true;
    final lower = s.toLowerCase();
    return lower == 'business lead' ||
        lower == 'unnamed business' ||
        lower == 'unknown business' ||
        lower == 'business owner' ||
        lower == 'direct lead' ||
        lower == 'new lead' ||
        lower == 'placeholder lead' ||
        lower == 'test lead' ||
        lower == 'placeholder customer' ||
        lower == 'test customer' ||
        lower == '.' ||
        lower == 'null' ||
        lower == 'n/a' ||
        lower == 'undefined' ||
        lower == 'none';
  }

  String? get validContactPerson {
    final full = '$firstName $lastName'.trim();
    if (isPlaceholder(full)) return null;
    if (firstName.trim().toLowerCase() == 'business' &&
        lastName.trim().toLowerCase() == 'lead') {
      return null;
    }
    if (firstName.trim().toLowerCase() == 'placeholder' ||
        firstName.trim().toLowerCase() == 'test') {
      return null;
    }
    return full;
  }

  String get fullName => validContactPerson ?? '';

  /// Authoritative display name resolution (businessName ?? companyName ?? title ?? contactName):
  String get displayName {
    if (businessName != null &&
        businessName!.trim().isNotEmpty &&
        !isPlaceholder(businessName)) {
      return businessName!.trim();
    }
    if (companyName != null &&
        companyName!.trim().isNotEmpty &&
        !isPlaceholder(companyName)) {
      return companyName!.trim();
    }
    if (title.trim().isNotEmpty && !isPlaceholder(title)) {
      return title.trim();
    }
    final contact = validContactPerson;
    if (contact != null && contact.trim().isNotEmpty) {
      return contact.trim();
    }
    return '';
  }

  /// Safe display title with genuine fallback:
  /// businessName ?? companyName ?? contactName ?? "No business name available"
  String get displayTitle {
    if (displayName.isNotEmpty) {
      return displayName;
    }
    return 'No business name available';
  }

  /// Formats raw source (e.g. 'GOOGLE_PLACES' or 'GOOGLE_DISCOVERY') into clean human-readable text
  String get sourceDisplayName {
    final s = source.trim().toUpperCase();
    if (s == 'GOOGLE_PLACES') return 'Google Places';
    if (s == 'GOOGLE_DISCOVERY') return 'Google Discovery';
    if (s == 'GOOGLE_MAPS') return 'Google Maps';
    if (s == 'WEBSITE') return 'Website';
    if (s == 'MANUAL') return 'Manual';
    if (s == 'REFERRAL') return 'Referral';
    if (s.isEmpty) return 'Google Discovery';
    return s
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// Validates that an image URL represents a genuine, real business photo
  /// and is not an Unsplash placeholder, dummy image, or fake asset.
  static bool isValidRealImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final u = url.trim().toLowerCase();
    if (u.contains('unsplash.com') ||
        u.contains('pexels.com') ||
        u.contains('placeholder') ||
        u.contains('dummy') ||
        u.contains('fake') ||
        u.contains('default_avatar')) {
      return false;
    }
    return u.startsWith('http://') ||
        u.startsWith('https://') ||
        u.startsWith('data:image/') ||
        u.startsWith('/api/') ||
        u.startsWith('/uploads/');
  }

  /// Returns the primary image if configured (isPrimary == true) and valid,
  /// or falls back to the first available genuine image, or null if no real images exist.
  LeadImageModel? get primaryImage {
    if (images.isEmpty) return null;
    try {
      return images.firstWhere(
        (img) => img.isPrimary && isValidRealImageUrl(img.url),
      );
    } catch (_) {
      try {
        return images.firstWhere((img) => isValidRealImageUrl(img.url));
      } catch (_) {
        return null;
      }
    }
  }

  int get imageCount => images.length;

  /// Stage index is now resolved dynamically in the UI from leadStagesProvider by stageId.
  /// Do NOT compute index here from status strings — that would be hardcoding stage order.
  /// Use: ref.read(leadStagesProvider.notifier).stageIndexById(lead.stageId)

  /// Returns the display name for this lead's stage.
  /// Priority: stageNameConfig (from API stage relation) → title-cased status string.
  /// Never hardcode stage-name mappings here.
  String get stageName {
    if (stageNameConfig != null && stageNameConfig!.trim().isNotEmpty) {
      return stageNameConfig!.trim();
    }
    // Generic fallback: title-case the raw status string
    final s = status.trim();
    if (s.isEmpty) return 'Unknown';
    return s
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  String get stageLabel => stageName;

  /// Returns the display color for this lead's stage.
  /// Priority: stageColorHex (from API stage relation) → neutral slate.
  /// Never hardcode stage-color mappings here.
  Color get stageColor {
    if (stageColorHex != null && stageColorHex!.trim().isNotEmpty) {
      try {
        final hex = stageColorHex!.trim().replaceFirst('#', '');
        final fullHex = hex.length == 6 ? 'FF$hex' : hex;
        return Color(int.parse(fullHex, radix: 16));
      } catch (_) {}
    }
    return const Color(
      0xFF64748B,
    ); // Slate — generic fallback, not stage-specific
  }

  /// Returns true if this lead was imported from Google Places or Google Discovery.
  /// Used to determine if photos should come from Google or if manual upload is allowed.
  bool get isGooglePlacesLead {
    final s = source.trim().toUpperCase();
    if (s == 'GOOGLE_PLACES' || s == 'GOOGLE_DISCOVERY' || s == 'GOOGLE_MAPS') {
      return true;
    }
    // Also check if we have a googlePlaceId (may indicate Google source even if source string is unclear)
    return googlePlaceId != null && googlePlaceId!.isNotEmpty;
  }

  /// Returns true if any social media handle or website is present on this lead.
  bool get hasSocialOrWebsite =>
      (socialMedia != null && socialMedia!.isNotEmpty) ||
      (website != null && website!.trim().isNotEmpty);

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    String? assignedName;
    if (json['assignedTo'] != null && json['assignedTo'] is Map) {
      final a = json['assignedTo'] as Map;
      assignedName =
          '${a['firstName']?.toString() ?? ''} ${a['lastName']?.toString() ?? ''}'
              .trim();
      if (assignedName.isEmpty && a['email'] != null) {
        assignedName = a['email']?.toString();
      }
    }
    // Also accept pre-normalized name from backend enrichment
    if ((assignedName == null || assignedName.isEmpty) &&
        json['assignedToName'] is String) {
      assignedName = json['assignedToName'] as String;
    }

    String? createdName;
    if (json['createdBy'] != null && json['createdBy'] is Map) {
      final c = json['createdBy'] as Map;
      createdName =
          '${c['firstName']?.toString() ?? ''} ${c['lastName']?.toString() ?? ''}'
              .trim();
    }
    if ((createdName == null || createdName.isEmpty) &&
        json['createdByName'] is String) {
      createdName = json['createdByName'] as String;
    }

    // Employee (creator via limit system)
    String? empName;
    if (json['employee'] != null && json['employee'] is Map) {
      final e = json['employee'] as Map;
      empName =
          '${e['firstName']?.toString() ?? ''} ${e['lastName']?.toString() ?? ''}'
              .trim();
    }
    if ((empName == null || empName.isEmpty) &&
        json['employeeName'] is String) {
      empName = json['employeeName'] as String;
    }

    // Converting employee (set on WON transition)
    String? convByName;
    if (json['convertedByEmployee'] != null &&
        json['convertedByEmployee'] is Map) {
      final cb = json['convertedByEmployee'] as Map;
      convByName =
          '${cb['firstName']?.toString() ?? ''} ${cb['lastName']?.toString() ?? ''}'
              .trim();
    }
    if ((convByName == null || convByName.isEmpty) &&
        json['convertedByEmployeeName'] is String) {
      convByName = json['convertedByEmployeeName'] as String;
    }

    List<LeadNoteModel> parsedNotes = [];
    final rawNotes = json['notes'] ?? json['notesList'];
    if (rawNotes != null && rawNotes is List) {
      parsedNotes = rawNotes
          .whereType<Map>()
          .map(
            (item) => LeadNoteModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } else if (rawNotes is String && rawNotes.trim().isNotEmpty) {
      final str = rawNotes.trim();
      if (str.startsWith('[')) {
        try {
          final decoded = jsonDecode(str);
          if (decoded is List) {
            parsedNotes = decoded
                .whereType<Map>()
                .map(
                  (item) =>
                      LeadNoteModel.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList();
          }
        } catch (_) {}
      }
      if (parsedNotes.isEmpty) {
        parsedNotes = [
          LeadNoteModel(
            id: '1',
            leadId: json['id']?.toString() ?? '',
            content: str,
            authorName: 'Team Member',
            createdAt: json['updatedAt']?.toString() ??
                json['createdAt']?.toString() ??
                '',
          ),
        ];
      }
    }

    List<LeadTimelineItemModel> parsedTimeline = [];
    if (json['timeline'] != null && json['timeline'] is List) {
      parsedTimeline = (json['timeline'] as List)
          .whereType<Map>()
          .map(
            (item) =>
                LeadTimelineItemModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    List<LeadStatusHistoryModel> parsedHistory = [];
    if (json['statusHistory'] != null && json['statusHistory'] is List) {
      parsedHistory = (json['statusHistory'] as List)
          .whereType<Map>()
          .map(
            (item) => LeadStatusHistoryModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    List<LeadVisitModel> parsedVisits = [];
    if (json['visits'] != null && json['visits'] is List) {
      parsedVisits = (json['visits'] as List)
          .whereType<Map>()
          .map(
            (item) => LeadVisitModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    List<LeadProposalModel> parsedQuotes = [];
    if (json['quotations'] != null && json['quotations'] is List) {
      parsedQuotes = (json['quotations'] as List)
          .whereType<Map>()
          .map(
            (item) =>
                LeadProposalModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    final stageObj = json['stage'] is Map ? json['stage'] as Map : null;
    final stageIdVal =
        stageObj?['id']?.toString() ?? json['stageId']?.toString();
    final stageNameVal =
        stageObj?['name']?.toString() ?? stageObj?['label']?.toString();
    final stageColorVal = stageObj?['color']?.toString();

    List<LeadImageModel> parsedImages = [];
    if (json['images'] != null && json['images'] is List) {
      parsedImages = (json['images'] as List)
          .whereType<Map>()
          .map(
            (item) => LeadImageModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((img) => isValidRealImageUrl(img.url))
          .toList();
    }
    if (parsedImages.isEmpty) {
      final altPhotos = json['googlePhotos'] ?? json['photos'];
      if (altPhotos is List) {
        for (var i = 0; i < altPhotos.length; i++) {
          final item = altPhotos[i];
          if (item is Map) {
            final url = item['url']?.toString();
            if (url != null && url.isNotEmpty && isValidRealImageUrl(url)) {
              parsedImages.add(
                LeadImageModel(
                  id: item['id']?.toString() ?? 'photo_$i',
                  leadId: json['id']?.toString() ?? '',
                  url: url,
                  key: item['name']?.toString(),
                  caption: item['name']?.toString() ?? 'Google Photo ${i + 1}',
                  isPrimary: i == 0,
                  createdAt: DateTime.now().toIso8601String(),
                ),
              );
            }
          } else if (item is String &&
              item.isNotEmpty &&
              isValidRealImageUrl(item)) {
            parsedImages.add(
              LeadImageModel(
                id: 'photo_$i',
                leadId: json['id']?.toString() ?? '',
                url: item,
                caption: 'Google Photo ${i + 1}',
                isPrimary: i == 0,
                createdAt: DateTime.now().toIso8601String(),
              ),
            );
          }
        }
      }
    }
    parsedImages = parsedImages
        .where((img) => isValidRealImageUrl(img.url))
        .toList();

    LeadSocialMediaModel? parsedSocial;
    if (json['socialMedia'] != null && json['socialMedia'] is Map) {
      parsedSocial = LeadSocialMediaModel.fromJson(
        Map<String, dynamic>.from(json['socialMedia'] as Map),
      );
    } else if (json['socialMedia'] != null && json['socialMedia'] is String) {
      final rawStr = (json['socialMedia'] as String).trim();
      if (rawStr.startsWith('{')) {
        try {
          final decoded = jsonDecode(rawStr);
          if (decoded is Map) {
            parsedSocial = LeadSocialMediaModel.fromJson(
              Map<String, dynamic>.from(decoded),
            );
          }
        } catch (_) {}
      }
      if (parsedSocial == null &&
          rawStr.isNotEmpty &&
          rawStr != 'null' &&
          rawStr != 'N/A') {
        final lower = rawStr.toLowerCase();
        if (lower.contains('instagram.com')) {
          parsedSocial = LeadSocialMediaModel(instagram: rawStr);
        } else if (lower.contains('facebook.com')) {
          parsedSocial = LeadSocialMediaModel(facebook: rawStr);
        } else if (lower.contains('linkedin.com')) {
          parsedSocial = LeadSocialMediaModel(linkedin: rawStr);
        } else if (lower.contains('youtube.com')) {
          parsedSocial = LeadSocialMediaModel(youtube: rawStr);
        } else if (lower.contains('twitter.com') || lower.contains('x.com')) {
          parsedSocial = LeadSocialMediaModel(twitter: rawStr);
        } else {
          parsedSocial = LeadSocialMediaModel(website: rawStr);
        }
      }
    } else if (json['rawData'] is Map &&
        (json['rawData'] as Map)['socialMedia'] is Map) {
      parsedSocial = LeadSocialMediaModel.fromJson(
        Map<String, dynamic>.from(
          (json['rawData'] as Map)['socialMedia'] as Map,
        ),
      );
    }

    // Extract from socialProfiles array if present
    String? spInstagram;
    String? spFacebook;
    String? spYoutube;
    String? spLinkedin;
    String? spTwitter;
    String? spTiktok;
    String? spPinterest;
    if (json['socialProfiles'] is List) {
      for (final sp in (json['socialProfiles'] as List)) {
        if (sp is Map) {
          final plat = (sp['platform'] ?? sp['name'] ?? '')
              .toString()
              .toLowerCase();
          final url = (sp['url'] ?? sp['link'] ?? sp['handle'] ?? '')
              .toString();
          if (url.isNotEmpty) {
            if (plat.contains('instagram')) {
              spInstagram ??= url;
            } else if (plat.contains('facebook')) {
              spFacebook ??= url;
            } else if (plat.contains('youtube')) {
              spYoutube ??= url;
            } else if (plat.contains('linkedin')) {
              spLinkedin ??= url;
            } else if (plat.contains('twitter') || plat == 'x') {
              spTwitter ??= url;
            } else if (plat.contains('tiktok')) {
              spTiktok ??= url;
            } else if (plat.contains('pinterest')) {
              spPinterest ??= url;
            }
          }
        }
      }
    }

    // Merge top-level aliases & socialProfiles fallback
    final resolvedIg =
        parsedSocial?.instagram ?? spInstagram ?? json['instagram']?.toString();
    final resolvedFb =
        parsedSocial?.facebook ?? spFacebook ?? json['facebook']?.toString();
    final resolvedLi =
        parsedSocial?.linkedin ?? spLinkedin ?? json['linkedin']?.toString();
    final resolvedYt =
        parsedSocial?.youtube ?? spYoutube ?? json['youtube']?.toString();
    final resolvedTw =
        parsedSocial?.twitter ??
        spTwitter ??
        json['twitter']?.toString() ??
        json['x']?.toString();
    final resolvedWeb = parsedSocial?.website ?? json['website']?.toString();
    final resolvedTt =
        parsedSocial?.tiktok ?? spTiktok ?? json['tiktok']?.toString();
    final resolvedPin =
        parsedSocial?.pinterest ?? spPinterest ?? json['pinterest']?.toString();

    if (resolvedIg != null ||
        resolvedFb != null ||
        resolvedLi != null ||
        resolvedYt != null ||
        resolvedTw != null ||
        resolvedWeb != null ||
        resolvedTt != null ||
        resolvedPin != null) {
      parsedSocial = LeadSocialMediaModel(
        instagram: resolvedIg,
        facebook: resolvedFb,
        linkedin: resolvedLi,
        youtube: resolvedYt,
        twitter: resolvedTw,
        website: resolvedWeb,
        tiktok: resolvedTt,
        pinterest: resolvedPin,
      );
    }

    double? parsedLat;
    if (json['latitude'] != null) {
      parsedLat =
          (json['latitude'] as num?)?.toDouble() ??
          double.tryParse(json['latitude'].toString());
    }

    double? parsedLng;
    if (json['longitude'] != null) {
      parsedLng =
          (json['longitude'] as num?)?.toDouble() ??
          double.tryParse(json['longitude'].toString());
    }

    final rawBizName =
        json['businessName']?.toString().trim() ??
        json['business_name']?.toString().trim();
    final rawCompName =
        json['companyName']?.toString().trim() ??
        json['company_name']?.toString().trim();
    final rawTitle = json['title']?.toString().trim();
    final rawContact = json['contactName']?.toString().trim();

    final String? parsedBiz = (rawBizName != null && !isPlaceholder(rawBizName))
        ? rawBizName
        : null;
    final String? parsedComp =
        (rawCompName != null && !isPlaceholder(rawCompName))
        ? rawCompName
        : null;
    final String? parsedContact =
        (rawContact != null && !isPlaceholder(rawContact)) ? rawContact : null;
    final String? parsedRawTitle =
        (rawTitle != null && !isPlaceholder(rawTitle)) ? rawTitle : null;

    final String? resolvedName =
        parsedBiz ??
        parsedComp ??
        parsedContact ??
        parsedRawTitle ??
        (json['displayName'] is Map &&
                !isPlaceholder(json['displayName']['text']?.toString())
            ? json['displayName']['text'].toString().trim()
            : null) ??
        (json['displayName'] is String &&
                !isPlaceholder(json['displayName']?.toString())
            ? json['displayName'].toString().trim()
            : null) ??
        (json['name'] != null &&
                !isPlaceholder(json['name'].toString()) &&
                !json['name'].toString().trim().startsWith('places/')
            ? json['name'].toString().trim()
            : null) ??
        (!isPlaceholder(json['placeName']?.toString())
            ? json['placeName'].toString().trim()
            : null) ??
        (!isPlaceholder(json['establishmentName']?.toString())
            ? json['establishmentName'].toString().trim()
            : null) ??
        (!isPlaceholder(json['organizationName']?.toString())
            ? json['organizationName'].toString().trim()
            : null) ??
        (!isPlaceholder(json['formattedName']?.toString())
            ? json['formattedName'].toString().trim()
            : null) ??
        (!isPlaceholder(
              json['data'] is Map
                  ? (json['data'] as Map)['businessName']?.toString()
                  : null,
            )
            ? (json['data'] as Map)['businessName'].toString().trim()
            : null) ??
        (!isPlaceholder(
              json['data'] is Map
                  ? (json['data'] as Map)['companyName']?.toString()
                  : null,
            )
            ? (json['data'] as Map)['companyName'].toString().trim()
            : null);

    final parsedBusinessName = parsedBiz ?? resolvedName;
    final finalCompanyName = parsedComp ?? resolvedName;
    final parsedTitle = parsedRawTitle ?? (resolvedName ?? '');

    final rawFn = json['firstName']?.toString().trim() ?? '';
    final rawLn = json['lastName']?.toString().trim() ?? '';
    bool isFakePart(String s) => [
      'business',
      'lead',
      'owner',
      'unknown',
      'direct',
      'prospect',
      'customer',
      '.',
      'placeholder',
      'test',
    ].contains(s.toLowerCase());
    final parsedFirstName = isFakePart(rawFn) ? '' : rawFn;
    final parsedLastName = isFakePart(rawLn) ? '' : rawLn;

    final parsedRating =
        (json['rating'] as num?)?.toDouble() ??
        double.tryParse(json['rating']?.toString() ?? '');
    final parsedReviews =
        (json['reviewCount'] as num?)?.toInt() ??
        int.tryParse(json['reviewCount']?.toString() ?? '') ??
        (json['reviews'] as num?)?.toInt() ??
        int.tryParse(json['reviews']?.toString() ?? '');
    final parsedPlaceId =
        json['googlePlaceId']?.toString() ?? json['placeId']?.toString();
    final parsedStatusStr =
        json['businessStatus']?.toString() ?? json['status']?.toString();

    ConvertedCustomerModel? parsedCustomer;
    if (json['convertedCustomer'] != null && json['convertedCustomer'] is Map) {
      parsedCustomer = ConvertedCustomerModel.fromJson(
        Map<String, dynamic>.from(json['convertedCustomer'] as Map),
      );
    } else if (json['customer'] != null && json['customer'] is Map) {
      parsedCustomer = ConvertedCustomerModel.fromJson(
        Map<String, dynamic>.from(json['customer'] as Map),
      );
    }

    double? parsedCommission;
    if (json['upcomingCommission'] != null) {
      parsedCommission = (json['upcomingCommission'] as num?)?.toDouble();
    } else if (json['commissions'] is List &&
        (json['commissions'] as List).isNotEmpty) {
      final list = json['commissions'] as List;
      double sum = 0;
      bool hasValid = false;
      for (final c in list) {
        if (c is Map) {
          final st = c['status']?.toString().toUpperCase();
          if (st == 'PENDING' || st == 'APPROVED') {
            final amt =
                (c['commissionAmount'] as num?)?.toDouble() ??
                double.tryParse(c['commissionAmount']?.toString() ?? '');
            if (amt != null && amt > 0) {
              sum += amt;
              hasValid = true;
            }
          }
        }
      }
      if (hasValid && sum > 0) {
        parsedCommission = sum;
      }
    }

    final model = LeadModel(
      id: json['id']?.toString() ?? '',
      stageId: stageIdVal,
      stageNameConfig: stageNameVal,
      stageColorHex: stageColorVal,
      title: parsedTitle,
      firstName: parsedFirstName,
      lastName: parsedLastName,
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      companyName: finalCompanyName,
      businessName: parsedBusinessName,
      website: json['website']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      pincode: json['pincode']?.toString(),
      country: json['country']?.toString(),
      latitude: parsedLat,
      longitude: parsedLng,
      category: json['category']?.toString(),
      source: json['source']?.toString() ?? 'WEBSITE',
      status: json['status']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'MEDIUM',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      assignedToId: json['assignedToId']?.toString(),
      assignedToName: assignedName,
      createdById: json['createdById']?.toString(),
      createdByName: createdName,
      nextFollowUpDate: json['nextFollowUpDate']?.toString(),
      nextFollowUpTime: json['nextFollowUpTime']?.toString(),
      workStartDate: json['workStartDate']?.toString(),
      workNotes: json['workNotes']?.toString(),
      assignedTeam: json['assignedTeam']?.toString(),
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['paymentStatus']?.toString() ?? 'PENDING',
      paymentMethod: json['paymentMethod']?.toString(),
      paymentRef: json['paymentRef']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt:
          json['updatedAt']?.toString() ?? json['updated_at']?.toString(),
      images: parsedImages,
      socialMedia: parsedSocial,
      notes: parsedNotes,
      timeline: parsedTimeline,
      statusHistory: parsedHistory,
      visits: parsedVisits,
      quotations: parsedQuotes,
      googlePlaceId: parsedPlaceId,
      rating: parsedRating,
      reviewCount: parsedReviews,
      businessStatus: parsedStatusStr,
      upcomingCommission: parsedCommission,
      convertedCustomer: parsedCustomer,
      sourceRecordId: json['sourceRecordId']?.toString(),
      captureRequestId: json['captureRequestId']?.toString(),
      employeeId: json['employeeId']?.toString(),
      employeeName: empName?.isEmpty == true ? null : empName,
      convertedByEmployeeId: json['convertedByEmployeeId']?.toString(),
      convertedByEmployeeName: convByName?.isEmpty == true ? null : convByName,
    );

    // Section 18: Mobile lead name debug output
    if (model.source.toUpperCase().contains('DISCOVERY') ||
        model.source.toUpperCase().contains('GOOGLE') ||
        model.displayName.isEmpty) {
      debugPrint('''
[MOBILE LEAD NAME DEBUG]

leadId: ${model.id}
source: ${model.source}
companyName: ${model.companyName}
title: ${model.title}
firstName: ${model.firstName}
lastName: ${model.lastName}
captureRequestId: ${model.captureRequestId}
sourceRecordId: ${model.sourceRecordId}
googlePlaceId: ${model.googlePlaceId}
finalDisplayName: ${model.displayName}
''');
    }

    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stageId': stageId,
      'stageNameConfig': stageNameConfig,
      'stageColorHex': stageColorHex,
      'title': title,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'companyName': companyName,
      'website': website,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'source': source,
      'status': status,
      'priority': priority,
      'value': value,
      'assignedToId': assignedToId,
      'nextFollowUpDate': nextFollowUpDate,
      'nextFollowUpTime': nextFollowUpTime,
      'workStartDate': workStartDate,
      'workNotes': workNotes,
      'assignedTeam': assignedTeam,
      'paidAmount': paidAmount,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'paymentRef': paymentRef,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'images': images.map((e) => e.toJson()).toList(),
      if (socialMedia != null) 'socialMedia': socialMedia!.toJson(),
      if (googlePlaceId != null) 'googlePlaceId': googlePlaceId,
      if (rating != null) 'rating': rating,
      if (reviewCount != null) 'reviewCount': reviewCount,
      if (businessStatus != null) 'businessStatus': businessStatus,
      if (upcomingCommission != null) 'upcomingCommission': upcomingCommission,
      if (convertedCustomer != null)
        'convertedCustomer': convertedCustomer!.toJson(),
      if (sourceRecordId != null) 'sourceRecordId': sourceRecordId,
      if (captureRequestId != null) 'captureRequestId': captureRequestId,
    };
  }

  LeadModel copyWith({
    String? id,
    String? stageId,
    String? stageNameConfig,
    String? stageColorHex,
    String? title,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? companyName,
    String? businessName,
    String? website,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? country,
    double? latitude,
    double? longitude,
    String? category,
    String? source,
    String? status,
    String? priority,
    double? value,
    String? assignedToId,
    String? assignedToName,
    String? nextFollowUpDate,
    String? nextFollowUpTime,
    String? workStartDate,
    String? workNotes,
    String? assignedTeam,
    double? paidAmount,
    String? paymentStatus,
    String? paymentMethod,
    String? paymentRef,
    String? createdAt,
    String? updatedAt,
    List<LeadImageModel>? images,
    LeadSocialMediaModel? socialMedia,
    List<LeadNoteModel>? notes,
    List<LeadTimelineItemModel>? timeline,
    List<LeadStatusHistoryModel>? statusHistory,
    List<LeadVisitModel>? visits,
    List<LeadProposalModel>? quotations,
    String? googlePlaceId,
    double? rating,
    int? reviewCount,
    String? businessStatus,
    double? upcomingCommission,
    ConvertedCustomerModel? convertedCustomer,
    String? sourceRecordId,
    String? captureRequestId,
    String? employeeId,
    String? employeeName,
    String? convertedByEmployeeId,
    String? convertedByEmployeeName,
  }) {
    return LeadModel(
      id: id ?? this.id,
      stageId: stageId ?? this.stageId,
      stageNameConfig: stageNameConfig ?? this.stageNameConfig,
      stageColorHex: stageColorHex ?? this.stageColorHex,
      title: title ?? this.title,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      companyName: companyName ?? this.companyName,
      businessName: businessName ?? this.businessName,
      website: website ?? this.website,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      source: source ?? this.source,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      value: value ?? this.value,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
      createdById: createdById,
      createdByName: createdByName,
      nextFollowUpDate: nextFollowUpDate ?? this.nextFollowUpDate,
      nextFollowUpTime: nextFollowUpTime ?? this.nextFollowUpTime,
      workStartDate: workStartDate ?? this.workStartDate,
      workNotes: workNotes ?? this.workNotes,
      assignedTeam: assignedTeam ?? this.assignedTeam,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentRef: paymentRef ?? this.paymentRef,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      images: images ?? this.images,
      socialMedia: socialMedia ?? this.socialMedia,
      notes: notes ?? this.notes,
      timeline: timeline ?? this.timeline,
      statusHistory: statusHistory ?? this.statusHistory,
      visits: visits ?? this.visits,
      quotations: quotations ?? this.quotations,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      businessStatus: businessStatus ?? this.businessStatus,
      upcomingCommission: upcomingCommission ?? this.upcomingCommission,
      convertedCustomer: convertedCustomer ?? this.convertedCustomer,
      sourceRecordId: sourceRecordId ?? this.sourceRecordId,
      captureRequestId: captureRequestId ?? this.captureRequestId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      convertedByEmployeeId:
          convertedByEmployeeId ?? this.convertedByEmployeeId,
      convertedByEmployeeName:
          convertedByEmployeeName ?? this.convertedByEmployeeName,
    );
  }
}

class LeadNoteModel {
  final String id;
  final String leadId;
  final String content;
  final String? authorName;
  final String createdAt;

  LeadNoteModel({
    required this.id,
    required this.leadId,
    required this.content,
    this.authorName,
    required this.createdAt,
  });

  factory LeadNoteModel.fromJson(Map<String, dynamic> json) {
    String? author;
    if (json['user'] != null && json['user'] is Map) {
      final u = json['user'] as Map;
      author =
          '${u['firstName']?.toString() ?? ''} ${u['lastName']?.toString() ?? ''}'
              .trim();
    }
    if ((author == null || author.isEmpty) && json['authorName'] != null) {
      author = json['authorName']?.toString().trim();
    }
    if ((author == null || author.isEmpty) && json['author'] != null) {
      author = json['author']?.toString().trim();
    }
    return LeadNoteModel(
      id: json['id']?.toString() ?? '',
      leadId: json['leadId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      authorName: author,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class LeadTimelineItemModel {
  final String id;
  final String leadId;
  final String action;
  final String description;
  final Map<String, dynamic>? metadata;
  final String createdAt;

  LeadTimelineItemModel({
    required this.id,
    required this.leadId,
    required this.action,
    required this.description,
    this.metadata,
    required this.createdAt,
  });

  factory LeadTimelineItemModel.fromJson(Map<String, dynamic> json) {
    return LeadTimelineItemModel(
      id: json['id']?.toString() ?? '',
      leadId: json['leadId']?.toString() ?? '',
      action: json['action']?.toString() ?? 'ACTIVITY',
      description: json['description']?.toString() ?? '',
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class LeadStatusHistoryModel {
  final String id;
  final String leadId;
  final String? fromStatus;
  final String toStatus;
  final String? notes;
  final String createdAt;

  LeadStatusHistoryModel({
    required this.id,
    required this.leadId,
    this.fromStatus,
    required this.toStatus,
    this.notes,
    required this.createdAt,
  });

  factory LeadStatusHistoryModel.fromJson(Map<String, dynamic> json) {
    return LeadStatusHistoryModel(
      id: json['id']?.toString() ?? '',
      leadId: json['leadId']?.toString() ?? '',
      fromStatus: json['fromStatus']?.toString(),
      toStatus: json['toStatus']?.toString() ?? '',
      notes: json['notes']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class LeadVisitModel {
  final String id;
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

  LeadVisitModel({
    required this.id,
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
      customerName: json['customerName']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString(),
      location: json['location']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'SCHEDULED',
      notes: json['notes']?.toString(),
      outcome: json['outcome']?.toString(),
      assignedEmployee: resolvedAssigned,
      completedBy: resolvedCompletedBy,
      completedAt:
          json['completedAt']?.toString() ??
          json['completedAtFormatted']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class LeadProposalModel {
  final String id;
  final String quotationNo;
  final String status;
  final double subTotal;
  final double taxAmount;
  final double discount;
  final double totalAmount;
  final String validUntil;
  final String? notes;
  final List<LeadProposalItemModel> items;
  final String createdAt;

  LeadProposalModel({
    required this.id,
    required this.quotationNo,
    required this.status,
    required this.subTotal,
    required this.taxAmount,
    required this.discount,
    required this.totalAmount,
    required this.validUntil,
    this.notes,
    this.items = const [],
    required this.createdAt,
  });

  factory LeadProposalModel.fromJson(Map<String, dynamic> json) {
    List<LeadProposalItemModel> parsedItems = [];
    if (json['items'] != null && json['items'] is List) {
      parsedItems = (json['items'] as List)
          .whereType<Map>()
          .map(
            (e) => LeadProposalItemModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    }
    return LeadProposalModel(
      id: json['id']?.toString() ?? '',
      quotationNo: json['quotationNo']?.toString() ?? '',
      status: json['status']?.toString() ?? 'SENT',
      subTotal: (json['subTotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      validUntil: json['validUntil']?.toString() ?? '',
      notes: json['notes']?.toString(),
      items: parsedItems,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class LeadProposalItemModel {
  final String id;
  final String name;
  final int quantity;
  final double unitPrice;
  final double total;

  LeadProposalItemModel({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory LeadProposalItemModel.fromJson(Map<String, dynamic> json) {
    return LeadProposalItemModel(
      id: json['id']?.toString() ?? '',
      name:
          json['product']?['name']?.toString() ??
          json['name']?.toString() ??
          'Service / Product',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class LeadImageModel {
  final String id;
  final String leadId;
  final String url;
  final String? caption;
  final String? key;
  final List<String> attributions;
  final bool isPrimary;
  final String? createdAt;

  LeadImageModel({
    required this.id,
    required this.leadId,
    required this.url,
    this.caption,
    this.key,
    this.attributions = const [],
    this.isPrimary = false,
    this.createdAt,
  });

  static String resolveUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return '';
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:image/')) {
      return trimmed;
    }
    final origin = AppUrl.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    if (trimmed.startsWith('/')) {
      return '$origin$trimmed';
    }
    return '$origin/$trimmed';
  }

  factory LeadImageModel.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['url']?.toString() ?? '';
    final authors = json['attributions'] ?? json['authorAttributions'];
    return LeadImageModel(
      id: json['id']?.toString() ?? '',
      leadId: json['leadId']?.toString() ?? '',
      url: resolveUrl(rawUrl),
      caption: json['caption']?.toString(),
      key: json['key']?.toString(),
      attributions: authors is List
          ? authors.map((author) => author is Map ? author['displayName']?.toString() ?? '' : author.toString()).where((name) => name.trim().isNotEmpty).toList()
          : const [],
      isPrimary: json['isPrimary'] == true || json['is_primary'] == true,
      createdAt: json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'leadId': leadId,
      'url': url,
      if (caption != null) 'caption': caption,
      if (key != null) 'key': key,
      if (attributions.isNotEmpty) 'attributions': attributions,
      'isPrimary': isPrimary,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}

class LeadSocialMediaModel {
  final String? instagram;
  final String? facebook;
  final String? linkedin;
  final String? youtube;
  final String? twitter;
  final String? website;
  final String? tiktok;
  final String? pinterest;

  LeadSocialMediaModel({
    this.instagram,
    this.facebook,
    this.linkedin,
    this.youtube,
    this.twitter,
    this.website,
    this.tiktok,
    this.pinterest,
  });

  factory LeadSocialMediaModel.fromJson(Map<String, dynamic> json) {
    return LeadSocialMediaModel(
      instagram: json['instagram']?.toString() ?? json['ig']?.toString(),
      facebook: json['facebook']?.toString() ?? json['fb']?.toString(),
      linkedin: json['linkedin']?.toString() ?? json['li']?.toString(),
      youtube: json['youtube']?.toString() ?? json['yt']?.toString(),
      twitter:
          json['twitter']?.toString() ??
          json['x']?.toString() ??
          json['twitter_x']?.toString(),
      website:
          json['website']?.toString() ??
          json['site']?.toString() ??
          json['web']?.toString(),
      tiktok: json['tiktok']?.toString() ?? json['tt']?.toString(),
      pinterest: json['pinterest']?.toString() ?? json['pin']?.toString(),
    );
  }

  bool get isEmpty =>
      (instagram == null || instagram!.trim().isEmpty) &&
      (facebook == null || facebook!.trim().isEmpty) &&
      (linkedin == null || linkedin!.trim().isEmpty) &&
      (youtube == null || youtube!.trim().isEmpty) &&
      (twitter == null || twitter!.trim().isEmpty) &&
      (tiktok == null || tiktok!.trim().isEmpty) &&
      (pinterest == null || pinterest!.trim().isEmpty) &&
      (website == null || website!.trim().isEmpty);

  bool get isNotEmpty => !isEmpty;
  bool get hasSocialLinks => isNotEmpty;

  Map<String, dynamic> toJson() => {
    if (instagram != null) 'instagram': instagram,
    if (facebook != null) 'facebook': facebook,
    if (linkedin != null) 'linkedin': linkedin,
    if (youtube != null) 'youtube': youtube,
    if (twitter != null) 'twitter': twitter,
    if (website != null) 'website': website,
    if (tiktok != null) 'tiktok': tiktok,
    if (pinterest != null) 'pinterest': pinterest,
  };
}

class ConvertedCustomerModel {
  final String id;
  final String? companyName;
  final String? plan;
  final String? email;
  final String? phone;
  final String? status;

  ConvertedCustomerModel({
    required this.id,
    this.companyName,
    this.plan,
    this.email,
    this.phone,
    this.status,
  });

  String get customerId =>
      id.isNotEmpty ? (id.startsWith('CUST-') ? id : 'CUST-$id') : '';
  String get name => companyName ?? '';

  factory ConvertedCustomerModel.fromJson(Map<String, dynamic> json) {
    return ConvertedCustomerModel(
      id: json['id']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? json['name']?.toString(),
      plan:
          json['plan']?.toString() ??
          json['packageName']?.toString() ??
          'Active Plan',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (companyName != null) 'companyName': companyName,
    if (plan != null) 'plan': plan,
    if (email != null) 'email': email,
    if (phone != null) 'phone': phone,
    if (status != null) 'status': status,
  };
}
