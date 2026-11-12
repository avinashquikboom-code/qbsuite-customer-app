import 'package:flutter/foundation.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';

/// Supported trending content categories matching backend Prisma enum.
enum TrendingCategory {
  reel,
  story,
  offer,
  highRoiAd;

  String get apiValue {
    switch (this) {
      case TrendingCategory.reel:
        return 'REEL';
      case TrendingCategory.story:
        return 'STORY';
      case TrendingCategory.offer:
        return 'OFFER';
      case TrendingCategory.highRoiAd:
        return 'HIGH_ROI_AD';
    }
  }

  String get displayLabel {
    switch (this) {
      case TrendingCategory.reel:
        return 'Viral Reels';
      case TrendingCategory.story:
        return 'Story Hooks';
      case TrendingCategory.offer:
        return 'Offers & Deals';
      case TrendingCategory.highRoiAd:
        return 'High ROI Ads';
    }
  }

  String get emoji {
    switch (this) {
      case TrendingCategory.reel:
        return '🔥';
      case TrendingCategory.story:
        return '⚡';
      case TrendingCategory.offer:
        return '🎟️';
      case TrendingCategory.highRoiAd:
        return '🚀';
    }
  }

  static TrendingCategory? tryParse(String? value) {
    if (value == null) return null;
    final upper = value.trim().toUpperCase();
    switch (upper) {
      case 'REEL':
      case 'REELS':
      case 'VIRAL_REEL':
        return TrendingCategory.reel;
      case 'STORY':
      case 'STORIES':
      case 'STORY_AD':
      case 'STORY_ADS':
        return TrendingCategory.story;
      case 'OFFER':
      case 'OFFERS':
      case 'PROMO':
      case 'PROMO_OFFER':
        return TrendingCategory.offer;
      case 'HIGH_ROI_AD':
      case 'HIGH_ROI':
      case 'AD':
        return TrendingCategory.highRoiAd;
      default:
        return null;
    }
  }

  static TrendingCategory fromString(String? value) {
    return tryParse(value) ?? TrendingCategory.reel;
  }
}

/// Reusable YouTube URL parser and helper utility
class YouTubeUrlHelper {
  /// Extracts the YouTube Video ID from any standard YouTube URL (watch, youtu.be, shorts, embed).
  static String? extractVideoId(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();

    // 1. Check youtu.be/ID (e.g. https://youtu.be/ABC12345678)
    final youtuBeRegex = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?youtu\.be\/([a-zA-Z0-9_-]{6,15})',
      caseSensitive: false,
    );
    final youtuBeMatch = youtuBeRegex.firstMatch(trimmed);
    if (youtuBeMatch != null && youtuBeMatch.groupCount >= 1) {
      return youtuBeMatch.group(1);
    }

    // 2. Check youtube.com/shorts/ID (e.g. https://www.youtube.com/shorts/ABC12345678)
    final shortsRegex = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?youtube\.com\/shorts\/([a-zA-Z0-9_-]{6,15})',
      caseSensitive: false,
    );
    final shortsMatch = shortsRegex.firstMatch(trimmed);
    if (shortsMatch != null && shortsMatch.groupCount >= 1) {
      return shortsMatch.group(1);
    }

    // 3. Check youtube.com/embed/ID
    final embedRegex = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?youtube(?:-nocookie)?\.com\/embed\/([a-zA-Z0-9_-]{6,15})',
      caseSensitive: false,
    );
    final embedMatch = embedRegex.firstMatch(trimmed);
    if (embedMatch != null && embedMatch.groupCount >= 1) {
      return embedMatch.group(1);
    }

    // 4. Check youtube.com/watch?v=ID or m.youtube.com/watch?v=ID
    final watchRegex = RegExp(
      r'(?:https?:\/\/)?(?:www\.|m\.)?youtube\.com\/watch\?(?:.*&)?v=([a-zA-Z0-9_-]{6,15})',
      caseSensitive: false,
    );
    final watchMatch = watchRegex.firstMatch(trimmed);
    if (watchMatch != null && watchMatch.groupCount >= 1) {
      return watchMatch.group(1);
    }

    // 5. Fallback URI parameter parsing
    try {
      final uri = Uri.parse(trimmed);
      if (uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
        final v = uri.queryParameters['v'];
        if (v != null && v.isNotEmpty) return v;
        if (uri.pathSegments.isNotEmpty) {
          final last = uri.pathSegments.last;
          if (last.isNotEmpty && last != 'watch') return last;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Returns true if the provided URL represents a YouTube video
  static bool isYouTubeUrl(String? url) {
    return extractVideoId(url) != null;
  }

  /// Derives the standard high-resolution thumbnail URL for a YouTube video
  static String? getThumbnailUrl(String? url) {
    final videoId = extractVideoId(url);
    if (videoId == null) return null;
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  /// Derives the standard playable YouTube watch URL
  static String? getWatchUrl(String? url) {
    final videoId = extractVideoId(url);
    if (videoId == null) return null;
    return 'https://www.youtube.com/watch?v=$videoId';
  }
}

/// Dynamic Trending Content Model
@immutable
class TrendingContent {
  final int id;
  final String title;
  final String? description;
  final TrendingCategory category;
  final String? thumbnailUrl;
  final String? mediaUrl;
  final String? mediaType; // 'IMAGE' | 'VIDEO'
  final String? mediaSource; // 'UPLOAD' | 'URL'
  final String? ctaText;
  final String? ctaUrl;
  final String platform;
  final String objective;
  final int priority;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  final int? views;
  final int? likes;
  final int? shares;
  final int? comments;
  final String? duration;
  final double? engagementRate;
  final bool isFeatured;

  const TrendingContent({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    this.thumbnailUrl,
    this.mediaUrl,
    this.mediaType,
    this.mediaSource,
    this.ctaText,
    this.ctaUrl,
    this.platform = 'INSTAGRAM',
    this.objective = 'ENGAGEMENT',
    this.priority = 0,
    this.startAt,
    this.endAt,
    required this.createdAt,
    this.metadata,
    this.views,
    this.likes,
    this.shares,
    this.comments,
    this.duration,
    this.engagementRate,
    this.isFeatured = false,
  });

  /// Extracted YouTube Video ID if mediaUrl or ctaUrl is a YouTube URL
  String? get youTubeVideoId {
    return YouTubeUrlHelper.extractVideoId(mediaUrl) ??
        YouTubeUrlHelper.extractVideoId(ctaUrl);
  }

  /// True if this item contains a valid YouTube video URL
  bool get isYouTubeVideo => youTubeVideoId != null;

  /// True if this item contains a direct downloadable/streamable video (.mp4, .mov, .webm)
  bool get isDirectVideo {
    if (isYouTubeVideo) return false;
    if (mediaType?.toUpperCase() == 'VIDEO') return true;
    final raw = (mediaUrl ?? '').toLowerCase();
    return raw.contains('.mp4') ||
        raw.contains('.mov') ||
        raw.contains('.webm') ||
        raw.contains('.mkv') ||
        raw.contains('.avi') ||
        category == TrendingCategory.reel;
  }

  /// True if this item is any video (YouTube, Direct video file, or Reel category)
  bool get isVideo {
    if (mediaType?.toUpperCase() == 'VIDEO') return true;
    if (mediaType?.toUpperCase() == 'IMAGE') return false;
    return isYouTubeVideo || isDirectVideo || category == TrendingCategory.reel;
  }

  /// Platform detection matching backend field values
  bool get isInstagram {
    final p = platform.trim().toUpperCase();
    return p == 'INSTAGRAM' ||
        (p != 'YOUTUBE' &&
            !isYouTubeVideo &&
            category == TrendingCategory.reel);
  }

  bool get isYouTube {
    final p = platform.trim().toUpperCase();
    return p == 'YOUTUBE' || isYouTubeVideo;
  }

  String get displayPlatform {
    if (isInstagram) return 'Instagram';
    if (isYouTube) return 'YouTube';
    final p = platform.trim();
    if (p.isEmpty) return 'Trending';
    return p.substring(0, 1).toUpperCase() + p.substring(1).toLowerCase();
  }

  String get displayCategoryTag {
    switch (category) {
      case TrendingCategory.reel:
        return 'Viral Reels';
      case TrendingCategory.story:
        return 'Story Ads';
      case TrendingCategory.offer:
        return 'Offers';
      case TrendingCategory.highRoiAd:
        return 'High ROI Ads';
    }
  }

  /// Dynamic Category Name for the card chip (e.g. Fashion, Food, Tech, Business or fallback)
  String get displayCategoryName {
    final customName =
        metadata?['categoryName']?.toString() ??
        metadata?['category']?.toString() ??
        metadata?['niche']?.toString();
    if (customName != null && customName.trim().isNotEmpty) {
      return customName.trim();
    }
    switch (category) {
      case TrendingCategory.reel:
        return 'Reels';
      case TrendingCategory.story:
        return 'Story Ad';
      case TrendingCategory.offer:
        return 'Offer';
      case TrendingCategory.highRoiAd:
        return 'High ROI';
    }
  }

  /// Short formatted date (e.g. "12 Aug")
  String get shortDate {
    final dt = (startAt ?? createdAt).toLocal();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  /// The resolved full thumbnail URL.
  /// Dynamically computes standard YouTube thumbnail if no custom thumbnail is provided!
  String get effectiveThumbnailUrl {
    final raw = thumbnailUrl?.trim() ?? '';
    if (raw.isNotEmpty) {
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return raw;
      }
      final base = AppUrl.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
      if (raw.startsWith('/')) {
        return '$base$raw';
      }
      return '$base/$raw';
    }

    // Dynamic YouTube thumbnail fallback from video ID
    if (isYouTubeVideo) {
      final ytThumb = YouTubeUrlHelper.getThumbnailUrl(mediaUrl ?? ctaUrl);
      if (ytThumb != null) return ytThumb;
    }

    // If mediaUrl is an image, use it as thumbnail
    if (!isVideo && effectiveMediaUrl.isNotEmpty) {
      return effectiveMediaUrl;
    }

    return '';
  }

  /// The resolved full media URL (resolves relative paths against AppUrl.baseUrl).
  String get effectiveMediaUrl {
    final raw = mediaUrl?.trim() ?? '';
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    final base = AppUrl.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    if (raw.startsWith('/')) {
      return '$base$raw';
    }
    return '$base/$raw';
  }

  /// The primary playable or viewable action URL
  String get playOrTargetUrl {
    if (isYouTubeVideo) {
      return YouTubeUrlHelper.getWatchUrl(mediaUrl ?? ctaUrl) ??
          (mediaUrl ?? ctaUrl ?? '');
    }
    if (effectiveMediaUrl.isNotEmpty) {
      return effectiveMediaUrl;
    }
    if (ctaUrl != null && ctaUrl!.trim().isNotEmpty) {
      return ctaUrl!.trim();
    }
    return '';
  }

  /// Formatted date string (e.g. "30 Aug 2026 • 10:00 AM" or relative time like "2h ago")
  String get formattedDateTime {
    final dt = (startAt ?? createdAt).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final fullDate = '$day $month $year • $hour:$minute $ampm';

    if (diff.inMinutes < 60 && diff.inMinutes >= 0) {
      final mins = diff.inMinutes <= 1 ? 1 : diff.inMinutes;
      return '$mins min ago ($fullDate)';
    } else if (diff.inHours < 24 && diff.inHours >= 0) {
      return '${diff.inHours}h ago • $fullDate';
    }
    return fullDate;
  }

  /// Clean readable date string (e.g. "30 Aug 2026 • 10:00 AM")
  String get formattedDateOnly {
    final dt = (startAt ?? createdAt).toLocal();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year • $hour:$minute $ampm';
  }

  /// Clean number formatter for metrics (e.g. 2100000 -> 2.1M, 124000 -> 124K)
  static String formatMetricNumber(num number) {
    if (number >= 1000000) {
      final val = number / 1000000;
      return val % 1 == 0 ? '${val.toInt()}M' : '${val.toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      final val = number / 1000;
      return val % 1 == 0 ? '${val.toInt()}K' : '${val.toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String? get formattedViews {
    if (views == null || views! <= 0) return null;
    return formatMetricNumber(views!);
  }

  String? get formattedLikes {
    if (likes == null || likes! <= 0) return null;
    return formatMetricNumber(likes!);
  }

  String? get formattedShares {
    if (shares == null || shares! <= 0) return null;
    return formatMetricNumber(shares!);
  }

  String? get formattedComments {
    if (comments == null || comments! <= 0) return null;
    return formatMetricNumber(comments!);
  }

  String? get formattedEngagement {
    if (engagementRate == null || engagementRate! <= 0) return null;
    return '${engagementRate!.toStringAsFixed(1)}%';
  }

  String? get formattedDuration {
    if (duration == null || duration!.trim().isEmpty) return null;
    return duration!.trim();
  }

  factory TrendingContent.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : null;
    final detectedMediaType =
        json['mediaType']?.toString() ?? meta?['mediaType']?.toString();
    final detectedMediaSource =
        json['mediaSource']?.toString() ?? meta?['mediaSource']?.toString();

    int? parseNumToInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString());
    }

    double? parseNumToDouble(dynamic val) {
      if (val == null) return null;
      if (val is double) return val;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    final viewsVal = parseNumToInt(
      json['views'] ?? meta?['views'] ?? meta?['viewCount'],
    );
    final likesVal = parseNumToInt(
      json['likes'] ?? meta?['likes'] ?? meta?['likeCount'],
    );
    final sharesVal = parseNumToInt(
      json['shares'] ?? meta?['shares'] ?? meta?['shareCount'],
    );
    final commentsVal = parseNumToInt(
      json['comments'] ?? meta?['comments'] ?? meta?['commentCount'],
    );
    final durationVal =
        json['duration']?.toString() ?? meta?['duration']?.toString();
    final engagementVal = parseNumToDouble(
      json['engagementRate'] ??
          json['engagement'] ??
          meta?['engagementRate'] ??
          meta?['engagement'],
    );
    final isFeaturedVal =
        json['isFeatured'] == true ||
        json['isFeatured']?.toString().toLowerCase() == 'true' ||
        meta?['isFeatured'] == true ||
        meta?['isFeatured']?.toString().toLowerCase() == 'true';

    return TrendingContent(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? 'Untitled Campaign',
      description: json['description']?.toString(),
      category: TrendingCategory.fromString(json['category']?.toString()),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      mediaType: detectedMediaType,
      mediaSource: detectedMediaSource,
      ctaText: json['ctaText']?.toString(),
      ctaUrl: json['ctaUrl']?.toString(),
      platform: json['platform']?.toString() ?? 'INSTAGRAM',
      objective: json['objective']?.toString() ?? 'ENGAGEMENT',
      priority: json['priority'] is int
          ? json['priority'] as int
          : int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
      startAt: json['startAt'] != null
          ? DateTime.tryParse(json['startAt'].toString())
          : null,
      endAt: json['endAt'] != null
          ? DateTime.tryParse(json['endAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      metadata: meta,
      views: viewsVal,
      likes: likesVal,
      shares: sharesVal,
      comments: commentsVal,
      duration: durationVal,
      engagementRate: engagementVal,
      isFeatured: isFeaturedVal,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category.apiValue,
    'thumbnailUrl': thumbnailUrl,
    'mediaUrl': mediaUrl,
    'mediaType': mediaType,
    'mediaSource': mediaSource,
    'ctaText': ctaText,
    'ctaUrl': ctaUrl,
    'platform': platform,
    'objective': objective,
    'priority': priority,
    'startAt': startAt?.toIso8601String(),
    'endAt': endAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'metadata': metadata,
    'views': views,
    'likes': likes,
    'shares': shares,
    'comments': comments,
    'duration': duration,
    'engagementRate': engagementRate,
    'isFeatured': isFeatured,
  };
}
