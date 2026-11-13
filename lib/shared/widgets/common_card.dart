import 'package:material_ui/material_ui.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

/// Reusable theme-aware Card container for Employee, Customer, and Admin roles.
class CommonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;

  const CommonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.borderLight,
          width: 1,
        ),
        boxShadow:
            boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
