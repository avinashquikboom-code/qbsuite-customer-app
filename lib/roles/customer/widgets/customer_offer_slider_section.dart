import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/current_customer_viewmodel.dart';
import 'package:quickboom_company_admin/roles/company_admin/views/calendar/admin_customer_calendar_view.dart';
import '../models/marketing_banner_model.dart';
import '../viewmodels/customer_marketing_viewmodel.dart';

/// Main Promotional Banner Widget for Customer Home Screen.
/// Displays real marketing promotional banner images from the backend API.
class CustomerOfferSliderSection extends ConsumerStatefulWidget {
  final bool autoScroll;
  final void Function(int tabIndex)? onNavigateToTab;
  final double? height;

  const CustomerOfferSliderSection({
    super.key,
    this.autoScroll = true,
    this.onNavigateToTab,
    this.height,
  });

  @override
  ConsumerState<CustomerOfferSliderSection> createState() =>
      _CustomerOfferSliderSectionState();
}

class _CustomerOfferSliderSectionState
    extends ConsumerState<CustomerOfferSliderSection> {
  late final PageController _pageCtrl;
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
    _pageCtrl = PageController(initialPage: 0);
  }

  void _setupAutoScroll(int totalBanners) {
    _autoScrollTimer?.cancel();
    if (!widget.autoScroll || totalBanners <= 1) return;

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      if (_pageCtrl.hasClients) {
        final nextPage = (_currentPage + 1) % totalBanners;
        _pageCtrl.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  Future<void> _handleBannerTap(
    BuildContext context,
    MarketingBannerModel banner,
  ) async {
    final action = banner.actionType?.trim().toUpperCase();
    if (action == 'NONE') return;

    final rawUrl = banner.ctaUrl?.trim();
    final effectiveAction =
        action ??
        ((rawUrl != null &&
                (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')))
            ? 'OPEN_URL'
            : (rawUrl != null &&
                  (rawUrl.contains('/orders') ||
                      rawUrl.toLowerCase() == 'orders'))
            ? 'OPEN_ORDERS'
            : 'OPEN_PLAN');

    // 1. Plan Destination
    if (effectiveAction == 'OPEN_PLAN' ||
        (rawUrl != null &&
            (rawUrl.contains('/plans') || rawUrl.toLowerCase() == 'plans'))) {
      if (widget.onNavigateToTab != null) {
        widget.onNavigateToTab!(1); // Tab 1 is Subscription Plans
        return;
      }
    }

    // 2. Orders & Invoices Destination
    if (action == 'OPEN_ORDERS' ||
        (rawUrl != null &&
            (rawUrl.contains('/orders') || rawUrl.toLowerCase() == 'orders'))) {
      if (widget.onNavigateToTab != null) {
        widget.onNavigateToTab!(3); // Tab 3 is Orders
        return;
      }
    }

    // 3. Customer Calendar Destination
    if (action == 'OPEN_CALENDAR' ||
        (rawUrl != null &&
            (rawUrl.contains('/calendar') ||
                rawUrl.toLowerCase() == 'calendar'))) {
      final customerIdAsync = ref.read(currentCustomerIdProvider);
      final customerId = customerIdAsync.asData?.value ?? customerIdAsync.value;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminCustomerCalendarView(
            initialDate: DateTime.now(),
            isCustomerScope: true,
            customerId: customerId,
          ),
        ),
      );
      return;
    }

    // 4. Offer Details Sheet
    if (action == 'OPEN_DETAILS') {
      _showBannerDetailsSheet(context, banner);
      return;
    }

    // 5. External Web URL
    if (rawUrl != null &&
        rawUrl.isNotEmpty &&
        (rawUrl.startsWith('http://') ||
            rawUrl.startsWith('https://') ||
            action == 'OPEN_URL')) {
      try {
        String formattedUrl = rawUrl;
        if (!formattedUrl.startsWith('http://') &&
            !formattedUrl.startsWith('https://')) {
          formattedUrl = 'https://$formattedUrl';
        }
        final uri = Uri.tryParse(formattedUrl);
        if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          }
        }
      } catch (e) {
        debugPrint('[BANNER_URL_LAUNCH_ERROR] $e');
      }
    }

    // 6. If has couponCode, copy it
    if (banner.couponCode != null && banner.couponCode!.trim().isNotEmpty) {
      Clipboard.setData(ClipboardData(text: banner.couponCode!.trim()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Remix.checkbox_circle_fill,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Coupon code "${banner.couponCode}" copied to clipboard!',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primaryDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 7. Fallback: Show Banner Offer Details Bottom Sheet
    if (context.mounted) {
      _showBannerDetailsSheet(context, banner);
    }
  }

  /// CTA buttons always open the exact link configured for this banner.  They
  /// intentionally have no destination fallback: a missing link means no CTA.
  Future<void> _handleCtaTap(MarketingBannerModel banner) async {
    if (banner.ctaUrl == null || banner.ctaUrl!.trim().isEmpty) return;

    final uri = Uri.tryParse(banner.ctaUrl!.trim());
    if (uri == null) {
      debugPrint('[BANNER_CTA_URL_INVALID] ${banner.ctaUrl}');
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        debugPrint('[BANNER_CTA_URL_LAUNCH_FAILED] $uri');
      }
    } catch (error) {
      debugPrint('[BANNER_CTA_URL_LAUNCH_ERROR] $error');
    }
  }

  void _showBannerDetailsSheet(
    BuildContext context,
    MarketingBannerModel banner,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (banner.title != null)
                Text(
                  banner.title!,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              if (banner.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  banner.subtitle!,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (banner.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  banner.description!,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
              if (banner.couponCode != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'COUPON CODE',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          Text(
                            banner.couponCode!,
                            style: GoogleFonts.robotoMono(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: banner.couponCode!),
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Coupon code "${banner.couponCode}" copied to clipboard!',
                              ),
                              backgroundColor: AppColors.primaryDark,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Remix.file_copy_line, size: 16),
                        label: const Text('Copy'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (banner.ctaUrl != null &&
                  banner.ctaUrl!.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleCtaTap(banner);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        banner.ctaText != null &&
                            banner.ctaText!.trim().isNotEmpty
                        ? Text(
                            banner.ctaText!.trim(),
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const Icon(Remix.arrow_right_s_line),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(customerHomeBannersProvider);

    if (bannersAsync.hasError) {
      return const SizedBox.shrink();
    }

    if (bannersAsync.isLoading) {
      return _buildSkeletonLoading(context);
    }

    final allBanners = bannersAsync.value ?? const [];
    final now = DateTime.now();
    final banners = allBanners.where((b) {
      if (!b.isActive || !b.isPublished) return false;
      if (b.startAt != null && b.startAt!.isAfter(now)) return false;
      if (b.endAt != null && b.endAt!.isBefore(now)) return false;
      return b.effectiveImageUrl.isNotEmpty ||
          (b.title != null && b.title!.isNotEmpty);
    }).toList();

    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    final isMultiple = banners.length > 1;
    if (isMultiple) {
      _setupAutoScroll(banners.length);
    } else {
      _autoScrollTimer?.cancel();
    }

    final isTablet = (widget.height != null && widget.height! > 180);
    final sectionHeight = widget.height ?? 156.0;

    return SizedBox(
      height: sectionHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: isMultiple
                ? PageView.builder(
                    controller: _pageCtrl,
                    itemCount: banners.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildBannerCard(
                        context,
                        banners[index],
                        isTablet: isTablet,
                      );
                    },
                  )
                : _buildBannerCard(
                    context,
                    banners.first,
                    isTablet: isTablet,
                  ),
          ),
          if (isMultiple)
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: IgnorePointer(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(banners.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading(BuildContext context) {
    final sectionHeight = widget.height ?? 156.0;
    return Container(
      height: sectionHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildBannerImage(MarketingBannerModel banner, {bool isTablet = false}) {
    final imageUrl = banner.effectiveImageUrl;

    if (imageUrl.isEmpty) {
      return _buildFallbackBackground();
    }

    final isBase64 = imageUrl.startsWith('data:image');
    Uint8List? memoryBytes;
    if (isBase64) {
      try {
        final commaIdx = imageUrl.indexOf(',');
        final base64Str = commaIdx != -1
            ? imageUrl.substring(commaIdx + 1)
            : imageUrl;
        memoryBytes = base64Decode(base64Str);
      } catch (e) {
        debugPrint('Banner base64 decode failed: $e');
        return _buildFallbackBackground();
      }
    }

    final foregroundFit = isTablet ? BoxFit.contain : BoxFit.cover;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Ambient Blurred Background Layer on wide tablet displays
        if (isTablet) ...[
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Transform.scale(
                scale: 1.15,
                child: isBase64 && memoryBytes != null
                    ? Image.memory(
                        memoryBytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackBackground(),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackBackground(),
                      ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.12),
            ),
          ),
        ],

        // 2. Main Foreground Banner Image (contain on tablet so text & heads are never cropped)
        Positioned.fill(
          child: isBase64 && memoryBytes != null
              ? Image.memory(
                  memoryBytes,
                  fit: foregroundFit,
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Banner memory image failed: $error');
                    return _buildFallbackBackground();
                  },
                )
              : Image.network(
                  imageUrl,
                  fit: foregroundFit,
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildFallbackBackground();
                  },
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('[BANNER_IMAGE_ERROR] url: $imageUrl, error: $error');
                    return _buildFallbackBackground();
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFallbackBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildBannerCard(
    BuildContext context,
    MarketingBannerModel banner, {
    bool isTablet = false,
  }) {
    final hasImage = banner.effectiveImageUrl.isNotEmpty;
    final hasTitle =
        banner.title != null &&
        banner.title!.trim().isNotEmpty &&
        banner.title!.trim().toLowerCase() != 'home banner';
    final hasSubtitle =
        banner.subtitle != null && banner.subtitle!.trim().isNotEmpty;
    final hasDescription =
        banner.description != null && banner.description!.trim().isNotEmpty;
    final hasCtaLink =
        banner.ctaUrl != null && banner.ctaUrl!.trim().isNotEmpty;
    final hasCtaText =
        banner.ctaText != null && banner.ctaText!.trim().isNotEmpty;
    final ctaButtonText = hasCtaText
        ? banner.ctaText!.trim()
        : (hasCtaLink ? 'Claim Offer' : null);

    final hasContentOverlay =
        hasTitle || hasSubtitle || hasDescription || hasCtaLink;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleBannerTap(context, banner),
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Base Image Layer
                hasImage
                    ? _buildBannerImage(banner, isTablet: isTablet)
                    : _buildFallbackBackground(),

                // 2. Content Overlay Layer
                if (hasContentOverlay) ...[
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 90,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                            Colors.black.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Left: Title & Subtitle/Description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasTitle)
                                Text(
                                  banner.title!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.75,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (hasSubtitle || hasDescription) ...[
                                const SizedBox(height: 2),
                                Text(
                                  hasSubtitle
                                      ? banner.subtitle!
                                      : banner.description!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    color: const Color(0xFFE2E8F0),
                                    fontWeight: FontWeight.w400,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.75,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Right: Dynamic CTA Action Button
                        if (hasCtaLink) ...[
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _handleCtaTap(banner),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.45,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (ctaButtonText != null) ...[
                                    Text(
                                      ctaButtonText,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  const Icon(
                                    Remix.arrow_right_s_line,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
