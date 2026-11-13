import 'package:material_ui/material_ui.dart';
import 'package:remixicon/remixicon.dart';

/// Immutable model representing a business tool in the QB Marketplace.
class MarketplaceToolModel {
  final int id;
  final String title;
  final String? subtitle;
  final String description;
  final String icon;
  final String category;
  final String? route;
  final String? externalUrl;
  final String? badge;
  final int sortOrder;
  final bool isActive;
  final bool isPublished;

  const MarketplaceToolModel({
    required this.id,
    required this.title,
    this.subtitle,
    required this.description,
    required this.icon,
    this.category = 'GROWTH_TOOLS',
    this.route,
    this.externalUrl,
    this.badge,
    this.sortOrder = 0,
    this.isActive = true,
    this.isPublished = true,
  });

  factory MarketplaceToolModel.fromJson(Map<String, dynamic> json) {
    return MarketplaceToolModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? 'default',
      category: json['category'] as String? ?? 'GROWTH_TOOLS',
      route: json['route'] as String? ?? json['link'] as String?,
      externalUrl: json['externalUrl'] as String?,
      badge: json['badge'] as String?,
      sortOrder: json['sortOrder'] is int
          ? json['sortOrder'] as int
          : int.tryParse('${json['sortOrder']}') ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      isPublished: json['isPublished'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'icon': icon,
      'category': category,
      'route': route,
      'externalUrl': externalUrl,
      'badge': badge,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'isPublished': isPublished,
    };
  }

  /// Whether this tool represents the AI Content Generator.
  bool get isAiContentGenerator {
    final lowerTitle = title.toLowerCase();
    final lowerRoute = route?.toLowerCase() ?? '';
    final lowerIcon = icon.toLowerCase();
    return lowerTitle.contains('ai content generator') ||
        lowerTitle.contains('ai content') ||
        (lowerTitle.contains('ai') && lowerTitle.contains('generator')) ||
        lowerRoute.contains('ai-studio') ||
        lowerRoute.contains('/customer/ai-studio') ||
        lowerRoute.contains('ai_studio') ||
        lowerIcon == 'ai';
  }

  /// In QB Marketplace, all features/modules are "Coming Soon" EXCEPT the AI Content Generator.
  bool get isComingSoon => !isAiContentGenerator;

  /// Resolves the corresponding Remix icon according to icon key or tool title.
  IconData resolveIcon() {
    final lowerIcon = icon.toLowerCase();
    final lowerTitle = title.toLowerCase();

    if (lowerIcon.contains('whatsapp') || lowerTitle.contains('whatsapp')) {
      return Remix.whatsapp_fill;
    }
    if (lowerIcon.contains('calendar') ||
        lowerIcon.contains('schedule') ||
        lowerTitle.contains('scheduler') ||
        lowerTitle.contains('calendar') ||
        lowerTitle.contains('social media')) {
      return Remix.instagram_line;
    }
    if (lowerIcon.contains('crm') ||
        lowerIcon.contains('lead') ||
        lowerTitle.contains('crm') ||
        lowerTitle.contains('lead')) {
      return Remix.team_fill;
    }
    if (lowerIcon.contains('invoice') ||
        lowerIcon.contains('bill') ||
        lowerTitle.contains('invoice') ||
        lowerTitle.contains('billing')) {
      return Remix.file_text_fill;
    }
    if (lowerIcon.contains('email') ||
        lowerIcon.contains('mail') ||
        lowerTitle.contains('email') ||
        lowerTitle.contains('newsletter')) {
      return Remix.mail_fill;
    }
    if (lowerIcon == 'ai' ||
        lowerIcon.contains('magic') ||
        RegExp(r'\bai\b').hasMatch(lowerTitle) ||
        lowerTitle.contains('content generator') ||
        lowerTitle.contains('generator')) {
      return Remix.cpu_line;
    }
    return Remix.apps_2_line;
  }

  /// Resolves the squircle background decoration for the tool icon.
  BoxDecoration resolveSquircleDecoration() {
    final lowerIcon = icon.toLowerCase();
    final lowerTitle = title.toLowerCase();

    if (lowerIcon.contains('whatsapp') || lowerTitle.contains('whatsapp')) {
      return BoxDecoration(
        color: const Color(0xFF22C55E), // WhatsApp vibrant green
        borderRadius: BorderRadius.circular(10),
      );
    }
    if (lowerIcon.contains('calendar') ||
        lowerIcon.contains('schedule') ||
        lowerTitle.contains('scheduler') ||
        lowerTitle.contains('social media')) {
      return BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF833AB4),
            Color(0xFFE1306C),
            Color(0xFFFD1D1D),
            Color(0xFFF77737),
          ],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: BorderRadius.circular(10),
      );
    }
    if (lowerIcon.contains('crm') ||
        lowerIcon.contains('lead') ||
        lowerTitle.contains('crm') ||
        lowerTitle.contains('lead')) {
      return BoxDecoration(
        color: const Color(0xFF3B82F6), // Blue
        borderRadius: BorderRadius.circular(10),
      );
    }
    if (lowerIcon.contains('invoice') ||
        lowerIcon.contains('bill') ||
        lowerTitle.contains('invoice') ||
        lowerTitle.contains('billing')) {
      return BoxDecoration(
        color: const Color(0xFF8B5CF6), // Purple
        borderRadius: BorderRadius.circular(10),
      );
    }
    if (lowerIcon == 'ai' ||
        lowerIcon.contains('magic') ||
        RegExp(r'\bai\b').hasMatch(lowerTitle) ||
        lowerTitle.contains('content generator')) {
      return BoxDecoration(
        color: const Color(0xFFF97316), // Orange
        borderRadius: BorderRadius.circular(10),
      );
    }
    if (lowerIcon.contains('email') ||
        lowerIcon.contains('mail') ||
        lowerTitle.contains('email')) {
      return BoxDecoration(
        color: const Color(0xFF06B6D4), // Teal / Cyan
        borderRadius: BorderRadius.circular(10),
      );
    }
    return BoxDecoration(
      color: const Color(0xFF059669),
      borderRadius: BorderRadius.circular(10),
    );
  }

  /// Resolves icon tint color (white on squircle).
  Color resolveIconColor() {
    return Colors.white;
  }

  /// Resolves icon soft background tint.
  Color resolveIconBgColor() {
    return const Color(0xFFF1F5F9);
  }
}
