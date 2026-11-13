import 'package:material_ui/material_ui.dart';

/// Reusable responsive Stage Badge for lead cards and pipeline views.
///
/// Ensures:
/// - Consistent height and padding
/// - Rounded capsule border
/// - Stage-specific color with subtle background opacity and border
/// - Responsive visual label: adapts cleanly on narrow devices (< 340px)
/// - Flexible and ellipsis-safe layout to prevent any RenderFlex overflow
class StageBadge extends StatelessWidget {
  final String stage;
  final Color color;
  final bool? showPrefix;
  final double? maxWidth;

  const StageBadge({
    super.key,
    required this.stage,
    required this.color,
    this.showPrefix,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 340;

    // Normalize stage text: remove existing 'Stage:' prefix if present to avoid duplication
    final cleanStage = stage
        .replaceFirst(RegExp(r'^Stage:\s*', caseSensitive: false), '')
        .trim();

    // Use prefix on normal/wide screens (>= 340px) or if explicitly requested.
    final bool includePrefix = showPrefix ?? !isNarrow;
    final String displayText = includePrefix
        ? 'Stage: $cleanStage'
        : cleanStage;

    // Responsive max constraint: never exceed 48% of screen width so title has ample room
    final effectiveMaxWidth = maxWidth ?? (screenWidth * 0.48);

    return Container(
      constraints: BoxConstraints(minHeight: 22, maxWidth: effectiveMaxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          height: 1.15,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
