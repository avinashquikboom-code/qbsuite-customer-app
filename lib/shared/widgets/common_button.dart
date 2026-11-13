import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

enum CommonButtonVariant { primary, secondary, outline, text, danger }

/// Reusable, theme-aware button component across Employee, Customer, and Admin.
class CommonButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final Widget? icon;
  final CommonButtonVariant variant;
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const CommonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.variant = CommonButtonVariant.primary,
    this.width,
    this.height = 48,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDisabled = isDisabled || isLoading || onPressed == null;

    Color bgColor;
    Color textColor;
    BorderSide borderSide = BorderSide.none;

    switch (variant) {
      case CommonButtonVariant.primary:
        bgColor = effectiveDisabled
            ? AppColors.textMuted.withValues(alpha: 0.2)
            : AppColors.primary;
        textColor = effectiveDisabled ? AppColors.textMuted : Colors.white;
        break;
      case CommonButtonVariant.secondary:
        bgColor = effectiveDisabled ? AppColors.pillBg : AppColors.primaryLight;
        textColor = effectiveDisabled ? AppColors.textMuted : AppColors.primary;
        break;
      case CommonButtonVariant.outline:
        bgColor = Colors.transparent;
        textColor = effectiveDisabled ? AppColors.textMuted : AppColors.primary;
        borderSide = BorderSide(
          color: effectiveDisabled ? AppColors.borderLight : AppColors.primary,
          width: 1.5,
        );
        break;
      case CommonButtonVariant.text:
        bgColor = Colors.transparent;
        textColor = effectiveDisabled ? AppColors.textMuted : AppColors.primary;
        break;
      case CommonButtonVariant.danger:
        bgColor = effectiveDisabled
            ? AppColors.textMuted.withValues(alpha: 0.2)
            : AppColors.error;
        textColor = Colors.white;
        break;
    }

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        shape: borderSide != BorderSide.none
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                side: borderSide,
              )
            : null,
        child: InkWell(
          onTap: effectiveDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[icon!, const SizedBox(width: 8)],
                        Text(
                          label,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
