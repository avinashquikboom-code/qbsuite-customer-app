import 'package:material_ui/material_ui.dart';

/// Represents a CRM Lead Pipeline Stage returned by GET /leads/stages.
/// Single source of truth for all stage UI:
/// name, key, color, bgColor, borderColor, sortOrder, isActive.
class LeadStageModel {
  final int id;
  final String key;
  final String name;
  final int sortOrder;
  final bool isActive;
  final bool isDefault;
  final String? color;
  final String? bgColor;
  final String? borderColor;
  final int leadsCount;

  const LeadStageModel({
    required this.id,
    required this.key,
    required this.name,
    required this.sortOrder,
    this.isActive = true,
    this.isDefault = false,
    this.color,
    this.bgColor,
    this.borderColor,
    this.leadsCount = 0,
  });

  factory LeadStageModel.fromJson(Map<String, dynamic> json) {
    return LeadStageModel(
      id: _stageInt(json['id']),
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? json['label']?.toString() ?? '',
      sortOrder: _stageInt(json['sortOrder'] ?? json['order']),
      isActive: json['isActive'] != false,
      isDefault: json['isDefault'] == true || json['isSystem'] == true,
      color: json['color']?.toString(),
      bgColor: json['bgColor']?.toString(),
      borderColor: json['borderColor']?.toString(),
      leadsCount: _stageInt(json['leadsCount']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
    'name': name,
    'sortOrder': sortOrder,
    'isActive': isActive,
    'isDefault': isDefault,
    'color': color,
    'bgColor': bgColor,
    'borderColor': borderColor,
    'leadsCount': leadsCount,
  };

  Color get stageColor {
    if (color != null && color!.trim().isNotEmpty) {
      try {
        final hex = color!.trim().replaceFirst('#', '');
        final fullHex = hex.length == 6 ? 'FF$hex' : hex;
        return Color(int.parse(fullHex, radix: 16));
      } catch (_) {}
    }
    return const Color(0xFF0284C7);
  }

  Color get stageBgColor {
    if (bgColor != null && bgColor!.trim().isNotEmpty) {
      try {
        final hex = bgColor!.trim().replaceFirst('#', '');
        final fullHex = hex.length == 6 ? 'FF$hex' : hex;
        return Color(int.parse(fullHex, radix: 16));
      } catch (_) {}
    }
    return const Color(0xFFE0F2FE);
  }

  Color get stageBorderColor {
    if (borderColor != null && borderColor!.trim().isNotEmpty) {
      try {
        final hex = borderColor!.trim().replaceFirst('#', '');
        final fullHex = hex.length == 6 ? 'FF$hex' : hex;
        return Color(int.parse(fullHex, radix: 16));
      } catch (_) {}
    }
    return const Color(0xFFBAE6FD);
  }

  @override
  String toString() =>
      'LeadStageModel(id: $id, key: $key, name: $name, sortOrder: $sortOrder)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadStageModel &&
          (other.id == id || other.key.toUpperCase() == key.toUpperCase());

  @override
  int get hashCode => id.hashCode ^ key.hashCode;
}

int _stageInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
