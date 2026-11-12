import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import '../models/marketplace_tool_model.dart';

final customerMarketplaceServiceProvider = Provider<CustomerMarketplaceService>(
  (ref) {
    final apiClient = ref.watch(apiClientProvider);
    return CustomerMarketplaceService(apiClient);
  },
);

class CustomerMarketplaceService {
  final ApiClient _apiClient;

  CustomerMarketplaceService(this._apiClient);

  /// Fetch active marketplace tools from backend API.
  Future<List<MarketplaceToolModel>> fetchMarketplaceTools() async {
    await _apiClient.ensureAuthLoaded();

    debugPrint(
      '[MARKETPLACE] Requesting marketplace tools: ${AppUrl.marketplaceTools}',
    );

    try {
      final response = await _apiClient.get(AppUrl.marketplaceTools);

      debugPrint('[MARKETPLACE] Response status: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        dynamic payload = response.data;
        if (payload is Map && payload.containsKey('data')) {
          payload = payload['data'];
        }

        if (payload is List) {
          final tools = payload
              .map(
                (item) => MarketplaceToolModel.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .where((tool) => tool.isActive && tool.isPublished)
              .toList();

          // Sort by backend sortOrder
          tools.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

          debugPrint(
            '[MARKETPLACE] Successfully fetched and parsed ${tools.length} active tools from backend',
          );
          return tools;
        }
      }
      return [];
    } on DioException catch (dioErr) {
      final status = dioErr.response?.statusCode;
      debugPrint('[MARKETPLACE] API status: $status - ${dioErr.message}');
      rethrow;
    } catch (e) {
      debugPrint('[MARKETPLACE] Unexpected error fetching tools: $e');
      rethrow;
    }
  }
}
