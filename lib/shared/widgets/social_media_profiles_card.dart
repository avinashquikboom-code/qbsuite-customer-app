import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/shared/models/social_media_model.dart';

/// Reusable Social Media Profiles Card for Lead Details and Data Capture Details screens.
///
/// Displays connected social profiles (Instagram, Facebook, LinkedIn, X, YouTube, TikTok, etc.)
/// with corresponding brand icons, handles, clickable external links, and copy-to-clipboard.
/// Hides gracefully when no social profiles are present.
class SocialMediaProfilesCard extends StatelessWidget {
  final dynamic socialMedia;
  final String? website;
  final String title;
  final bool showEmpty;

  const SocialMediaProfilesCard({
    super.key,
    required this.socialMedia,
    this.website,
    this.title = 'Social Media',
    this.showEmpty = false,
  });

  static Future<void> open(BuildContext context, SocialPlatformEntry entry) async {
    try {
      final uri = Uri.tryParse(entry.url);
      if (uri == null || !['http', 'https'].contains(uri.scheme)) {
        _showError(context, 'Invalid link for ${entry.platform}');
        return;
      }
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showError(context, 'Could not open ${entry.platform} profile');
      }
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'Could not open ${entry.platform} link');
      }
    }
  }

  void _copyToClipboard(BuildContext context, SocialPlatformEntry entry) {
    Clipboard.setData(ClipboardData(text: entry.url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${entry.platform} link to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static SocialPlatformEntry? websiteEntry(String? website) {
    final raw = website?.trim() ?? '';
    if (raw.isEmpty) return null;
    final url = raw.startsWith(RegExp(r'https?://', caseSensitive: false)) ? raw : 'https://$raw';
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) return null;
    return SocialPlatformEntry(
      platform: 'Website',
      platformKey: 'website',
      raw: raw,
      url: url,
      handle: uri.host,
      icon: Remix.global_line,
      brandColor: const Color(0xFF163A2E),
    );
  }

  static void _showError(BuildContext context, String message) {
    try {
      AppToast.error(context, message);
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = socialMedia is SocialMediaModel
        ? socialMedia as SocialMediaModel
        : SocialMediaModel.from(socialMedia);

    final websiteEntry = SocialMediaProfilesCard.websiteEntry(website);
    final entries = [
      ...?model?.entries,
      if (websiteEntry != null) websiteEntry,
    ];
    if (entries.isEmpty) {
      if (!showEmpty) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text('No social links available', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Remix.share_circle_line, size: 18, color: AppColors.primary),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${entries.length}',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          children: [
          ...entries.asMap().entries.map((item) {
            final index = item.key;
            final entry = item.value;
            final isLast = index == entries.length - 1;

            return Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => open(context, entry),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: entry.brandColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              entry.icon,
                              size: 19,
                              color: entry.brandColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.platform,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entry.handle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Remix.file_copy_line,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            ),
                            tooltip: 'Copy ${entry.platform} link',
                            onPressed: () => _copyToClipboard(context, entry),
                          ),
                          Icon(
                            Remix.external_link_line,
                            size: 18,
                            color: entry.brandColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  const Divider(height: 14, color: Color(0xFFF1F5F9)),
              ],
            );
          }),
          ],
        ),
      ),
      ),
    );
  }
}

/// Compact platform icons for a lead card. Hidden when the lead has no links.
class LeadSocialIconRow extends StatelessWidget {
  final dynamic socialMedia;
  final String? website;

  final bool showHandles;
  final bool wrap;

  const LeadSocialIconRow({super.key, required this.socialMedia, this.website, this.showHandles = false, this.wrap = false});

  @override
  Widget build(BuildContext context) {
    final model = socialMedia is SocialMediaModel ? socialMedia as SocialMediaModel : SocialMediaModel.from(socialMedia);
    final link = SocialMediaProfilesCard.websiteEntry(website);
    final entries = [...?model?.entries, if (link != null) link];
    if (entries.isEmpty) return const SizedBox.shrink();
    if (showHandles) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final entry in entries)
              InkWell(
                onTap: () => SocialMediaProfilesCard.open(context, entry),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: entry.brandColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(entry.icon, size: 14, color: entry.brandColor),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(entry.handle, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textPrimary)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }
    final icons = [
      for (final entry in entries)
        InkWell(
          onTap: () => SocialMediaProfilesCard.open(context, entry),
          borderRadius: BorderRadius.circular(8),
          child: Tooltip(
            message: entry.platform,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: entry.brandColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(entry.icon, size: 16, color: entry.brandColor),
            ),
          ),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: wrap
          ? Wrap(spacing: 8, runSpacing: 6, children: icons)
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [for (final icon in icons) Padding(padding: const EdgeInsets.only(right: 8), child: icon)]),
            ),
    );
  }
}
