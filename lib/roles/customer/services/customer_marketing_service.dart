import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import '../models/marketing_banner_model.dart';

final customerMarketingServiceProvider = Provider<CustomerMarketingService>((
  ref,
) {
  final apiClient = ref.watch(apiClientProvider);
  return CustomerMarketingService(apiClient);
});

class CustomerMarketingService {
  final ApiClient _apiClient;

  CustomerMarketingService(this._apiClient);

  /// Fetch active, published promotional banners for Customer Home
  Future<List<MarketingBannerModel>> getHomeBanners() async {
    await _apiClient.ensureAuthLoaded();

    debugPrint('[BANNER_DEBUG]');
    debugPrint('requestStarted: true');
    debugPrint('[BANNER] API request started');
    debugPrint('[BANNER] endpoint: ${AppUrl.marketingBannersCustomer}');
    debugPrint('[CUSTOMER_BANNERS_REQUEST]');
    debugPrint('endpoint: ${AppUrl.marketingBannersCustomer}');

    try {
      final response = await _apiClient.get(
        AppUrl.marketingBannersCustomer,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint('[BANNER_DEBUG]');
      debugPrint('status: ${response.statusCode}');
      debugPrint('[BANNER] API status code: ${response.statusCode}');
      debugPrint(
        '[BANNER] API response received: ${response.data != null ? "valid_data" : "null"}',
      );

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
          } else if (map['banners'] is List) {
            rawList = map['banners'];
          } else if (map['data'] is Map) {
            final inner = map['data'] as Map;
            if (inner['items'] is List) {
              rawList = inner['items'];
            } else if (inner['banners'] is List) {
              rawList = inner['banners'];
            }
          }
        }

        if (rawList is List) {
          final items = <MarketingBannerModel>[];
          for (final rawItem in rawList) {
            if (rawItem is Map) {
              try {
                final model = MarketingBannerModel.fromJson(
                  Map<String, dynamic>.from(rawItem),
                );
                items.add(model);
                debugPrint('[BANNER_API_DEBUG]');
                debugPrint('id: ${model.id}');
                debugPrint('title: ${model.title}');
                debugPrint('image: ${rawItem['image']}');
                debugPrint('imageUrl: ${model.imageUrl}');
                debugPrint('bannerUrl: ${rawItem['bannerUrl']}');
                debugPrint('mediaUrl: ${rawItem['mediaUrl']}');

                final effectiveUrl = model.effectiveImageUrl;
                final isValid =
                    (effectiveUrl.startsWith('http://') ||
                        effectiveUrl.startsWith('https://')) &&
                    !effectiveUrl.startsWith('data:');

                debugPrint('[BANNER_DEBUG]');
                debugPrint('count: ${rawList.length}');
                debugPrint('imageUrl: $effectiveUrl');
                debugPrint('isActive: ${model.isActive}');
                debugPrint(
                  'rendering: ${model.isActive && effectiveUrl.isNotEmpty}',
                );

                debugPrint('[BANNER_IMAGE_URL]');
                debugPrint('url: $effectiveUrl');

                debugPrint('[BANNER_IMAGE_DEBUG]');
                debugPrint('id: ${model.id}');
                debugPrint('title: ${model.title}');
                debugPrint('imageUrl: $effectiveUrl');
                debugPrint('imageUrlType: ${effectiveUrl.runtimeType}');
                debugPrint('isValidUrl: $isValid');

                debugPrint('[BANNER_FILTER_DEBUG]');
                debugPrint('id: ${model.id}');
                debugPrint('isActive: ${model.isActive}');
                debugPrint('status: ${model.isActive ? "ACTIVE" : "INACTIVE"}');
                debugPrint('startDate: ${model.startAt}');
                debugPrint('endDate: ${model.endAt}');
                debugPrint('currentDate: ${DateTime.now().toIso8601String()}');
                debugPrint('included: true');
                debugPrint('reason: active_and_valid_schedule');
              } catch (parseErr) {
                debugPrint('[BANNER] Parsing error if any: $parseErr');
              }
            }
          }

          debugPrint('[BANNER_API_DEBUG]');
          debugPrint('status: ${response.statusCode}');
          debugPrint('success: ${response.statusCode == 200}');
          debugPrint('count: ${items.length}');
          debugPrint('data: ${response.data}');

          debugPrint('[BANNER] Number of banners: ${items.length}');
          debugPrint('[CUSTOMER_BANNERS_RESPONSE]');
          debugPrint('count: ${items.length}');
          return items;
        }
      }

      debugPrint('[BANNER_DEBUG]');
      debugPrint('count: 0');
      debugPrint('rendering: false');
      debugPrint('[BANNER] Number of banners: 0');
      debugPrint('[CUSTOMER_BANNERS_RESPONSE] count: 0');
      return const [];
    } on DioException catch (dioErr) {
      final status = dioErr.response?.statusCode;
      final errorData = dioErr.response?.data;
      debugPrint('[BANNER_DEBUG]');
      debugPrint('status: $status');
      debugPrint('count: 0');
      debugPrint('rendering: false');
      debugPrint('[BANNER] API status code: $status');
      debugPrint(
        '[BANNER] API error: ${dioErr.message} | Response: $errorData',
      );
      debugPrint(
        '[CustomerMarketingService] API Error: HTTP $status - ${dioErr.message}',
      );
      return const [];
    } catch (e) {
      debugPrint('[BANNER_DEBUG]');
      debugPrint('status: error');
      debugPrint('rendering: false');
      debugPrint('[BANNER] Parsing error if any: $e');
      debugPrint('[CustomerMarketingService] Unexpected error: $e');
      return const [];
    }
  }
}
