import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

/// Reusable theme-aware AppBar across all roles with responsive actions.
class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Color backgroundColor;
  final double elevation;
  final Widget? bottom;
  final double bottomHeight;

  const CommonAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.backgroundColor = Colors.white,
    this.elevation = 0,
    this.bottom,
    this.bottomHeight = 0,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + bottomHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: elevation,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading:
          leading ??
          (Navigator.canPop(context) && automaticallyImplyLeading
              ? const BackButton(color: AppColors.textPrimary)
              : null),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            Text(
              subtitle!,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
      actions: actions,
      bottom: bottom != null
          ? PreferredSize(
              preferredSize: Size.fromHeight(bottomHeight),
              child: bottom!,
            )
          : null,
    );
  }
}
