import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import '../models/trending_content.dart';

final customerTrendingServiceProvider = Provider<CustomerTrendingService>((
  ref,
) {
  final apiClient = ref.watch(apiClientProvider);
  return CustomerTrendingService(apiClient);
});

class CustomerTrendingService {
  final ApiClient _apiClient;

  CustomerTrendingService(this._apiClient);

  /// Fetch dynamic trending content from backend with optional category, platform, search, sort, and isFeatured filtering
  Future<List<TrendingContent>> fetchCustomerTrending({
    TrendingCategory? category,
    String? platform,
    String? sort,
    String? search,
    bool? isFeatured,
  }) async {
    await _apiClient.ensureAuthLoaded();

    final queryParams = <String, dynamic>{};
    if (category != null) {
      queryParams['category'] = category.apiValue;
    }
    if (platform != null &&
        platform.isNotEmpty &&
        platform.toUpperCase() != 'ALL') {
      queryParams['platform'] = platform;
    }
    if (sort != null && sort.isNotEmpty) {
      queryParams['sort'] = sort;
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (isFeatured != null) {
      queryParams['isFeatured'] = isFeatured;
    }

    debugPrint(
      '[TRENDING] API request: ${AppUrl.trendingCustomer} (category: ${category?.apiValue ?? "ALL"}, platform: $platform, sort: $sort, search: $search, isFeatured: $isFeatured)',
    );
    debugPrint('[TRENDING_REQUEST]');
    debugPrint('endpoint: ${AppUrl.trendingCustomer}');
    debugPrint('category: ${category?.apiValue ?? "ALL"}');

    try {
      final response = await _apiClient.get(
        AppUrl.trendingCustomer,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      debugPrint('[TRENDING] API response status: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        dynamic rawList;
        if (response.data is List) {
          rawList = response.data;
        } else if (response.data is Map) {
          final map = response.data as Map;
          if (map['data'] is List) {
            rawList = map['data'];
          } else if (map['items'] is List) {
            rawList = map['items'];
          } else if (map['data'] is Map) {
            final inner = map['data'] as Map;
            if (inner['items'] is List) {
              rawList = inner['items'];
            } else if (inner['data'] is List) {
              rawList = inner['data'];
            }
          }
        }

        if (rawList is List) {
          final items = <TrendingContent>[];
          for (final rawItem in rawList) {
            if (rawItem is Map) {
              try {
                final model = TrendingContent.fromJson(
                  Map<String, dynamic>.from(rawItem),
                );
                items.add(model);
              } catch (parseErr) {
                debugPrint('[TRENDING] Parsing error for item: $parseErr');
              }
            }
          }

          debugPrint('[TRENDING] Content count: ${items.length}');
          debugPrint('[TRENDING_RESPONSE] count: ${items.length}');
          for (final model in items) {
            debugPrint('[TRENDING_ITEM]');
            debugPrint('id: ${model.id}');
            debugPrint(
              'mediaType: ${model.mediaType ?? (model.isVideo ? "VIDEO" : "IMAGE")}',
            );
            debugPrint(
              'mediaSource: ${model.mediaSource ?? (model.mediaUrl?.startsWith("http") == true ? "URL" : "UPLOAD")}',
            );
            debugPrint('mediaUrl: ${model.mediaUrl}');
            debugPrint('title: ${model.title}');
            debugPrint('isYouTubeVideo: ${model.isYouTubeVideo}');
            debugPrint('youTubeVideoId: ${model.youTubeVideoId}');
          }
          return items;
        }
      }

      debugPrint('[TRENDING] Content count: 0');
      debugPrint('[TRENDING_RESPONSE] count: 0');
      return const [];
    } on DioException catch (dioErr) {
      final status = dioErr.response?.statusCode;
      debugPrint('[TRENDING] API response status: $status');
      debugPrint(
        '[CustomerTrendingService] API Error: HTTP $status - ${dioErr.message}',
      );
      if (status == 401 || status == 403) {
        rethrow;
      }
      return const [];
    } catch (e) {
      debugPrint('[CustomerTrendingService] Unexpected error: $e');
      return const [];
    }
  }
}
