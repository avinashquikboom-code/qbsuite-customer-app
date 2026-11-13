import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

class SocialAccountCard extends StatelessWidget {
  final String accountName;
  final String platform;
  final String? handle;

  const SocialAccountCard({
    super.key,
    required this.accountName,
    required this.platform,
    this.handle,
  });

  IconData _getPlatformIcon(String p) {
    final lower = p.toLowerCase();
    if (lower.contains('instagram')) return Remix.instagram_line;
    if (lower.contains('facebook')) return Remix.facebook_circle_line;
    if (lower.contains('youtube')) return Remix.youtube_line;
    if (lower.contains('linkedin')) return Remix.linkedin_box_line;
    return Remix.global_line;
  }

  Color _getPlatformColor(String p) {
    final lower = p.toLowerCase();
    if (lower.contains('instagram')) return const Color(0xFFE1306C);
    if (lower.contains('facebook')) return const Color(0xFF1877F2);
    if (lower.contains('youtube')) return const Color(0xFFFF0000);
    if (lower.contains('linkedin')) return const Color(0xFF0A66C2);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _getPlatformColor(platform);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getPlatformIcon(platform), color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accountName,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  handle ?? platform,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
