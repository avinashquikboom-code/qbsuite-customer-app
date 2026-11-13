import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/api_exception.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import '../models/ai_studio_model.dart';

final customerAiStudioServiceProvider = Provider<CustomerAiStudioService>((
  ref,
) {
  final apiClient = ref.watch(apiClientProvider);
  return CustomerAiStudioService(apiClient);
});

class CustomerAiStudioService {
  final ApiClient _apiClient;

  CustomerAiStudioService(this._apiClient);

  /// Fetch available AI services and credit pricing.
  Future<List<AiServiceConfigModel>> fetchServices() async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.get(AppUrl.aiServices);
      if (response.statusCode == 200 && response.data != null) {
        dynamic list = response.data;
        if (list is Map && list.containsKey('data')) list = list['data'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map(
                (m) =>
                    AiServiceConfigModel.fromJson(Map<String, dynamic>.from(m)),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[AI_STUDIO_SERVICES_ERROR] $e');
    }
    return const [];
  }

  /// Fetch authenticated customer's AI wallet and credit ledger.
  Future<AiWalletModel?> fetchWallet() async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.get(AppUrl.aiWallet);
      if (response.statusCode == 200 && response.data != null) {
        dynamic payload = response.data;
        if (payload is Map && payload.containsKey('data')) {
          payload = payload['data'];
        }
        if (payload is Map) {
          return AiWalletModel.fromJson(Map<String, dynamic>.from(payload));
        }
      }
    } catch (e) {
      debugPrint('[AI_STUDIO_WALLET_ERROR] $e');
    }
    return null;
  }

  /// Create Razorpay order to purchase credits.
  Future<Map<String, dynamic>?> createCreditOrder({
    required int credits,
    required double amount,
  }) async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.post(
        AppUrl.aiCreditsOrder,
        data: {'credits': credits, 'amount': amount},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        dynamic payload = response.data;
        if (payload is Map && payload.containsKey('data')) {
          payload = payload['data'];
        }
        if (payload is Map) return Map<String, dynamic>.from(payload);
      }
    } catch (e) {
      debugPrint('[AI_STUDIO_CREDITS_ORDER_ERROR] $e');
    }
    return null;
  }

  /// Verify Razorpay payment and credit customer's wallet.
  Future<bool> verifyCreditPayment({
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
    required int credits,
  }) async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.post(
        AppUrl.aiCreditsVerify,
        data: {
          'razorpayPaymentId': razorpayPaymentId,
          'razorpayOrderId': razorpayOrderId,
          'razorpaySignature': razorpaySignature,
          'credits': credits,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[AI_STUDIO_CREDITS_VERIFY_ERROR] $e');
      return false;
    }
  }

  /// Generate AI content (Post, Poster, Video, Caption, Hashtags).
  Future<AiGenerationModel?> generateContent({
    required String type,
    required String product,
    String? objective,
    String? targetAudience,
    String? platform,
    String? language,
    String? tone,
    String? cta,
    String? instructions,
    String? referenceImageUrl,
  }) async {
    final trimmedProduct = product.trim();
    if (trimmedProduct.isEmpty) {
      throw ArgumentError('Product description cannot be empty');
    }

    await _apiClient.ensureAuthLoaded();
    try {
      final payload = <String, dynamic>{
        'type': type,
        'product': trimmedProduct,
      };

      if (objective != null && objective.trim().isNotEmpty) {
        payload['objective'] = objective.trim();
      }
      if (targetAudience != null && targetAudience.trim().isNotEmpty) {
        payload['targetAudience'] = targetAudience.trim();
      }
      if (platform != null && platform.trim().isNotEmpty) {
        payload['platform'] = platform.trim();
      }
      if (language != null && language.trim().isNotEmpty) {
        payload['language'] = language.trim();
      }
      if (tone != null && tone.trim().isNotEmpty) {
        payload['tone'] = tone.trim();
      }
      if (cta != null && cta.trim().isNotEmpty) {
        payload['cta'] = cta.trim();
      }
      if (instructions != null && instructions.trim().isNotEmpty) {
        payload['instructions'] = instructions.trim();
      }
      if (referenceImageUrl != null && referenceImageUrl.trim().isNotEmpty) {
        payload['referenceImageUrl'] = referenceImageUrl.trim();
      }

      debugPrint(
        '[AI_REQUEST] Submitting to ${AppUrl.aiGenerate}: type="${payload['type']}", product="${payload['product']}"',
      );

      final response = await _apiClient.post(AppUrl.aiGenerate, data: payload);

      debugPrint(
        '[AI_RESPONSE] Status: ${response.statusCode}, response data keys: ${(response.data is Map) ? (response.data as Map).keys : 'not-a-map'}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        dynamic payloadData = response.data;
        if (payloadData is Map && payloadData.containsKey('data')) {
          payloadData = payloadData['data'];
        }
        if (payloadData is Map && payloadData.containsKey('generation')) {
          payloadData = payloadData['generation'];
        }
        if (payloadData is Map) {
          final model = AiGenerationModel.fromJson(
            Map<String, dynamic>.from(payloadData),
          );
          debugPrint(
            '[AI_GENERATION_FLUTTER] Parsed AiGenerationModel: id=${model.id}, generationId=${model.generationId}, status=${model.status}, mediaUrl=${model.mediaUrl}, effectiveMediaUrl=${model.effectiveMediaUrl}',
          );
          return model;
        }
      }
    } on DioException catch (dioErr) {
      final apiErr = ApiException.fromDioException(dioErr);
      debugPrint(
        '[AI_GENERATE_ERROR]\nstatusCode: ${apiErr.statusCode}\nmessage: ${apiErr.message}\npath: ${apiErr.path}',
      );
      throw apiErr;
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint(
        '[AI_GENERATE_ERROR]\nstatusCode: null\nmessage: $e\npath: ${AppUrl.aiGenerate}',
      );
      throw ApiException(message: e.toString());
    }
    return null;
  }

  /// Fetch customer's past AI generations.
  Future<List<AiGenerationModel>> fetchGenerations({String? type}) async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.get(
        AppUrl.aiGenerations,
        queryParameters: {
          if (type != null && type.isNotEmpty && type != 'ALL') 'type': type,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        dynamic list = response.data;
        if (list is Map && list.containsKey('data')) list = list['data'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map(
                (m) => AiGenerationModel.fromJson(Map<String, dynamic>.from(m)),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[AI_STUDIO_GENERATIONS_ERROR] $e');
    }
    return const [];
  }

  /// Fetch a single generation's details or poll async render status.
  Future<AiGenerationModel?> fetchGenerationDetails(dynamic id) async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.get(AppUrl.aiGenerationDetails(id));
      if (response.statusCode == 200 && response.data != null) {
        dynamic payload = response.data;
        if (payload is Map && payload.containsKey('data')) {
          payload = payload['data'];
        }
        if (payload is Map) {
          return AiGenerationModel.fromJson(Map<String, dynamic>.from(payload));
        }
      }
    } catch (e) {
      debugPrint('[AI_STUDIO_GENERATION_DETAILS_ERROR] $e');
    }
    return null;
  }

  /// Fetch connected social accounts for the customer.
  Future<List<SocialAccountModel>> fetchConnectedSocialAccounts() async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.get(AppUrl.socialAccounts);
      if (response.statusCode == 200 && response.data != null) {
        dynamic list = response.data;
        if (list is Map && list.containsKey('data')) list = list['data'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map(
                (m) =>
                    SocialAccountModel.fromJson(Map<String, dynamic>.from(m)),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SOCIAL_ACCOUNTS_ERROR] $e');
    }
    return const [];
  }

  /// Get the OAuth authorization URL for a platform (Instagram, Facebook, etc.)
  /// Returns the URL string the user must open in a browser, or null on failure.
  Future<String?> fetchOAuthStartUrl(String platform) async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.get(AppUrl.socialOAuthStart(platform));
      if (response.statusCode == 200 && response.data != null) {
        dynamic payload = response.data;
        if (payload is Map && payload.containsKey('authUrl')) {
          return payload['authUrl']?.toString();
        }
      }
    } catch (e) {
      debugPrint('[SOCIAL_OAUTH_START_ERROR] platform=$platform error=$e');
    }
    return null;
  }

  /// Connect a social media account.
  Future<SocialAccountModel?> connectSocialAccount({
    required String platform,
    required String accountName,
    String? username,
    required String accessToken,
    required String externalAccountId,
  }) async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.post(
        AppUrl.socialConnect,
        data: {
          'platform': platform,
          'accountName': accountName,
          if (username != null && username.isNotEmpty) 'username': username,
          'accessToken': accessToken,
          'externalAccountId': externalAccountId,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        dynamic payload = response.data;
        if (payload is Map && payload.containsKey('data')) {
          payload = payload['data'];
        }
        if (payload is Map) {
          return SocialAccountModel.fromJson(
            Map<String, dynamic>.from(payload),
          );
        }
      }
    } catch (e) {
      debugPrint('[SOCIAL_CONNECT_ERROR] $e');
    }
    return null;
  }

  /// Disconnect a social account.
  Future<bool> disconnectSocialAccount(int id) async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.delete(AppUrl.socialDisconnect(id));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[SOCIAL_DISCONNECT_ERROR] $e');
      return false;
    }
  }

  /// Publish or schedule post to a connected social media account.
  ///
  /// The backend resolves the platform from the stored SocialAccount record —
  /// [socialAccountId] is sufficient; [platform] must NOT be sent.
  ///
  /// [generationId] links the publish record to the original AI generation.
  Future<SocialPublishModel?> publishContent({
    required int socialAccountId,
    int? generationId,
    String? content,
    List<String> mediaUrls = const [],
    DateTime? scheduledFor,
  }) async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.post(
        AppUrl.socialPublish,
        data: {
          'socialAccountId': socialAccountId,
          'accountIds': [socialAccountId],
          'content': content ?? '',
          'mediaUrls': mediaUrls,
          'generationId': ?generationId,
          // ignore: use_null_aware_elements — must omit key when null (backend IsString rejects null)
          if (scheduledFor != null)
            'scheduledFor': scheduledFor.toIso8601String(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        if (body is! Map) return null;

        // Backend returns: { records: [...], mode, count, ... }
        // Try records[0] first (correct shape), then fall back to body['data']
        dynamic record;
        final records = body['records'];
        if (records is List && records.isNotEmpty) {
          record = records.first;
        } else if (body.containsKey('data')) {
          record = body['data'];
        } else {
          record = body;
        }

        if (record is Map) {
          return SocialPublishModel.fromJson(Map<String, dynamic>.from(record));
        }
      }
    } catch (e) {
      debugPrint('[SOCIAL_PUBLISH_ERROR] $e');
      rethrow;
    }
    return null;
  }

  /// Fetch publication history for customer.
  Future<List<SocialPublishModel>> fetchPublishes() async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.get(AppUrl.socialPublishes);
      if (response.statusCode == 200 && response.data != null) {
        dynamic list = response.data;
        if (list is Map && list.containsKey('data')) list = list['data'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map(
                (m) =>
                    SocialPublishModel.fromJson(Map<String, dynamic>.from(m)),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SOCIAL_PUBLISHES_ERROR] $e');
    }
    return const [];
  }
}
