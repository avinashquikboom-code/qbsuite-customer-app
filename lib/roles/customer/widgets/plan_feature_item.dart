import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

/// Reusable Plan Feature Item with responsive layout and green checkmark
class PlanFeatureItem extends StatelessWidget {
  final String text;
  final bool isHighlighted;

  const PlanFeatureItem({
    super.key,
    required this.text,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 1.5, right: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Remix.check_line,
                size: 13,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                color: isHighlighted
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
