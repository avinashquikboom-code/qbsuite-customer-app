import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import '../models/trending_content.dart';
import '../services/customer_trending_service.dart';

/// Horizontally scrollable platform & content filter chips
enum TrendingPlatformFilter {
  allTrending('All Trending', '★'),
  instagramReels('Instagram Reels', '📸'),
  youtubeShorts('YouTube Shorts', '▶'),
  viralReels('Viral Reels', '🔥'),
  storyAds('Story Ads', '⚡'),
  offers('Offers', '📣');

  final String label;
  final String emoji;
  const TrendingPlatformFilter(this.label, this.emoji);
}

/// Content type sorting tabs (Latest, Most Popular, Top Performing)
enum TrendingSortOption {
  latest('Latest'),
  mostPopular('Most Popular'),
  highestEngagement('Top Performing');

  final String label;
  const TrendingSortOption(this.label);
}

/// Notifier for selected platform/category filter chip
class SelectedTrendingFilterNotifier extends Notifier<TrendingPlatformFilter> {
  @override
  TrendingPlatformFilter build() => TrendingPlatformFilter.allTrending;

  void selectFilter(TrendingPlatformFilter filter) {
    state = filter;
  }
}

final selectedTrendingFilterProvider =
    NotifierProvider<SelectedTrendingFilterNotifier, TrendingPlatformFilter>(
      SelectedTrendingFilterNotifier.new,
    );

/// Backward-compatibility alias for legacy code
final selectedTrendingCategoryFilterProvider = selectedTrendingFilterProvider;

/// Notifier for content type sorting tabs (Latest, Most Popular, Top Performing)
class TrendingSortOptionNotifier extends Notifier<TrendingSortOption> {
  @override
  TrendingSortOption build() => TrendingSortOption.latest;

  void selectSort(TrendingSortOption sort) {
    state = sort;
  }
}

final trendingSortOptionProvider =
    NotifierProvider<TrendingSortOptionNotifier, TrendingSortOption>(
      TrendingSortOptionNotifier.new,
    );

/// Notifier for live search query
class TrendingSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setSearchQuery(String query) {
    state = query;
  }
}

final trendingSearchQueryProvider =
    NotifierProvider<TrendingSearchQueryNotifier, String>(
      TrendingSearchQueryNotifier.new,
    );

/// Dynamic trending content notifier providing `AsyncValue<List<TrendingContent>>` from real backend API
class CustomerTrendingListNotifier
    extends AsyncNotifier<List<TrendingContent>> {
  @override
  Future<List<TrendingContent>> build() async {
    // Re-fetch when user authentication state or active customer changes
    ref.watch(
      loginStateProvider.select((s) => '${s.isLoggedIn}_${s.customerId}'),
    );
    final service = ref.watch(customerTrendingServiceProvider);
    return service.fetchCustomerTrending();
  }

  /// Explicit refresh triggered by pull-to-refresh, refresh button, or retry
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(customerTrendingServiceProvider);
      return service.fetchCustomerTrending();
    });
  }
}

final customerTrendingListProvider =
    AsyncNotifierProvider<CustomerTrendingListNotifier, List<TrendingContent>>(
      CustomerTrendingListNotifier.new,
    );

/// Returns the primary featured trending item from the real API data for the Hero Banner
final featuredTrendingItemProvider = Provider<TrendingContent?>((ref) {
  final listAsync = ref.watch(customerTrendingListProvider);
  final items = listAsync.asData?.value;
  if (items == null || items.isEmpty) return null;
  // 1. Priority: admin marked isFeatured = true with real thumbnail
  try {
    return items.firstWhere(
      (item) => item.isFeatured && item.effectiveThumbnailUrl.isNotEmpty,
    );
  } catch (_) {}
  // 2. Admin marked isFeatured = true
  try {
    return items.firstWhere((item) => item.isFeatured);
  } catch (_) {}
  // 3. Any item with thumbnail
  try {
    return items.firstWhere((item) => item.effectiveThumbnailUrl.isNotEmpty);
  } catch (_) {}
  return items.first;
});

/// Filtered and sorted trending content selector combining platform chips, search, and sort tabs
final filteredTrendingContentProvider =
    Provider<AsyncValue<List<TrendingContent>>>((ref) {
      final listAsync = ref.watch(customerTrendingListProvider);
      final activeFilter = ref.watch(selectedTrendingFilterProvider);
      final activeSort = ref.watch(trendingSortOptionProvider);
      final searchQuery = ref
          .watch(trendingSearchQueryProvider)
          .trim()
          .toLowerCase();

      if (listAsync.hasError && !listAsync.hasValue) {
        return AsyncError(listAsync.error!, listAsync.stackTrace!);
      }

      return listAsync.whenData((items) {
        // 1. Filter by Search Query
        Iterable<TrendingContent> result = items;
        if (searchQuery.isNotEmpty) {
          result = result.where((item) {
            final titleMatch = item.title.toLowerCase().contains(searchQuery);
            final descMatch =
                item.description?.toLowerCase().contains(searchQuery) ?? false;
            final platformMatch = item.platform.toLowerCase().contains(
              searchQuery,
            );
            final objectiveMatch = item.objective.toLowerCase().contains(
              searchQuery,
            );
            final categoryMatch =
                item.displayCategoryTag.toLowerCase().contains(searchQuery) ||
                item.displayCategoryName.toLowerCase().contains(searchQuery);
            return titleMatch ||
                descMatch ||
                platformMatch ||
                objectiveMatch ||
                categoryMatch;
          });
        }

        // 2. Filter by Platform / Category Filter Chip
        switch (activeFilter) {
          case TrendingPlatformFilter.allTrending:
            break; // All content
          case TrendingPlatformFilter.instagramReels:
            result = result.where((item) => item.isInstagram);
            break;
          case TrendingPlatformFilter.youtubeShorts:
            result = result.where((item) => item.isYouTube);
            break;
          case TrendingPlatformFilter.viralReels:
            result = result.where(
              (item) => item.category == TrendingCategory.reel || item.isVideo,
            );
            break;
          case TrendingPlatformFilter.storyAds:
            result = result.where(
              (item) => item.category == TrendingCategory.story,
            );
            break;
          case TrendingPlatformFilter.offers:
            result = result.where(
              (item) => item.category == TrendingCategory.offer,
            );
            break;
        }

        final list = result.toList();

        // 3. Sort by Content Type Tab
        switch (activeSort) {
          case TrendingSortOption.latest:
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            break;
          case TrendingSortOption.mostPopular:
            list.sort((a, b) {
              final aViews = a.views ?? (a.priority * 10000);
              final bViews = b.views ?? (b.priority * 10000);
              if (bViews != aViews) return bViews.compareTo(aViews);
              return b.createdAt.compareTo(a.createdAt);
            });
            break;
          case TrendingSortOption.highestEngagement:
            list.sort((a, b) {
              final aEng =
                  (a.engagementRate ?? 0) * 10000 +
                  (a.likes ?? 0) +
                  (a.shares ?? 0);
              final bEng =
                  (b.engagementRate ?? 0) * 10000 +
                  (b.likes ?? 0) +
                  (b.shares ?? 0);
              if (bEng != aEng) return bEng.compareTo(aEng);
              return b.createdAt.compareTo(a.createdAt);
            });
            break;
        }

        return list;
      });
    });
