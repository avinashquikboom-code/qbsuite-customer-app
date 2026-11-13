import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

enum BadgeType {
  present,
  absent,
  halfDay,
  late,
  remote,
  leave,
  pending,
  approved,
  rejected,
  completed,
  inProgress,
  scheduled,
  offline,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeType type;

  const StatusBadge({super.key, required this.label, required this.type});

  @override
  Widget build(BuildContext context) {
    final config = _getBadgeConfig(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: config.borderColor, width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: config.textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  _BadgeStyle _getBadgeConfig(BadgeType type) {
    switch (type) {
      case BadgeType.present:
      case BadgeType.approved:
      case BadgeType.completed:
        return _BadgeStyle(
          backgroundColor: AppColors.success.withValues(alpha: 0.1),
          borderColor: AppColors.success.withValues(alpha: 0.3),
          textColor: AppColors.success,
        );

      case BadgeType.pending:
      case BadgeType.inProgress:
      case BadgeType.late:
        return _BadgeStyle(
          backgroundColor: AppColors.warning.withValues(alpha: 0.1),
          borderColor: AppColors.warning.withValues(alpha: 0.3),
          textColor: AppColors.warning,
        );

      case BadgeType.absent:
      case BadgeType.rejected:
        return _BadgeStyle(
          backgroundColor: AppColors.error.withValues(alpha: 0.1),
          borderColor: AppColors.error.withValues(alpha: 0.3),
          textColor: AppColors.error,
        );

      case BadgeType.remote:
      case BadgeType.scheduled:
        return _BadgeStyle(
          backgroundColor: AppColors.info.withValues(alpha: 0.1),
          borderColor: AppColors.info.withValues(alpha: 0.3),
          textColor: AppColors.info,
        );

      case BadgeType.halfDay:
      case BadgeType.leave:
        return _BadgeStyle(
          backgroundColor: Colors.purple.withValues(alpha: 0.1),
          borderColor: Colors.purple.withValues(alpha: 0.3),
          textColor: Colors.purple,
        );

      case BadgeType.offline:
        return _BadgeStyle(
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          borderColor: Colors.white.withValues(alpha: 0.3),
          textColor: Colors.white,
        );
    }
  }
}

class _BadgeStyle {
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  _BadgeStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });
}
