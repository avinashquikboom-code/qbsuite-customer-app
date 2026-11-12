import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../models/marketplace_tool_model.dart';
import '../viewmodels/customer_marketplace_viewmodel.dart';
import 'custom_plan_builder_view.dart';
import 'customer_ai_studio_home_view.dart';
import 'customer_orders_view.dart';
import 'customer_support_view.dart';
import 'leads_view.dart';
import 'social_media_work_handler_view.dart';
import 'package:quickboom_crm_customer/screens/customer/calendar_screen.dart';

class CustomerMarketplaceToolsView extends ConsumerStatefulWidget {
  const CustomerMarketplaceToolsView({super.key});

  @override
  ConsumerState<CustomerMarketplaceToolsView> createState() =>
      _CustomerMarketplaceToolsViewState();
}

class _CustomerMarketplaceToolsViewState
    extends ConsumerState<CustomerMarketplaceToolsView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'ALL';

  final List<Map<String, String>> _categories = const [
    {'id': 'ALL', 'label': 'All Tools', 'icon': 'apps'},
    {'id': 'GROWTH_TOOLS', 'label': 'Growth & Marketing', 'icon': 'rocket'},
    {'id': 'CREATIVE_TOOLS', 'label': 'Creative & AI', 'icon': 'sparkles'},
    {'id': 'FINANCE_TOOLS', 'label': 'Finance & Billing', 'icon': 'bank_card'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleToolTap(BuildContext context, MarketplaceToolModel tool) {
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerOrdersView()),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tool.title} is active and ready in your workspace!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final toolsAsync = ref.watch(customerMarketplaceToolsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QB Marketplace',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Integrated Business & Marketing Suite',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Remix.refresh_line,
              color: AppColors.textSecondary,
              size: 20,
            ),
            tooltip: 'Refresh Tools',
            onPressed: () => ref
                .read(customerMarketplaceToolsProvider.notifier)
                .refreshTools(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await ref
              .read(customerMarketplaceToolsProvider.notifier)
              .refreshTools();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── Hero Banner ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _buildHeroBanner(),
              ),
            ),

            // ── Search & Filter Category Bar ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(
                          () => _searchQuery = val.trim().toLowerCase(),
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search tools, CRM, AI, marketing...',
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 13.5,
                            color: const Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Icon(
                            Remix.search_2_line,
                            size: 19,
                            color: Color(0xFF64748B),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Remix.close_circle_line,
                                    size: 18,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Filter Chips
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = _selectedCategory == cat['id'];

                          return InkWell(
                            onTap: () =>
                                setState(() => _selectedCategory = cat['id']!),
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : const Color(0xFFE2E8F0),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Center(
                                child: Text(
                                  cat['label']!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Tools Grid / List ────────────────────────────────────────────
            toolsAsync.when(
              data: (tools) {
                final filteredTools = tools.where((tool) {
                  final matchesSearch =
                      _searchQuery.isEmpty ||
                      tool.title.toLowerCase().contains(_searchQuery) ||
                      tool.description.toLowerCase().contains(_searchQuery) ||
                      (tool.subtitle?.toLowerCase().contains(_searchQuery) ??
                          false);
                  final matchesCat =
                      _selectedCategory == 'ALL' ||
                      tool.category.toUpperCase() == _selectedCategory;
                  return matchesSearch && matchesCat;
                }).toList();

                if (filteredTools.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final tool = filteredTools[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildRichToolCard(context, tool),
                      );
                    }, childCount: filteredTools.length),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: SkeletonList(count: 4),
              ),
              error: (err, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Remix.error_warning_line,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Unable to load tools catalog',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(customerMarketplaceToolsProvider.notifier)
                            .refreshTools(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        child: const Text(
                          'Try Again',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Remix.flashlight_fill,
                      size: 12,
                      color: Color(0xFF34D399),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'PRO TOOLS',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF34D399),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(
                Remix.shield_check_line,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Text(
                'Enterprise Ready',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Power Up Your Growth',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Explore specialized automation, messaging, CRM, and AI solutions integrated into your workspace.',
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFCBD5E1),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRichToolCard(BuildContext context, MarketplaceToolModel tool) {
    final badgeText = tool.badge?.trim();
    final hasBadge = badgeText != null && badgeText.isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _handleToolTap(context, tool),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon + Category/Badge + Action Arrow
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: tool.resolveSquircleDecoration(),
                    alignment: Alignment.center,
                    child: Icon(
                      tool.resolveIcon(),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tool.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (tool.isComingSoon)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'COMING SOON',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFB45309),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              )
                            else if (hasBadge)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: _badgeBgColor(badgeText),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badgeText,
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: _badgeTextColor(badgeText),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tool.subtitle?.isNotEmpty == true
                              ? tool.subtitle!
                              : _formatCategoryName(tool.category),
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                tool.description,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),

              // Bottom Row with Action Button
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatCategoryName(tool.category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Spacer(),
                  if (tool.isComingSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
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
                          const Icon(
                            Remix.time_line,
                            color: Color(0xFF64748B),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Coming Soon',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Open Tool',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Remix.arrow_right_line,
                            color: Color(0xFF15803D),
                            size: 13,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Remix.search_line,
                size: 28,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No tools found',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results matching "$_searchQuery" in this category.'
                  : 'No tools available under this category yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = 'ALL';
                });
              },
              icon: const Icon(
                Remix.refresh_line,
                size: 16,
                color: AppColors.primary,
              ),
              label: Text(
                'Reset Filters',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCategoryName(String raw) {
    switch (raw.toUpperCase()) {
      case 'GROWTH_TOOLS':
        return 'Growth & Marketing';
      case 'CREATIVE_TOOLS':
        return 'Creative & AI';
      case 'FINANCE_TOOLS':
        return 'Finance & Billing';
      default:
        return 'Business Tool';
    }
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
