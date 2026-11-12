import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import '../models/social_media_work_model.dart';

final socialMediaWorkServiceProvider = Provider<SocialMediaWorkService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SocialMediaWorkService(apiClient);
});

class SocialMediaWorkService {
  final ApiClient _apiClient;

  SocialMediaWorkService(this._apiClient);

  static const List<String> workTypes = [
    'Content Posting',
    'Reel Creation',
    'Ad Campaign',
    'Graphic Design',
    'Story Updates',
    'Full Social Media Handling',
  ];

  static const List<String> platforms = [
    'INSTAGRAM',
    'FACEBOOK',
    'YOUTUBE',
    'LINKEDIN',
    'TWITTER',
    'OTHER',
  ];

  /// Fetch real social media handlers for the authenticated customer
  Future<List<CustomerSocialMediaHandler>> getSocialMediaHandlers() async {
    await _apiClient.ensureAuthLoaded();

    debugPrint('[SOCIAL_MEDIA_HANDLER_REQUEST]');
    debugPrint('endpoint: ${AppUrl.socialMediaHandlersCustomer}');

    try {
      final response = await _apiClient.get(AppUrl.socialMediaHandlersCustomer);

      debugPrint(
        '[SOCIAL_MEDIA_HANDLER_RESPONSE] status: ${response.statusCode}',
      );

      if (response.statusCode == 200 && response.data != null) {
        dynamic rawList;
        if (response.data is List) {
          rawList = response.data;
        } else if (response.data is Map) {
          final map = response.data as Map;
          if (map['items'] is List) {
            rawList = map['items'];
          } else if (map['data'] is List) {
            rawList = map['data'];
          } else if (map['data'] is Map &&
              (map['data'] as Map)['items'] is List) {
            rawList = (map['data'] as Map)['items'];
          }
        }

        if (rawList is List) {
          final items = <CustomerSocialMediaHandler>[];
          for (final raw in rawList) {
            if (raw is Map) {
              try {
                items.add(
                  CustomerSocialMediaHandler.fromJson(
                    Map<String, dynamic>.from(raw),
                  ),
                );
              } catch (e) {
                debugPrint('[SOCIAL_MEDIA_PARSE_ERROR] $e');
              }
            }
          }
          debugPrint('[SOCIAL_MEDIA_HANDLER_RESPONSE] count: ${items.length}');
          return items;
        }
      }
      return [];
    } catch (e) {
      debugPrint('[SOCIAL_MEDIA_HANDLER_ERROR] $e');
      rethrow;
    }
  }

  /// Create a new handler / work schedule in the real database
  Future<CustomerSocialMediaHandler?> createHandler({
    required String platform,
    required String accountName,
    String? accountUrl,
    String? password,
    String? handlerName,
    String? handlerPhone,
    String? handlerEmail,
    String? workType,
    String? status,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    int? durationDays,
  }) async {
    await _apiClient.ensureAuthLoaded();

    final payload = {
      'platform': platform.trim().toUpperCase(),
      'accountName': accountName.trim(),
      if (accountUrl != null && accountUrl.isNotEmpty)
        'accountUrl': accountUrl.trim(),
      if (password != null && password.isNotEmpty) 'password': password,
      if (handlerName != null && handlerName.isNotEmpty)
        'handlerName': handlerName.trim(),
      if (handlerPhone != null && handlerPhone.isNotEmpty)
        'handlerPhone': handlerPhone.trim(),
      if (handlerEmail != null && handlerEmail.isNotEmpty)
        'handlerEmail': handlerEmail.trim(),
      'workType': workType ?? 'Content Posting',
      'status': status ?? 'ACTIVE',
      if (notes != null && notes.isNotEmpty) 'notes': notes.trim(),
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
      'durationDays': durationDays ?? 30,
    };

    try {
      final response = await _apiClient.post(
        AppUrl.socialMediaHandlersCustomer,
        data: payload,
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        final data =
            response.data is Map && (response.data as Map)['data'] is Map
            ? (response.data as Map)['data']
            : response.data;
        if (data is Map) {
          return CustomerSocialMediaHandler.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SOCIAL_MEDIA_CREATE_ERROR] $e');
      rethrow;
    }
  }

  /// Update an existing handler in the real database
  Future<CustomerSocialMediaHandler?> updateHandler({
    required int id,
    String? platform,
    String? accountName,
    String? accountUrl,
    String? password,
    String? handlerName,
    String? handlerPhone,
    String? handlerEmail,
    String? workType,
    String? status,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    int? durationDays,
  }) async {
    await _apiClient.ensureAuthLoaded();

    final payload = <String, dynamic>{
      if (platform != null) 'platform': platform.trim().toUpperCase(),
      if (accountName != null) 'accountName': accountName.trim(),
      if (accountUrl != null) 'accountUrl': accountUrl.trim(),
      if (password != null && password.trim().isNotEmpty)
        'password': password.trim(),
      if (handlerName != null) 'handlerName': handlerName.trim(),
      if (handlerPhone != null) 'handlerPhone': handlerPhone.trim(),
      if (handlerEmail != null) 'handlerEmail': handlerEmail.trim(),
      if (workType != null && workType.isNotEmpty) 'workType': workType,
      if (status != null && status.isNotEmpty) 'status': status,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
      'durationDays': ?durationDays,
    };

    try {
      final response = await _apiClient.patch(
        '${AppUrl.socialMediaHandlersCustomer}/$id',
        data: payload,
      );
      if ((response.statusCode == 200 || response.statusCode == 204) &&
          response.data != null) {
        final data =
            response.data is Map && (response.data as Map)['data'] is Map
            ? (response.data as Map)['data']
            : response.data;
        if (data is Map) {
          return CustomerSocialMediaHandler.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SOCIAL_MEDIA_UPDATE_ERROR] $e');
      rethrow;
    }
  }

  /// Delete a handler
  Future<bool> deleteHandler(int id) async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.delete(
        '${AppUrl.socialMediaHandlersCustomer}/$id',
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('[SOCIAL_MEDIA_DELETE_ERROR] $e');
      return false;
    }
  }
}
