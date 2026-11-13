import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

/// Reusable search input with prefix search icon, clear action and debounce-ready callback.
class CommonSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final double height;

  const CommonSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
    this.height = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.textPlaceholder,
          ),
          prefixIcon: const Icon(
            Remix.search_2_line,
            color: AppColors.textSecondary,
            size: 18,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Remix.close_circle_fill,
                    size: 16,
                    color: AppColors.textPlaceholder,
                  ),
                  onPressed: () {
                    controller.clear();
                    onClear?.call();
                    onChanged?.call('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
