import 'package:material_ui/material_ui.dart';

/// Represents a single lead stage returned by GET /leads/stages.
/// This is the SINGLE SOURCE OF TRUTH for all stage UI:
///   name, color, bgColor, borderColor, sortOrder, isActive.
/// Never use hardcoded stage strings in UI — always resolve from this model.
class LeadStageModel {
  final int id;
  final String key;
  final String name;
  final int sortOrder;
  final bool isActive;
  final bool isSystem;
  final String? color;
  final String? bgColor;
  final String? borderColor;
  final int leadsCount;

  const LeadStageModel({
    required this.id,
    required this.key,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    this.isSystem = false,
    this.color,
    this.bgColor,
    this.borderColor,
    this.leadsCount = 0,
  });

  factory LeadStageModel.fromJson(Map<String, dynamic> json) {
    return LeadStageModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? json['label']?.toString() ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] == true,
      isSystem: json['isSystem'] == true,
      color: json['color']?.toString(),
      bgColor: json['bgColor']?.toString(),
      borderColor: json['borderColor']?.toString(),
      leadsCount: (json['leadsCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
    'name': name,
    'sortOrder': sortOrder,
    'isActive': isActive,
    'isSystem': isSystem,
    'color': color,
    'bgColor': bgColor,
    'borderColor': borderColor,
    'leadsCount': leadsCount,
  };

  /// Whether this stage represents a WON state
  bool get isWon => key.toUpperCase() == 'WON' || name.toUpperCase() == 'WON';

  /// Whether this stage represents a LOST state
  bool get isLost =>
      key.toUpperCase() == 'LOST' || name.toUpperCase() == 'LOST';

  /// Returns the stage color as a Flutter [Color].
  /// Uses the API-provided hex color, falling back to a neutral slate.
  Color get stageColor {
    if (color != null && color!.trim().isNotEmpty) {
      try {
        final hex = color!.trim().replaceFirst('#', '');
        final fullHex = hex.length == 6 ? 'FF$hex' : hex;
        return Color(int.parse(fullHex, radix: 16));
      } catch (_) {}
    }
    return const Color(0xFF64748B); // Slate — generic fallback
  }

  /// Returns the stage background color as a Flutter [Color].
  Color get stageBgColor {
    if (bgColor != null && bgColor!.trim().isNotEmpty) {
      try {
        final hex = bgColor!.trim().replaceFirst('#', '');
        final fullHex = hex.length == 6 ? 'FF$hex' : hex;
        return Color(int.parse(fullHex, radix: 16));
      } catch (_) {}
    }
    return const Color(0xFFF1F5F9); // Slate-100 — generic fallback
  }

  /// Returns the stage border color as a Flutter [Color].
  Color get stageBorderColor {
    if (borderColor != null && borderColor!.trim().isNotEmpty) {
      try {
        final hex = borderColor!.trim().replaceFirst('#', '');
        final fullHex = hex.length == 6 ? 'FF$hex' : hex;
        return Color(int.parse(fullHex, radix: 16));
      } catch (_) {}
    }
    return const Color(0xFFE2E8F0); // Slate-200 — generic fallback
  }

  @override
  String toString() =>
      'LeadStageModel(id: $id, key: $key, name: $name, sortOrder: $sortOrder)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LeadStageModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  /// Normalizes stage tokens so NEW, New, and new compare equal.
  static String normalizeToken(String? value) {
    return (value ?? '').trim().toUpperCase().replaceAll(
      RegExp(r'[\s_\-]+'),
      '',
    );
  }

  /// Canonical stage resolution for a Lead from configured stages.
  /// Prefer exact stageId, then stageId as key/name, then status, then stage name.
  static LeadStageModel? resolve({
    required List<LeadStageModel> stages,
    String? stageId,
    String? status,
    String? stageName,
  }) {
    if (stages.isEmpty) return null;

    final rawId = stageId?.trim();
    if (rawId != null && rawId.isNotEmpty && rawId.toLowerCase() != 'null') {
      for (final s in stages) {
        if (s.id.toString() == rawId) return s;
      }
      final nid = normalizeToken(rawId);
      if (nid.isNotEmpty) {
        for (final s in stages) {
          if (normalizeToken(s.key) == nid || normalizeToken(s.name) == nid) {
            return s;
          }
        }
      }
    }

    final rawStatus = status?.trim();
    if (rawStatus != null && rawStatus.isNotEmpty) {
      final ns = normalizeToken(rawStatus);
      if (ns.isNotEmpty) {
        for (final s in stages) {
          if (normalizeToken(s.key) == ns || normalizeToken(s.name) == ns) {
            return s;
          }
        }
      }
    }

    final rawName = stageName?.trim();
    if (rawName != null && rawName.isNotEmpty) {
      final nn = normalizeToken(rawName);
      if (nn.isNotEmpty) {
        for (final s in stages) {
          if (normalizeToken(s.key) == nn || normalizeToken(s.name) == nn) {
            return s;
          }
        }
      }
    }

    return null;
  }
}
