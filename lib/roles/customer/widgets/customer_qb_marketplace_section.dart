import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../models/marketplace_tool_model.dart';
import '../viewmodels/customer_marketplace_viewmodel.dart';
import '../views/custom_plan_builder_view.dart';
import '../views/customer_ai_studio_home_view.dart';
import '../views/customer_marketplace_tools_view.dart';
import '../views/customer_orders_view.dart';
import '../views/customer_support_view.dart';
import '../views/leads_view.dart';
import '../views/social_media_work_handler_view.dart';
import 'package:quickboom_crm_customer/screens/customer/calendar_screen.dart';

/// Redesigned "QB Marketplace" section displayed on the Customer Home Screen.
class CustomerQbMarketplaceSection extends ConsumerWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const CustomerQbMarketplaceSection({super.key, this.onNavigateToTab});

  void _openAllTools(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerMarketplaceToolsView()),
    );
  }

  void _handleToolNavigation(BuildContext context, MarketplaceToolModel tool) {
    if (tool.isComingSoon) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Remix.time_line, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${tool.title} is coming soon! Stay tuned.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final route = tool.route?.toLowerCase() ?? '';

    if (route.contains('social') || route.contains('whatsapp')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SocialMediaWorkHandlerView()),
      );
    } else if (route.contains('calendar') || route.contains('schedule')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerCalendarScreen()),
      );
    } else if (route.contains('lead') || route.contains('crm')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LeadsView()),
      );
    } else if (route.contains('order') ||
        route.contains('invoice') ||
        route.contains('billing')) {
      if (onNavigateToTab != null) {
        onNavigateToTab!(3); // Orders & Invoices tab
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CustomerOrdersView()),
        );
      }
    } else if (route.contains('ai') ||
        route.contains('content') ||
        route.contains('studio') ||
        tool.title.toLowerCase().contains('ai') ||
        tool.title.toLowerCase().contains('content')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerAiStudioHomeView()),
      );
    } else if (route.contains('plan')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomPlanBuilderView()),
      );
    } else if (route.contains('support') ||
        route.contains('email') ||
        route.contains('mail')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerSupportView()),
      );
    } else {
      _openAllTools(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolsAsync = ref.watch(customerMarketplaceToolsProvider);

    return toolsAsync.when(
      data: (tools) {
        if (tools.isEmpty) return const SizedBox.shrink();
        return _buildMarketplaceContainer(context, tools);
      },
      loading: () => const SizedBox.shrink(),
      error: (err, _) {
        debugPrint('[CustomerQbMarketplaceSection] Error loading tools: $err');
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMarketplaceContainer(
    BuildContext context,
    List<MarketplaceToolModel> tools,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header Row ──────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Vibrant Green Circular Icon with Marketplace/Bag Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Remix.shopping_bag_3_fill,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Title & Subtitle Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'QB Marketplace',
                      maxLines: 1,
                      style: GoogleFonts.outfit(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your Business Growth Tools in One Place 🚀',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // View All Pill Button
              InkWell(
                onTap: () => _openAllTools(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Remix.arrow_right_s_line,
                        size: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Horizontal Scrollable Row of Marketplace Tools ──────────────────
          SizedBox(
            height: 164,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: tools.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final tool = tools[index];
                return SizedBox(
                  width: 136,
                  child: _buildToolCard(context, tool),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, MarketplaceToolModel tool) {
    final badgeText = tool.badge?.trim();
    final hasBadge = badgeText != null && badgeText.isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _handleToolNavigation(context, tool),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9ECEF), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Squircle Icon + Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: tool.resolveSquircleDecoration(),
                    alignment: Alignment.center,
                    child: Icon(
                      tool.resolveIcon(),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Spacer(),
                  if (tool.isComingSoon)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'COMING SOON',
                            maxLines: 1,
                            style: GoogleFonts.outfit(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFB45309),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (hasBadge)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _badgeBgColor(badgeText),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            badgeText,
                            maxLines: 1,
                            style: GoogleFonts.outfit(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: _badgeTextColor(badgeText),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Tool Title
              Text(
                tool.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),

              // Tool Description
              Expanded(
                child: Text(
                  tool.subtitle?.isNotEmpty == true
                      ? tool.subtitle!
                      : tool.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF64748B),
                    height: 1.2,
                  ),
                ),
              ),

              // Bottom Launch Indicator
              if (tool.isComingSoon)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Remix.time_line,
                      color: Color(0xFF94A3B8),
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Coming Soon',
                          maxLines: 1,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Text(
                      'Open',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Remix.arrow_right_line,
                      color: AppColors.primary,
                      size: 12,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _badgeBgColor(String badge) {
    final b = badge.toUpperCase();
    if (b.contains('POPULAR') || b.contains('HOT')) {
      return const Color(0xFFFEF3C7);
    }
    if (b.contains('AI') || b.contains('SMART')) return const Color(0xFFEDE9FE);
    if (b.contains('NEW')) return const Color(0xFFDCFCE7);
    if (b.contains('GST') || b.contains('TAX')) return const Color(0xFFE0E7FF);
    return const Color(0xFFF1F5F9);
  }

  Color _badgeTextColor(String badge) {
    final b = badge.toUpperCase();
    if (b.contains('POPULAR') || b.contains('HOT')) {
      return const Color(0xFFB45309);
    }
    if (b.contains('AI') || b.contains('SMART')) return const Color(0xFF6D28D9);
    if (b.contains('NEW')) return const Color(0xFF15803D);
    if (b.contains('GST') || b.contains('TAX')) return const Color(0xFF4338CA);
    return const Color(0xFF475569);
  }
}
