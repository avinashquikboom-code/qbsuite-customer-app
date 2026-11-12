import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';

/// Redesigned Modern Social Media Card.
/// Displays connected social accounts & profiles (Instagram, Facebook, YouTube,
/// LinkedIn, X/Twitter, TikTok, Pinterest, Website) with rich brand styling,
/// clean handle previews, copy-to-clipboard, and direct external launch.
class LeadSocialMediaCard extends StatelessWidget {
  final LeadModel lead;

  const LeadSocialMediaCard({super.key, required this.lead});

  Future<void> _launch(BuildContext context, String url) async {
    String formattedUrl = url.trim();
    if (!formattedUrl.startsWith('http://') &&
        !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }
    final uri = Uri.parse(formattedUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          _showToast(context, 'Could not open $formattedUrl');
        }
      }
    } catch (_) {
      if (context.mounted) {
        _showToast(context, 'Could not open URL');
      }
    }
  }

  void _copyToClipboard(
    BuildContext context,
    String text,
    String platformName,
  ) {
    Clipboard.setData(ClipboardData(text: text));
    _showToast(context, 'Copied $platformName link to clipboard');
  }

  void _showToast(BuildContext context, String message) {
    // Toast messages disabled across mobile app
  }

  String _cleanHandle(String raw, String platform) {
    var val = raw.trim();
    if (val.isEmpty) return '';

    // Strip trailing slashes
    while (val.endsWith('/')) {
      val = val.substring(0, val.length - 1);
    }

    // If it's a full URL, extract the last meaningful segment or clean display
    if (val.startsWith('http://') || val.startsWith('https://')) {
      try {
        final uri = Uri.parse(val);
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) {
          final last = segments.last;
          if (platform == 'Instagram' ||
              platform == 'X (Twitter)' ||
              platform == 'TikTok') {
            return last.startsWith('@') ? last : '@$last';
          }
          return '${uri.host}/${segments.join('/')}';
        }
        return uri.host;
      } catch (_) {}
    }

    if (platform == 'Instagram' ||
        platform == 'X (Twitter)' ||
        platform == 'TikTok') {
      return val.startsWith('@') ? val : '@$val';
    }
    return val;
  }

  @override
  Widget build(BuildContext context) {
    final s = lead.socialMedia;
    final platforms = <_SocialPlatformItem>[];

    if (s?.instagram != null && s!.instagram!.trim().isNotEmpty) {
      final raw = s.instagram!.trim();
      final url = raw.startsWith('http')
          ? raw
          : raw.startsWith('instagram.com')
          ? 'https://$raw'
          : 'https://instagram.com/${raw.replaceFirst('@', '')}';
      platforms.add(
        _SocialPlatformItem(
          label: 'Instagram',
          handle: _cleanHandle(raw, 'Instagram'),
          icon: Remix.instagram_line,
          brandColor: const Color(0xFFE1306C),
          gradient: const LinearGradient(
            colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          url: url,
        ),
      );
    }

    if (s?.facebook != null && s!.facebook!.trim().isNotEmpty) {
      final raw = s.facebook!.trim();
      final url = raw.startsWith('http')
          ? raw
          : raw.startsWith('facebook.com')
          ? 'https://$raw'
          : 'https://facebook.com/$raw';
      platforms.add(
        _SocialPlatformItem(
          label: 'Facebook',
          handle: _cleanHandle(raw, 'Facebook'),
          icon: Remix.facebook_fill,
          brandColor: const Color(0xFF1877F2),
          gradient: const LinearGradient(
            colors: [Color(0xFF1877F2), Color(0xFF0C5DC7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          url: url,
        ),
      );
    }

    if (s?.youtube != null && s!.youtube!.trim().isNotEmpty) {
      final raw = s.youtube!.trim();
      final url = raw.startsWith('http')
          ? raw
          : raw.startsWith('youtube.com')
          ? 'https://$raw'
          : 'https://youtube.com/${raw.startsWith('@') ? raw : '@$raw'}';
      platforms.add(
        _SocialPlatformItem(
          label: 'YouTube',
          handle: _cleanHandle(raw, 'YouTube'),
          icon: Remix.youtube_fill,
          brandColor: const Color(0xFFFF0000),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          url: url,
        ),
      );
    }

    if (s?.linkedin != null && s!.linkedin!.trim().isNotEmpty) {
      final raw = s.linkedin!.trim();
      final url = raw.startsWith('http')
          ? raw
          : raw.startsWith('linkedin.com')
          ? 'https://$raw'
          : raw.contains('/')
          ? 'https://linkedin.com/$raw'
          : 'https://linkedin.com/in/$raw';
      platforms.add(
        _SocialPlatformItem(
          label: 'LinkedIn',
          handle: _cleanHandle(raw, 'LinkedIn'),
          icon: Remix.linkedin_fill,
          brandColor: const Color(0xFF0A66C2),
          gradient: const LinearGradient(
            colors: [Color(0xFF0A66C2), Color(0xFF084E96)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          url: url,
        ),
      );
    }

    if (s?.twitter != null && s!.twitter!.trim().isNotEmpty) {
      final raw = s.twitter!.trim();
      final url = raw.startsWith('http')
          ? raw
          : raw.startsWith('twitter.com') || raw.startsWith('x.com')
          ? 'https://$raw'
          : 'https://x.com/${raw.replaceFirst('@', '')}';
      platforms.add(
        _SocialPlatformItem(
          label: 'X (Twitter)',
          handle: _cleanHandle(raw, 'X (Twitter)'),
          icon: Remix.twitter_x_line,
          brandColor: const Color(0xFF0F172A),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          url: url,
        ),
      );
    }

    if (s?.tiktok != null && s!.tiktok!.trim().isNotEmpty) {
      final raw = s.tiktok!.trim();
      final url = raw.startsWith('http')
          ? raw
          : raw.startsWith('tiktok.com')
          ? 'https://$raw'
          : 'https://tiktok.com/@${raw.replaceFirst('@', '')}';
      platforms.add(
        _SocialPlatformItem(
          label: 'TikTok',
          handle: _cleanHandle(raw, 'TikTok'),
          icon: Remix.tiktok_fill,
          brandColor: const Color(0xFF000000),
          gradient: const LinearGradient(
            colors: [Color(0xFF00F2FE), Color(0xFF4FACFE), Color(0xFF000000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          url: url,
        ),
      );
    }

    if (s?.pinterest != null && s!.pinterest!.trim().isNotEmpty) {
      final raw = s.pinterest!.trim();
      final url = raw.startsWith('http')
          ? raw
          : raw.startsWith('pinterest.com')
          ? 'https://$raw'
          : 'https://pinterest.com/$raw';
      platforms.add(
        _SocialPlatformItem(
          label: 'Pinterest',
          handle: _cleanHandle(raw, 'Pinterest'),
          icon: Remix.pinterest_fill,
          brandColor: const Color(0xFFE60023),
          gradient: const LinearGradient(
            colors: [Color(0xFFE60023), Color(0xFFAD0019)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          url: url,
        ),
      );
    }

    // Optional website inclusion
    final webUrl = s?.website ?? lead.website;
    if (webUrl != null &&
        webUrl.trim().isNotEmpty &&
        !platforms.any((p) => p.label == 'Website')) {
      final raw = webUrl.trim();
      final url = raw.startsWith('http://') || raw.startsWith('https://')
          ? raw
          : 'https://$raw';
      platforms.add(
        _SocialPlatformItem(
          label: 'Website',
          handle: _cleanHandle(raw, 'Website'),
          icon: Remix.global_line,
          brandColor: const Color(0xFF0D9488),
          gradient: const LinearGradient(
            colors: [Color(0xFF0D9488), Color(0xFF047857)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          url: url,
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 0,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Remix.share_circle_line,
                size: 15,
                color: Color(0xFF475569),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Social Media Presence',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: platforms.isNotEmpty
                              ? const Color(0xFF10B981)
                              : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${platforms.length} Found',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            children: [
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),
              if (platforms.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Remix.share_circle_line,
                          size: 26,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'No social media handles added',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                for (int i = 0; i < platforms.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _buildPlatformTile(context, platforms[i]),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformTile(BuildContext context, _SocialPlatformItem p) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launch(context, p.url),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
          ),
          child: Row(
            children: [
              // Brand Icon with gradient
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: p.gradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: p.brandColor.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(p.icon, size: 18, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),

              // Platform Name & Handle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.label,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      p.handle,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Copy Button
              Tooltip(
                message: 'Copy ${p.label} link',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _copyToClipboard(context, p.url, p.label),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Remix.file_copy_line,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Open Pill Button
              Tooltip(
                message: 'Open ${p.label}',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _launch(context, p.url),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: p.brandColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: p.brandColor.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Open',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: p.brandColor,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Remix.arrow_right_up_line,
                            size: 12,
                            color: p.brandColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialPlatformItem {
  final String label;
  final String handle;
  final IconData icon;
  final Color brandColor;
  final LinearGradient gradient;
  final String url;

  _SocialPlatformItem({
    required this.label,
    required this.handle,
    required this.icon,
    required this.brandColor,
    required this.gradient,
    required this.url,
  });
}
