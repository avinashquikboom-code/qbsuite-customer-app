import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

/// Representation of an individual social media platform entry.
class SocialPlatformEntry {
  final String platform;
  final String platformKey;
  final String raw;
  final String url;
  final String handle;
  final IconData icon;
  final Color brandColor;

  const SocialPlatformEntry({
    required this.platform,
    required this.platformKey,
    required this.raw,
    required this.url,
    required this.handle,
    required this.icon,
    required this.brandColor,
  });
}

/// Unified social media model supporting standard handles, URLs, and arbitrary platform profiles.
class SocialMediaModel {
  final String? instagram;
  final String? facebook;
  final String? linkedin;
  final String? twitter;
  final String? youtube;
  final String? tiktok;
  final String? pinterest;
  final String? whatsapp;
  final String? telegram;
  final String? threads;
  final String? github;
  final Map<String, String> other;

  const SocialMediaModel({
    this.instagram,
    this.facebook,
    this.linkedin,
    this.twitter,
    this.youtube,
    this.tiktok,
    this.pinterest,
    this.whatsapp,
    this.telegram,
    this.threads,
    this.github,
    this.other = const {},
  });

  static SocialMediaModel? from(dynamic raw) {
    if (raw == null) return null;
    if (raw is SocialMediaModel) return raw;

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = jsonDecode(trimmed);
          return from(decoded);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    if (raw is List) {
      final map = <String, dynamic>{};
      for (final item in raw) {
        if (item is Map) {
          final plat = (item['platform'] ?? item['name'] ?? item['type'] ?? '')
              .toString()
              .trim();
          final url = (item['url'] ?? item['handle'] ?? item['link'] ?? '')
              .toString()
              .trim();
          if (plat.isNotEmpty && url.isNotEmpty) {
            map[plat.toLowerCase()] = url;
          }
        }
      }
      return map.isEmpty ? null : from(map);
    }

    if (raw is Map) {
      String? val(List<String> keys) {
        for (final k in keys) {
          final v = raw[k]?.toString().trim();
          if (v != null && v.isNotEmpty) return v;
        }
        return null;
      }

      final ig = val(['instagram', 'ig', 'insta']);
      final fb = val(['facebook', 'fb']);
      final li = val(['linkedin', 'li']);
      final tw = val(['twitter', 'x', 'twitter_x']);
      final yt = val(['youtube', 'yt']);
      final tt = val(['tiktok', 'tt']);
      final pin = val(['pinterest', 'pin']);
      final wa = val(['whatsapp', 'wa']);
      final tg = val(['telegram', 'tg']);
      final th = val(['threads']);
      final gh = val(['github', 'gh']);

      final known = {
        'instagram', 'ig', 'insta',
        'facebook', 'fb',
        'linkedin', 'li',
        'twitter', 'x', 'twitter_x',
        'youtube', 'yt',
        'tiktok', 'tt',
        'pinterest', 'pin',
        'whatsapp', 'wa',
        'telegram', 'tg',
        'threads',
        'github', 'gh',
        'website', 'web', 'site', // Typically handled as primary website
      };

      final others = <String, String>{};
      for (final entry in raw.entries) {
        final key = entry.key.toString().trim();
        final lower = key.toLowerCase();
        final value = entry.value?.toString().trim();
        if (!known.contains(lower) && value != null && value.isNotEmpty) {
          others[key] = value;
        }
      }

      final model = SocialMediaModel(
        instagram: ig,
        facebook: fb,
        linkedin: li,
        twitter: tw,
        youtube: yt,
        tiktok: tt,
        pinterest: pin,
        whatsapp: wa,
        telegram: tg,
        threads: th,
        github: gh,
        other: others,
      );

      return model.isEmpty ? null : model;
    }

    return null;
  }

  List<SocialPlatformEntry> get entries {
    final list = <SocialPlatformEntry>[];

    void addIfValid({
      required String? value,
      required String platform,
      required String platformKey,
      required IconData icon,
      required Color brandColor,
      required String Function(String clean) urlBuilder,
    }) {
      if (value == null || value.trim().isEmpty) return;
      final rawVal = value.trim();
      final clean = _stripTrailingSlashes(rawVal);
      if (clean.isEmpty) return;

      final url = clean.startsWith(RegExp(r'https?://', caseSensitive: false))
          ? clean
          : urlBuilder(clean);

      final handle = _extractHandle(clean, platform);

      list.add(
        SocialPlatformEntry(
          platform: platform,
          platformKey: platformKey,
          raw: rawVal,
          url: url,
          handle: handle,
          icon: icon,
          brandColor: brandColor,
        ),
      );
    }

    addIfValid(
      value: instagram,
      platform: 'Instagram',
      platformKey: 'instagram',
      icon: Remix.instagram_line,
      brandColor: const Color(0xFFE1306C),
      urlBuilder: (c) => 'https://instagram.com/${c.replaceFirst('@', '')}',
    );

    addIfValid(
      value: facebook,
      platform: 'Facebook',
      platformKey: 'facebook',
      icon: Remix.facebook_circle_fill,
      brandColor: const Color(0xFF1877F2),
      urlBuilder: (c) => 'https://facebook.com/$c',
    );

    addIfValid(
      value: linkedin,
      platform: 'LinkedIn',
      platformKey: 'linkedin',
      icon: Remix.linkedin_box_fill,
      brandColor: const Color(0xFF0A66C2),
      urlBuilder: (c) => c.contains('linkedin.com')
          ? 'https://$c'
          : 'https://linkedin.com/in/${c.replaceFirst('@', '')}',
    );

    addIfValid(
      value: twitter,
      platform: 'X (Twitter)',
      platformKey: 'twitter',
      icon: Remix.twitter_x_line,
      brandColor: const Color(0xFF0F1419),
      urlBuilder: (c) => 'https://x.com/${c.replaceFirst('@', '')}',
    );

    addIfValid(
      value: youtube,
      platform: 'YouTube',
      platformKey: 'youtube',
      icon: Remix.youtube_fill,
      brandColor: const Color(0xFFFF0000),
      urlBuilder: (c) => c.contains('youtube.com')
          ? 'https://$c'
          : 'https://youtube.com/${c.startsWith('@') ? c : '@$c'}',
    );

    addIfValid(
      value: tiktok,
      platform: 'TikTok',
      platformKey: 'tiktok',
      icon: Remix.tiktok_line,
      brandColor: const Color(0xFF000000),
      urlBuilder: (c) => 'https://tiktok.com/@${c.replaceFirst('@', '')}',
    );

    addIfValid(
      value: pinterest,
      platform: 'Pinterest',
      platformKey: 'pinterest',
      icon: Remix.pinterest_line,
      brandColor: const Color(0xFFE60023),
      urlBuilder: (c) => 'https://pinterest.com/$c',
    );

    addIfValid(
      value: whatsapp,
      platform: 'WhatsApp',
      platformKey: 'whatsapp',
      icon: Remix.whatsapp_line,
      brandColor: const Color(0xFF25D366),
      urlBuilder: (c) => 'https://wa.me/${c.replaceAll(RegExp(r'[^0-9]'), '')}',
    );

    addIfValid(
      value: telegram,
      platform: 'Telegram',
      platformKey: 'telegram',
      icon: Remix.telegram_line,
      brandColor: const Color(0xFF229ED9),
      urlBuilder: (c) => 'https://t.me/${c.replaceFirst('@', '')}',
    );

    addIfValid(
      value: threads,
      platform: 'Threads',
      platformKey: 'threads',
      icon: Remix.threads_line,
      brandColor: const Color(0xFF000000),
      urlBuilder: (c) => 'https://threads.net/@${c.replaceFirst('@', '')}',
    );

    addIfValid(
      value: github,
      platform: 'GitHub',
      platformKey: 'github',
      icon: Remix.github_line,
      brandColor: const Color(0xFF24292E),
      urlBuilder: (c) => 'https://github.com/${c.replaceFirst('@', '')}',
    );

    for (final entry in other.entries) {
      final key = entry.key;
      final val = entry.value.trim();
      if (val.isEmpty) continue;
      final clean = _stripTrailingSlashes(val);
      if (clean.isEmpty) continue;

      final url = clean.startsWith(RegExp(r'https?://', caseSensitive: false))
          ? clean
          : 'https://$clean';

      final displayName = _formatPlatformName(key);
      list.add(
        SocialPlatformEntry(
          platform: displayName,
          platformKey: key.toLowerCase(),
          raw: val,
          url: url,
          handle: _extractHandle(clean, displayName),
          icon: Remix.links_line,
          brandColor: const Color(0xFF0284C7),
        ),
      );
    }

    return list;
  }

  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => !isEmpty;

  Map<String, dynamic> toJson() => {
    if (instagram != null) 'instagram': instagram,
    if (facebook != null) 'facebook': facebook,
    if (linkedin != null) 'linkedin': linkedin,
    if (twitter != null) 'twitter': twitter,
    if (youtube != null) 'youtube': youtube,
    if (tiktok != null) 'tiktok': tiktok,
    if (pinterest != null) 'pinterest': pinterest,
    if (whatsapp != null) 'whatsapp': whatsapp,
    if (telegram != null) 'telegram': telegram,
    if (threads != null) 'threads': threads,
    if (github != null) 'github': github,
    ...other,
  };

  static String _stripTrailingSlashes(String val) {
    var s = val.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static String _formatPlatformName(String key) {
    if (key.isEmpty) return 'Social';
    final formatted = key
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    return '${formatted[0].toUpperCase()}${formatted.substring(1)}';
  }

  static String _extractHandle(String clean, String platform) {
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      try {
        final uri = Uri.parse(clean);
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) {
          final last = segments.last;
          if (['Instagram', 'X (Twitter)', 'TikTok', 'Threads', 'Telegram'].contains(platform)) {
            return last.startsWith('@') ? last : '@$last';
          }
          if (['Facebook', 'LinkedIn', 'YouTube', 'Pinterest', 'GitHub'].contains(platform)) {
            return last;
          }
          if (segments.length == 1) {
            return last;
          }
          return '${uri.host}/${segments.join('/')}';
        }
        return uri.host;
      } catch (_) {}
    }
    if (['Instagram', 'X (Twitter)', 'TikTok', 'Threads', 'Telegram', 'LinkedIn'].contains(platform)) {
      return clean.startsWith('@') ? clean : '@$clean';
    }
    return clean;
  }
}
