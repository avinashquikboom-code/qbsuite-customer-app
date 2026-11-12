import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import '../models/trending_content.dart';
import '../viewmodels/customer_trending_viewmodel.dart';
import 'reels_style_video_feed_view.dart';
import 'package:quickboom_crm_customer/roles/employee/views/notifications_view.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';

class CustomerTrendingView extends ConsumerStatefulWidget {
  const CustomerTrendingView({super.key});

  @override
  ConsumerState<CustomerTrendingView> createState() =>
      _CustomerTrendingViewState();
}

class _CustomerTrendingViewState extends ConsumerState<CustomerTrendingView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<int> _bookmarkedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Launches full-screen video viewer or image viewer for a campaign item
  void _handlePlayMedia(BuildContext context, TrendingContent item) {
    if (item.isVideo) {
      final allItems = ref.read(filteredTrendingContentProvider).value ?? [];
      final videoList = allItems.where((i) => i.isVideo).toList();
      final targetList = videoList.isNotEmpty ? videoList : [item];
      final initialIdx = targetList.indexWhere((v) => v.id == item.id);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ReelsStyleVideoFeedView(
            videos: targetList,
            initialIndex: initialIdx >= 0 ? initialIdx : 0,
          ),
        ),
      );
    } else {
      final displayUrl = item.effectiveMediaUrl.isNotEmpty
          ? item.effectiveMediaUrl
          : item.effectiveThumbnailUrl;

      if (displayUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No media preview available for this campaign.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  displayUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Image unavailable',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Opens bottom sheet with comprehensive campaign idea details & CTA
  void _showCampaignIdeaSheet(BuildContext context, TrendingContent item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Sheet Handle Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Content Scrollable Area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row with Platform & Category
                      Row(
                        children: [
                          _buildPlatformBadge(item),
                          const SizedBox(width: 8),
                          _buildCategoryPill(item),
                          const Spacer(),
                          Text(
                            item.shortDate,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.textPlaceholder,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Media Thumbnail Preview Banner
                      if (item.effectiveThumbnailUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.network(
                                item.effectiveThumbnailUrl,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      height: 140,
                                      color: AppColors.scaffoldBg,
                                      child: const Center(
                                        child: Icon(
                                          Remix.image_line,
                                          size: 36,
                                          color: AppColors.textPlaceholder,
                                        ),
                                      ),
                                    ),
                              ),
                              if (item.isVideo)
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    _handlePlayMedia(context, item);
                                  },
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.65,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Remix.play_fill,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 18),

                      // Title
                      Text(
                        item.title,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          height: 1.3,
                        ),
                      ),

                      // Description / Hook
                      if (item.description != null &&
                          item.description!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          item.description!,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Date & Objective
                      Row(
                        children: [
                          const Icon(
                            Remix.time_line,
                            size: 14,
                            color: AppColors.textPlaceholder,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.formattedDateTime,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPlaceholder,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.objective,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Real API Metrics Grid
                      if (_hasAnyMetric(item)) ...[
                        const SizedBox(height: 20),
                        Text(
                          'CAMPAIGN METRICS',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.textPlaceholder,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            if (item.formattedViews != null)
                              _buildMetricChip(
                                Remix.eye_line,
                                item.formattedViews!,
                                'Views',
                              ),
                            if (item.formattedLikes != null)
                              _buildMetricChip(
                                Remix.heart_line,
                                item.formattedLikes!,
                                'Likes',
                              ),
                            if (item.formattedShares != null)
                              _buildMetricChip(
                                Remix.share_forward_line,
                                item.formattedShares!,
                                'Shares',
                              ),
                            if (item.formattedComments != null)
                              _buildMetricChip(
                                Remix.message_2_line,
                                item.formattedComments!,
                                'Comments',
                              ),
                            if (item.formattedEngagement != null)
                              _buildMetricChip(
                                Remix.fire_line,
                                item.formattedEngagement!,
                                'Engagement',
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Action Button
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    if (item.isVideo) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _handlePlayMedia(context, item);
                          },
                          icon: Icon(
                            item.isYouTube
                                ? Remix.youtube_fill
                                : Remix.play_circle_fill,
                            size: 18,
                          ),
                          label: Text(
                            item.isYouTube ? 'Watch Video' : 'Play Reel',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: item.isYouTube
                                ? const Color(0xFFCC0000)
                                : AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Campaign idea "${item.title}" saved to your inspirations!',
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.primaryDark,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Use This Hook',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
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
      },
    );
  }

  bool _hasAnyMetric(TrendingContent item) {
    return item.formattedViews != null ||
        item.formattedLikes != null ||
        item.formattedShares != null ||
        item.formattedComments != null ||
        item.formattedEngagement != null;
  }

  Widget _buildMetricChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppColors.textPlaceholder,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionManagerProvider);
    final canViewTrending = perms.customerCan('CUSTOMER_TRENDING', 'VIEW');

    if (!canViewTrending) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: Navigator.canPop(context),
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Remix.arrow_left_line, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: Text(
            'Trending Campaigns',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Remix.lock_line,
                    size: 40,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You do not have permission to view Trending Campaigns. Please contact your administrator if you need access.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeFilter = ref.watch(selectedTrendingFilterProvider);
    final activeSort = ref.watch(trendingSortOptionProvider);
    final featuredItem = ref.watch(featuredTrendingItemProvider);
    final trendingAsync = ref.watch(filteredTrendingContentProvider);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 360;
    final isCompact = screenWidth < 400;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 900;

    final horizontalPadding = isNarrow ? 12.0 : (isTablet ? 24.0 : 16.0);

    final int crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    final double childAspectRatio = isDesktop
        ? 0.70
        : (isTablet
              ? 0.66
              : (screenWidth < 350
                    ? 0.57
                    : (screenWidth < 380
                          ? 0.60
                          : (screenWidth >= 430 ? 0.65 : 0.62))));

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await ref.read(customerTrendingListProvider.notifier).refresh();
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // 1. Top Trending Header (Title with "Trending" navy + "Campaigns" QB green, Subtitle, Circular buttons)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Green rounded-square icon containing the flame/trending icon
                          Container(
                            width: isNarrow ? 36 : 40,
                            height: isNarrow ? 36 : 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Remix.fire_fill,
                                color: Colors.white,
                                size: isNarrow ? 18 : 20,
                              ),
                            ),
                          ),
                          SizedBox(width: isNarrow ? 8 : 10),

                          // Title & Subtitle Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    style: GoogleFonts.outfit(
                                      fontSize: isNarrow
                                          ? 17.5
                                          : (isTablet ? 22.0 : 19.0),
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                    children: const [
                                      TextSpan(text: 'Trending '),
                                      TextSpan(
                                        text: 'Campaigns',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                // Subtitle: Must remain on ONE line across all supported mobile widths
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'High-converting reels, story hooks & offers',
                                    maxLines: 1,
                                    softWrap: false,
                                    style: GoogleFonts.outfit(
                                      fontSize: isNarrow
                                          ? 10.5
                                          : (isCompact ? 11.0 : 11.5),
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isNarrow ? 6 : 8),

                          // Notification and Refresh buttons on same horizontal baseline
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Notification Icon in circular button
                              if (ref.watch(permissionManagerProvider).customerCan('CUSTOMER_NOTIFICATIONS', 'VIEW')) ...[
                                Container(
                                  width: isNarrow ? 34 : 36,
                                  height: isNarrow ? 34 : 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.border),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.02,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const NotificationsView(),
                                        ),
                                      );
                                    },
                                    icon: Icon(
                                      Remix.notification_3_line,
                                      size: isNarrow ? 16 : 17,
                                      color: AppColors.textSecondary,
                                    ),
                                    tooltip: 'Notifications',
                                  ),
                                ),
                                SizedBox(width: isNarrow ? 6 : 8),
                              ],

                              // Refresh Icon in circular button
                              Container(
                                width: isNarrow ? 34 : 36,
                                height: isNarrow ? 34 : 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => ref
                                      .read(
                                        customerTrendingListProvider.notifier,
                                      )
                                      .refresh(),
                                  icon: Icon(
                                    Remix.refresh_line,
                                    size: isNarrow ? 16 : 17,
                                    color: AppColors.textSecondary,
                                  ),
                                  tooltip: 'Refresh Trending',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 2. Search Field with Left Search Icon & Right Microphone/Clear Icon
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            ref
                                .read(trendingSearchQueryProvider.notifier)
                                .setSearchQuery(val);
                          },
                          style: GoogleFonts.outfit(
                            fontSize: isNarrow ? 12.0 : 12.5,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText:
                                'Search trending reels, videos, hooks, ads...',
                            hintStyle: GoogleFonts.outfit(
                              fontSize: isNarrow ? 11.5 : 12.5,
                              color: AppColors.textPlaceholder,
                            ),
                            prefixIcon: const Icon(
                              Remix.search_2_line,
                              size: 17,
                              color: AppColors.textSecondary,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Remix.close_circle_line,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref
                                          .read(
                                            trendingSearchQueryProvider
                                                .notifier,
                                          )
                                          .setSearchQuery('');
                                      setState(() {});
                                    },
                                  )
                                : const Icon(
                                    Remix.mic_line,
                                    size: 17,
                                    color: AppColors.textPlaceholder,
                                  ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 11,
                              horizontal: 4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Horizontal Platform & Category Filter Chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 2),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Row(
                      children: TrendingPlatformFilter.values.map((filter) {
                        final isSelected = activeFilter == filter;
                        final chipLabel =
                            filter == TrendingPlatformFilter.allTrending
                            ? '★ All Trending'
                            : '${filter.emoji} ${filter.label}';

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              ref
                                  .read(selectedTrendingFilterProvider.notifier)
                                  .selectFilter(filter);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6.5,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.28,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Text(
                                chipLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // 4. Featured Trending Hero Banner ("Get Inspired. Create. Grow.")
              if (featuredItem != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      8,
                      horizontalPadding,
                      8,
                    ),
                    child: _buildFeaturedHeroBanner(
                      context,
                      featuredItem,
                      screenWidth,
                    ),
                  ),
                ),

              // 5. Content Type Tabs (Latest, Most Popular, Top Performing)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    8,
                  ),
                  child: Row(
                    children: TrendingSortOption.values.map((opt) {
                      final isSelected = activeSort == opt;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: opt != TrendingSortOption.values.last
                                ? (isNarrow ? 6 : 8)
                                : 0,
                          ),
                          child: InkWell(
                            onTap: () {
                              ref
                                  .read(trendingSortOptionProvider.notifier)
                                  .selectSort(opt);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(
                                horizontal: isNarrow ? 2 : 4,
                                vertical: 7.5,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  opt.label,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: isNarrow ? 10.0 : 11.0,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // 6. Section Header ("Trending Content" with green dot + dynamic count + "View All >")
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    8,
                  ),
                  child: Row(
                    children: [
                      // Green indicator dot beside title
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'Trending Content',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: isNarrow ? 14 : 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            trendingAsync.maybeWhen(
                              data: (items) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${items.length}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              orElse: () => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // "View All >" button
                      InkWell(
                        onTap: () {
                          ref
                              .read(selectedTrendingFilterProvider.notifier)
                              .selectFilter(TrendingPlatformFilter.allTrending);
                          _searchController.clear();
                          ref
                              .read(trendingSearchQueryProvider.notifier)
                              .setSearchQuery('');
                          setState(() {});
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View All',
                                style: GoogleFonts.outfit(
                                  fontSize: isNarrow ? 11.0 : 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 1),
                              const Icon(
                                Remix.arrow_right_s_line,
                                size: 13,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 7. Responsive Campaign Grid
              trendingAsync.when(
                loading: () => SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    32,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _ShimmerGrid(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: childAspectRatio,
                    ),
                  ),
                ),
                error: (error, stack) => SliverToBoxAdapter(
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 16,
                    ),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Remix.error_warning_line,
                          size: 40,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Unable to load trending campaigns',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          error.toString().replaceFirst('Exception: ', ''),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => ref
                              .read(customerTrendingListProvider.notifier)
                              .refresh(),
                          icon: const Icon(Remix.refresh_line, size: 16),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 16,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 48,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: AppColors.scaffoldBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Remix.fire_line,
                                size: 36,
                                color: AppColors.textPlaceholder,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No trending campaigns available',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              activeFilter != TrendingPlatformFilter.allTrending
                                  ? 'No active campaigns found for "${activeFilter.label}". Try a different filter!'
                                  : 'New high-converting campaigns and reel ideas will appear here once published.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () {
                                ref
                                    .read(
                                      selectedTrendingFilterProvider.notifier,
                                    )
                                    .selectFilter(
                                      TrendingPlatformFilter.allTrending,
                                    );
                                _searchController.clear();
                                ref
                                    .read(trendingSearchQueryProvider.notifier)
                                    .setSearchQuery('');
                              },
                              icon: const Icon(
                                Remix.refresh_line,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              label: Text(
                                'Reset Filters',
                                style: GoogleFonts.outfit(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Responsive Campaign Grid matching approved UI
                  return SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      80,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: childAspectRatio,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return _buildCampaignGridCard(
                          context,
                          items[index],
                          isNarrow,
                        );
                      }, childCount: items.length),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 4. Featured Hero Banner ("Get Inspired. Create. Grow.")
  Widget _buildFeaturedHeroBanner(
    BuildContext context,
    TrendingContent featuredItem,
    double screenWidth,
  ) {
    final thumbWidth = screenWidth >= 600
        ? (screenWidth * 0.18).clamp(110.0, 160.0)
        : (screenWidth < 360 ? (screenWidth * 0.22).clamp(72.0, 84.0) : 92.0);
    final thumbHeight = thumbWidth * 1.24;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFE8F9EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Badge: 🔥 TRENDING SHORTS & REELS
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 3),
                          Text(
                            'TRENDING SHORTS & REELS',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF15803D),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Main Title: "Get Inspired.\nCreate. Grow."
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.outfit(
                        fontSize: screenWidth < 360
                            ? 15
                            : (screenWidth >= 600 ? 19 : 16.5),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        height: 1.15,
                        letterSpacing: -0.2,
                      ),
                      children: const [
                        TextSpan(text: 'Get Inspired.\n'),
                        TextSpan(
                          text: 'Create. Grow.',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle / Description
                  Text(
                    'Explore viral Shorts & Reels hooks and ideas from top creators.',
                    style: GoogleFonts.outfit(
                      fontSize: screenWidth < 360
                          ? 9.5
                          : (screenWidth >= 600 ? 12 : 10.5),
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF475569),
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Green Button: [ Browse Ideas → ]
                  ElevatedButton(
                    onPressed: () =>
                        _showCampaignIdeaSheet(context, featuredItem),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Browse Ideas',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Remix.arrow_right_s_line, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Right Real Campaign / Video Thumbnail
            GestureDetector(
              onTap: () => _showCampaignIdeaSheet(context, featuredItem),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: thumbWidth,
                      height: thumbHeight,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: featuredItem.effectiveThumbnailUrl.isNotEmpty
                          ? Image.network(
                              featuredItem.effectiveThumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: const Color(0xFFDCFCE7),
                                    child: const Icon(
                                      Remix.fire_fill,
                                      color: AppColors.primary,
                                      size: 28,
                                    ),
                                  ),
                            )
                          : Container(
                              color: const Color(0xFFDCFCE7),
                              child: const Icon(
                                Remix.fire_fill,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                    ),
                  ),
                  // Platform badge on hero thumbnail
                  Positioned(
                    top: 5,
                    left: 5,
                    child: _buildGridPlatformBadge(featuredItem),
                  ),
                  // Light circular play button overlay
                  if (featuredItem.isVideo)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Remix.play_fill,
                        color: AppColors.primaryDark,
                        size: 17,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 7. Responsive Campaign Card Matching Approved Mobile Screenshot
  Widget _buildCampaignGridCard(
    BuildContext context,
    TrendingContent item,
    bool isNarrow,
  ) {
    final isBookmarked = _bookmarkedIds.contains(item.id);

    return GestureDetector(
      onTap: () => _showCampaignIdeaSheet(context, item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vertical Video / Image Thumbnail with consistent responsive aspect ratio
            AspectRatio(
              aspectRatio: 1.02,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                    child: Container(
                      color: Colors.black12,
                      child: item.effectiveThumbnailUrl.isNotEmpty
                          ? Image.network(
                              item.effectiveThumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: item.isYouTube
                                        ? const Color(0xFFFEE2E2)
                                        : const Color(0xFFF3E8FF),
                                    child: Center(
                                      child: Icon(
                                        item.isYouTube
                                            ? Remix.youtube_line
                                            : Remix.instagram_line,
                                        size: 32,
                                        color: item.isYouTube
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF9333EA),
                                      ),
                                    ),
                                  ),
                            )
                          : Container(
                              color: item.isYouTube
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFF3E8FF),
                              child: Center(
                                child: Icon(
                                  item.isYouTube
                                      ? Remix.youtube_line
                                      : Remix.instagram_line,
                                  size: 32,
                                  color: item.isYouTube
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF9333EA),
                                ),
                              ),
                            ),
                    ),
                  ),

                  // Top Dark Gradient Vignette for Badges
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 42,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top Left: Platform Badge (Instagram / YouTube)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _buildGridPlatformBadge(item),
                  ),

                  // Top Right: Bookmark Button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isBookmarked) {
                            _bookmarkedIds.remove(item.id);
                          } else {
                            _bookmarkedIds.add(item.id);
                          }
                        });
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              !isBookmarked
                                  ? 'Saved to bookmarked campaigns'
                                  : 'Removed from bookmarks',
                            ),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isBookmarked
                              ? Remix.bookmark_fill
                              : Remix.bookmark_line,
                          color: isBookmarked
                              ? Colors.amber.shade400
                              : Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ),

                  // Center Light Play Icon Button
                  if (item.isVideo)
                    Center(
                      child: GestureDetector(
                        onTap: () => _handlePlayMedia(context, item),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Remix.play_fill,
                            color: AppColors.primaryDark,
                            size: 18,
                          ),
                        ),
                      ),
                    ),

                  // Bottom Left: Duration Badge (e.g. 0:28, 0:30, 0:45)
                  if (item.formattedDuration != null)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          item.formattedDuration!,
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Content Section: Category Chip + Date, Title, Real Metrics
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Row: Category Chip + Date
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              item.displayCategoryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: isNarrow ? 8.5 : 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.shortDate,
                          style: GoogleFonts.outfit(
                            fontSize: isNarrow ? 8.5 : 9.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPlaceholder,
                          ),
                        ),
                      ],
                    ),

                    // Campaign Title (2 lines max with ellipsis)
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: isNarrow ? 10.5 : 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        height: 1.2,
                      ),
                    ),

                    // Metrics Row (Views, Likes, Shares/Comments)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Views
                          if (item.formattedViews != null) ...[
                            const Icon(
                              Remix.eye_line,
                              size: 11,
                              color: AppColors.textPlaceholder,
                            ),
                            const SizedBox(width: 2.5),
                            Text(
                              item.formattedViews!,
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],

                          // Likes
                          if (item.formattedLikes != null) ...[
                            const Icon(
                              Remix.heart_line,
                              size: 11,
                              color: Color(0xFFE11D48),
                            ),
                            const SizedBox(width: 2.5),
                            Text(
                              item.formattedLikes!,
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],

                          // Shares for Instagram, Comments for YouTube
                          if (item.isYouTube) ...[
                            if (item.formattedComments != null) ...[
                              const Icon(
                                Remix.message_2_line,
                                size: 10.5,
                                color: AppColors.textPlaceholder,
                              ),
                              const SizedBox(width: 2.5),
                              Text(
                                item.formattedComments!,
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ] else ...[
                            if (item.formattedShares != null) ...[
                              const Icon(
                                Remix.share_forward_line,
                                size: 10.5,
                                color: AppColors.textPlaceholder,
                              ),
                              const SizedBox(width: 2.5),
                              Text(
                                item.formattedShares!,
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact Grid Card Platform Badge (Instagram / YouTube)
  Widget _buildGridPlatformBadge(TrendingContent item) {
    if (item.isYouTube) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFCC0000),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Remix.youtube_fill, size: 11, color: Colors.white),
            const SizedBox(width: 3),
            Text(
              'Shorts',
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }

    // Default Instagram Reel Badge
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Remix.instagram_line, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            'Reel',
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Platform pill badge (used in bottom sheet)
  Widget _buildPlatformBadge(TrendingContent item) {
    if (item.isInstagram) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF2F8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFF472B6).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Remix.instagram_line,
              size: 11,
              color: Color(0xFFDB2777),
            ),
            const SizedBox(width: 4),
            Text(
              'INSTAGRAM',
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFDB2777),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    } else if (item.isYouTube) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFF87171).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Remix.youtube_fill, size: 11, color: Color(0xFFDC2626)),
            const SizedBox(width: 4),
            Text(
              'YOUTUBE',
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFDC2626),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.scaffoldBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          item.displayPlatform.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      );
    }
  }

  /// Category pill badge (used in bottom sheet)
  Widget _buildCategoryPill(TrendingContent item) {
    Color bg;
    Color fg;

    switch (item.category) {
      case TrendingCategory.reel:
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        break;
      case TrendingCategory.story:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        break;
      case TrendingCategory.offer:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case TrendingCategory.highRoiAd:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${item.category.emoji} ${item.displayCategoryTag}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}

/// Loading Responsive Shimmer Grid
class _ShimmerGrid extends StatelessWidget {
  final int crossAxisCount;
  final double childAspectRatio;

  const _ShimmerGrid({this.crossAxisCount = 2, this.childAspectRatio = 0.61});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemCount: crossAxisCount * 2,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.02,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 30,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: double.infinity,
                        height: 11,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: 75,
                        height: 11,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: 85,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
