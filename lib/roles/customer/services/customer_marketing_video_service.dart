import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import '../models/marketing_video_model.dart';

final customerMarketingVideoServiceProvider =
    Provider<CustomerMarketingVideoService>((ref) {
      final apiClient = ref.watch(apiClientProvider);
      return CustomerMarketingVideoService(apiClient);
    });

class CustomerMarketingVideoService {
  final ApiClient _apiClient;

  CustomerMarketingVideoService(this._apiClient);

  /// Fetch active, published marketing videos for Customer Home Screen
  Future<List<MarketingVideoModel>> getHomeVideos() async {
    await _apiClient.ensureAuthLoaded();

    debugPrint(
      '[MARKETING_VIDEOS_REQUEST] endpoint: ${AppUrl.marketingVideosCustomer}',
    );

    try {
      final response = await _apiClient.get(
        AppUrl.marketingVideosCustomer,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint('[MARKETING_VIDEOS_RESPONSE] status: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        dynamic rawList;
        if (response.data is List) {
          rawList = response.data;
        } else if (response.data is Map) {
          final map = response.data as Map;
          if (map['data'] is List) {
            rawList = map['data'];
          } else if (map['data'] is Map) {
            final inner = map['data'] as Map;
            if (inner['videos'] is List) {
              rawList = inner['videos'];
            } else if (inner['items'] is List) {
              rawList = inner['items'];
            } else if (inner['data'] is List) {
              rawList = inner['data'];
            }
          } else if (map['videos'] is List) {
            rawList = map['videos'];
          } else if (map['items'] is List) {
            rawList = map['items'];
          }
        }

        if (rawList is List) {
          final videos = rawList
              .map((item) {
                try {
                  if (item is Map<String, dynamic>) {
                    return MarketingVideoModel.fromJson(item);
                  } else if (item is Map) {
                    return MarketingVideoModel.fromJson(
                      Map<String, dynamic>.from(item),
                    );
                  }
                  return null;
                } catch (parseErr) {
                  debugPrint('[MARKETING_VIDEOS_PARSE_ERROR] $parseErr');
                  return null;
                }
              })
              .whereType<MarketingVideoModel>()
              .where((v) => v.isEligibleForHome)
              .toList();

          debugPrint('[MARKETING_VIDEO_HOME]');
          debugPrint('status: ${response.statusCode}');
          debugPrint('count: ${videos.length}');
          debugPrint(
            'data: ${rawList.length} received, ${videos.length} eligible',
          );
          for (final v in videos) {
            debugPrint('videoId: ${v.id}');
            debugPrint('videoUrl: ${v.videoUrl}');
            debugPrint('showOnHome: ${v.showOnHome}');
            debugPrint('status: ${v.status}');
          }

          return videos;
        }
      }
      debugPrint('[MARKETING_VIDEO_HOME]');
      debugPrint('status: ${response.statusCode}');
      debugPrint('count: 0');
      debugPrint('data: empty');
      return const [];
    } catch (e) {
      debugPrint('[MARKETING_VIDEO_HOME]');
      debugPrint('status: error ($e)');
      debugPrint('count: 0');
      debugPrint('data: error');
      return const [];
    }
  }

  /// Fetch next eligible unseen introduction marketing video for authenticated customer
  Future<MarketingVideoModel?> getIntroductionVideo() async {
    await _apiClient.ensureAuthLoaded();

    debugPrint(
      '[INTRO_VIDEO_REQUEST] endpoint: ${AppUrl.marketingIntroductionVideoCustomer}',
    );

    try {
      final response = await _apiClient.get(
        AppUrl.marketingIntroductionVideoCustomer,
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );

      debugPrint('[INTRO_VIDEO_RESPONSE] status: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        dynamic videoMap;
        if (response.data is Map) {
          final map = response.data as Map;
          if (map.containsKey('data') && map['data'] is Map) {
            videoMap = map['data'];
          } else if (map.containsKey('id') && map.containsKey('videoUrl')) {
            videoMap = map;
          }
        }

        if (videoMap is Map) {
          final video = MarketingVideoModel.fromJson(
            Map<String, dynamic>.from(videoMap),
          );
          if (video.videoUrl.isNotEmpty) {
            debugPrint(
              '[INTRO_VIDEO_FOUND] id: ${video.id} title: "${video.title}"',
            );
            return video;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('[INTRO_VIDEO_ERROR] $e');
      return null;
    }
  }

  /// Mark introduction marketing video as seen/skipped for authenticated customer
  Future<bool> markIntroductionVideoSeen(int videoId) async {
    await _apiClient.ensureAuthLoaded();

    final endpoint = AppUrl.marketingIntroductionVideoSeen(videoId);
    debugPrint('[INTRO_VIDEO_SEEN_REQUEST] endpoint: $endpoint');

    try {
      final response = await _apiClient.post(
        endpoint,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint('[INTRO_VIDEO_SEEN_RESPONSE] status: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[INTRO_VIDEO_SEEN_ERROR] $e');
      return false;
    }
  }
}
