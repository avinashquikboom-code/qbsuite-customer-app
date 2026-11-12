import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import '../models/marketing_video_model.dart';
import '../services/customer_marketing_video_service.dart';

/// Dynamic home marketing videos notifier providing `AsyncValue<List<MarketingVideoModel>>`
class CustomerMarketingVideosNotifier
    extends AsyncNotifier<List<MarketingVideoModel>> {
  @override
  Future<List<MarketingVideoModel>> build() async {
    final loginState = ref.watch(loginStateProvider);

    if (loginState.isInitializing) {
      await ref.read(apiClientProvider).ensureAuthLoaded();
    }

    final service = ref.watch(customerMarketingVideoServiceProvider);
    try {
      final videos = await service.getHomeVideos();

      debugPrint('[MARKETING_VIDEOS_PROVIDER]');
      debugPrint('count: ${videos.length}');
      debugPrint('status: ${videos.isNotEmpty ? "ACTIVE" : "EMPTY"}');

      return videos;
    } catch (e) {
      debugPrint('[MARKETING_VIDEOS_PROVIDER_ERROR] $e');
      return const [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(customerMarketingVideoServiceProvider);
      return service.getHomeVideos();
    });
  }
}

final customerMarketingVideosProvider =
    AsyncNotifierProvider<
      CustomerMarketingVideosNotifier,
      List<MarketingVideoModel>
    >(CustomerMarketingVideosNotifier.new);

/// Provider for retrieving the next eligible unseen introduction video for the customer
final customerIntroductionVideoProvider = FutureProvider<MarketingVideoModel?>((
  ref,
) async {
  final loginState = ref.watch(loginStateProvider);
  if (!loginState.isLoggedIn) {
    return null;
  }
  final service = ref.watch(customerMarketingVideoServiceProvider);
  return service.getIntroductionVideo();
});
