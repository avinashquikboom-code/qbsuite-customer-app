import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/constants/app_bar_titles.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

/// Clean, modern AppBar for the Lead Details screen.
/// Follows: [Back] Lead Details [More]
/// More menu displays only authorized actions based on permissions.
class LeadHeader extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onChangeStage;
  final VoidCallback? onRefresh;
  final bool canEdit;
  final bool canDelete;
  final bool canChangeStage;
  final String title;

  const LeadHeader({
    super.key,
    this.onBack,
    this.onEdit,
    this.onDelete,
    this.onChangeStage,
    this.onRefresh,
    this.canEdit = false,
    this.canDelete = false,
    this.canChangeStage = false,
    this.title = AppBarTitles.leadDetails,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(
          Remix.arrow_left_line,
          color: AppColors.textPrimary,
          size: 22,
        ),
        tooltip: 'Back',
        onPressed: () {
          if (onBack != null) {
            onBack!();
          } else if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        if (canEdit && onEdit != null)
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              size: 20,
              color: AppColors.textPrimary,
            ),
            tooltip: 'Edit Lead',
            onPressed: onEdit,
          ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: AppColors.border.withValues(alpha: 0.6),
          height: 1.0,
        ),
      ),
    );
  }
}
