import 'package:flutter/foundation.dart';

/// Immutable model representing a Marketing Video.
/// Can be displayed on the Customer Home Screen (between QB Marketplace and Influencer Hub)
/// and/or in the Customer Introduction / Onboarding flow.
@immutable
class MarketingVideoModel {
  final int id;
  final int? customerId;
  final String title;
  final String? subtitle;
  final String? description;
  final String videoUrl;
  final String? videoKey;
  final String? thumbnailUrl;
  final String? thumbnailKey;
  final String? ctaText;
  final String? ctaUrl;
  final String status;
  final int priority;
  final bool isActive;
  final bool isPublished;
  final bool showOnHome;
  final bool showInIntroduction;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? createdAt;

  const MarketingVideoModel({
    required this.id,
    this.customerId,
    required this.title,
    this.subtitle,
    this.description,
    required this.videoUrl,
    this.videoKey,
    this.thumbnailUrl,
    this.thumbnailKey,
    this.ctaText,
    this.ctaUrl,
    this.status = 'ACTIVE',
    this.priority = 0,
    this.isActive = true,
    this.isPublished = true,
    this.showOnHome = true,
    this.showInIntroduction = false,
    this.startAt,
    this.endAt,
    this.createdAt,
  });

  static bool _parseBool(dynamic val, {bool defaultValue = true}) {
    if (val == null) return defaultValue;
    if (val is bool) return val;
    if (val is num) return val != 0;
    final s = val.toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return defaultValue;
  }

  /// Evaluates whether this video is eligible for Customer Home Screen display.
  bool get isEligibleForHome {
    if (!isActive ||
        !showOnHome ||
        status.toUpperCase() != 'ACTIVE' ||
        videoUrl.trim().isEmpty) {
      return false;
    }
    final now = DateTime.now();
    if (startAt != null && startAt!.isAfter(now)) {
      return false;
    }
    if (endAt != null && endAt!.isBefore(now)) {
      return false;
    }
    return true;
  }

  factory MarketingVideoModel.fromJson(Map<String, dynamic> json) {
    return MarketingVideoModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      customerId: json['customerId'] != null
          ? int.tryParse(json['customerId'].toString())
          : null,
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString(),
      videoUrl: json['videoUrl']?.toString() ?? '',
      videoKey: json['videoKey']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      thumbnailKey: json['thumbnailKey']?.toString(),
      ctaText: json['ctaText']?.toString(),
      ctaUrl: json['ctaUrl']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      priority: json['priority'] is int
          ? json['priority'] as int
          : int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
      isActive: _parseBool(json['isActive'], defaultValue: true),
      isPublished: _parseBool(json['isPublished'], defaultValue: true),
      showOnHome: _parseBool(json['showOnHome'], defaultValue: true),
      showInIntroduction: _parseBool(
        json['showInIntroduction'],
        defaultValue: false,
      ),
      startAt: json['startAt'] != null
          ? DateTime.tryParse(json['startAt'].toString())
          : null,
      endAt: json['endAt'] != null
          ? DateTime.tryParse(json['endAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'videoUrl': videoUrl,
      'videoKey': videoKey,
      'thumbnailUrl': thumbnailUrl,
      'thumbnailKey': thumbnailKey,
      'ctaText': ctaText,
      'ctaUrl': ctaUrl,
      'status': status,
      'priority': priority,
      'isActive': isActive,
      'isPublished': isPublished,
      'showOnHome': showOnHome,
      'showInIntroduction': showInIntroduction,
      'startAt': startAt?.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketingVideoModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
