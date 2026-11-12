import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/permission_manager.dart';
import '../../../shared/widgets/permission_guarded_view.dart';
import '../models/influencer_model.dart';
import '../viewmodels/customer_influencer_viewmodel.dart';
import 'customer_influencer_profile_view.dart';
import 'influencer_registration_view.dart';

/// Screen 1 — Customer Influencer Listing
/// Visual source of truth: Screen 1 of reference_screens.jpeg
class CustomerInfluencersListView extends ConsumerStatefulWidget {
  final String? initialCategory;

  const CustomerInfluencersListView({super.key, this.initialCategory});

  @override
  ConsumerState<CustomerInfluencersListView> createState() =>
      _CustomerInfluencersListViewState();
}

class _CustomerInfluencersListViewState
    extends ConsumerState<CustomerInfluencersListView> {
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  final List<Map<String, dynamic>> _categoryData = [
    {
      'title': 'Instagram\nInfluencers',
      'slug': 'instagram',
      'icon': Remix.instagram_line,
      'color': Color(0xFFE1306C),
      'bgColor': Color(0xFFFDF2F8),
    },
    {
      'title': 'YouTube\nCreators',
      'slug': 'youtube',
      'icon': Remix.youtube_line,
      'color': Color(0xFFFF0000),
      'bgColor': Color(0xFFFEF2F2),
    },
    {
      'title': 'Local\nInfluencers',
      'slug': 'local',
      'icon': Remix.map_pin_2_line,
      'color': Color(0xFF10B981),
      'bgColor': Color(0xFFECFDF5),
    },
    {
      'title': 'Fashion\nInfluencers',
      'slug': 'fashion',
      'icon': Remix.t_shirt_2_line,
      'color': Color(0xFF8B5CF6),
      'bgColor': Color(0xFFF5F3FF),
    },
    {
      'title': 'Food\nBloggers',
      'slug': 'food',
      'icon': Remix.restaurant_line,
      'color': Color(0xFFF59E0B),
      'bgColor': Color(0xFFFFFBEB),
    },
    {
      'title': 'Travel\nCreators',
      'slug': 'travel',
      'icon': Remix.compass_3_line,
      'color': Color(0xFF0284C7),
      'bgColor': Color(0xFFF0F9FF),
    },
    {
      'title': 'Fitness\nInfluencers',
      'slug': 'fitness',
      'icon': Remix.heart_pulse_line,
      'color': Color(0xFFEC4899),
      'bgColor': Color(0xFFFDF2F8),
    },
    {
      'title': 'Mom & Kids\nInfluencers',
      'slug': 'mom_kids',
      'icon': Remix.parent_line,
      'color': Color(0xFF14B8A6),
      'bgColor': Color(0xFFF0FDFA),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionManagerProvider);
    if (!perms.customerCan('CUSTOMER_INFLUENCERS', 'VIEW')) {
      return const PermissionGuardedView(
        moduleKey: 'CUSTOMER_INFLUENCERS',
        moduleTitle: 'Influencer Hub',
        child: SizedBox.shrink(),
      );
    }

    final influencersAsync = ref.watch(
      customerAllInfluencersProvider(_selectedCategory),
    );
    final favorites = ref.watch(influencerFavoritesNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header (QB Suite • CUSTOMER WORKSPACE + Notification + Menu)
            _buildTopHeader(context),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // Influencer Hub Promo Card
                    _buildHubPromoBanner(),

                    const SizedBox(height: 18),

                    // Categories Grid (4x2)
                    _buildCategoriesGrid(),

                    const SizedBox(height: 22),

                    // Featured Influencers Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Featured Influencers',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = null;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View All',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Remix.arrow_right_s_line,
                                size: 16,
                                color: AppColors.primaryDark,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Influencer Grid
                    influencersAsync.when(
                      data: (creators) {
                        final list = _selectedCategory == null
                            ? creators
                            : creators
                                  .where(
                                    (c) =>
                                        c.categoryName.toLowerCase().contains(
                                          _selectedCategory!.toLowerCase(),
                                        ) ||
                                        (c.categoryId?.toString() ==
                                            _selectedCategory),
                                  )
                                  .toList();

                        if (list.isEmpty) {
                          final bool isFiltered = _selectedCategory != null;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 36),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(
                                    Remix.user_search_line,
                                    size: 40,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isFiltered
                                        ? 'No influencers available in this category'
                                        : 'No influencers available',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (isFiltered) ...[
                                    const SizedBox(height: 4),
                                    TextButton(
                                      onPressed: () => setState(
                                        () => _selectedCategory = null,
                                      ),
                                      child: Text(
                                        'View All Influencers',
                                        style: GoogleFonts.outfit(
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: 320,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 14,
                              ),
                          itemCount: list.length,
                          itemBuilder: (ctx, idx) {
                            final creator = list[idx];
                            final isFav = favorites.contains(creator.id);
                            return _buildInfluencerCard(
                              context,
                              creator,
                              isFav,
                            );
                          },
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      error: (err, st) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Remix.error_warning_line,
                                color: Colors.red,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Unable to load creators',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              TextButton(
                                onPressed: () => ref.refresh(
                                  customerAllInfluencersProvider(
                                    _selectedCategory,
                                  ),
                                ),
                                child: Text(
                                  'Retry',
                                  style: GoogleFonts.outfit(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        children: [
          // Back button if popped, else logo
          Navigator.canPop(context)
              ? const BackButton(color: AppColors.textPrimary)
              : Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Remix.building_2_fill,
                      color: AppColors.primaryDark,
                      size: 20,
                    ),
                  ),
                ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'QB Suite',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                Text(
                  'CUSTOMER WORKSPACE',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Remix.notification_3_line,
              color: AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 14),
          IconButton(
            icon: const Icon(
              Remix.menu_line,
              color: AppColors.textPrimary,
              size: 22,
            ),
            onPressed: () {
              Scaffold.maybeOf(context)?.openDrawer();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildHubPromoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
      ),
      child: Row(
        children: [
          // Star Icon badge
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Remix.star_fill, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          // Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Influencer Hub',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Find, Connect & Book Influencers\nfor Your Brand',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // Megaphone Graphic & Join Creator Action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Remix.megaphone_fill,
                    color: AppColors.primaryDark,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InfluencerRegistrationView(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Join as Creator',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.76,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemCount: _categoryData.length,
      itemBuilder: (ctx, idx) {
        final cat = _categoryData[idx];
        final isSelected = _selectedCategory == cat['slug'];

        return InkWell(
          onTap: () {
            setState(() {
              _selectedCategory = isSelected ? null : cat['slug'];
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryLight : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryDark
                        : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    cat['icon'] as IconData,
                    color: isSelected
                        ? AppColors.primaryDark
                        : cat['color'] as Color,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                cat['title'] as String,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primaryDark
                      : AppColors.textPrimary,
                  height: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfluencerCard(
    BuildContext context,
    InfluencerModel creator,
    bool isFav,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with badges
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13),
                ),
                child: creator.effectiveImageUrl.isNotEmpty
                    ? Image.network(
                        creator.effectiveImageUrl,
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) =>
                            _buildPlaceholderImage(),
                      )
                    : _buildPlaceholderImage(),
              ),
              // Top-left platform badge
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    creator.platform == 'YOUTUBE'
                        ? Remix.youtube_fill
                        : Remix.instagram_fill,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
              ),
              // Top-right Favorite Heart
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    ref
                        .read(influencerFavoritesNotifierProvider.notifier)
                        .toggleFavorite(creator.id);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? const Color(0xFFEF4444) : Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Details Section
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Verified Badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        creator.name,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (creator.isVerified) ...[
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.verified,
                        color: Color(0xFF3B82F6),
                        size: 14,
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 4),

                // Category pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    creator.categoryName,
                    style: GoogleFonts.outfit(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Location
                if (creator.location.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Remix.map_pin_2_line,
                        size: 11,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          creator.location,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],

                // Stats: Followers & Engagement
                Row(
                  children: [
                    const Icon(
                      Remix.user_3_line,
                      size: 11,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '${creator.followersCount} Followers',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Remix.sparkling_line,
                      size: 11,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '${creator.engagementRate}% Engagement',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Starting Price
                Text(
                  creator.pricing != null && creator.pricing! > 0
                      ? '₹${creator.pricing!.toStringAsFixed(0)} / ${creator.platform == 'YOUTUBE' ? 'Video' : 'Post'}'
                      : 'Price on Request',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                // View Profile CTA button
                SizedBox(
                  width: double.infinity,
                  height: 28,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomerInfluencerProfileView(creator: creator),
                        ),
                      );
                    },
                    child: Text(
                      'View Profile',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 130,
      width: double.infinity,
      color: const Color(0xFFE2E8F0),
      child: const Center(
        child: Icon(Remix.user_3_line, color: Color(0xFF94A3B8), size: 36),
      ),
    );
  }
}
