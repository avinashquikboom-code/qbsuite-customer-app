import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import '../models/influencer_model.dart';

final customerInfluencerServiceProvider = Provider<CustomerInfluencerService>((
  ref,
) {
  final apiClient = ref.watch(apiClientProvider);
  return CustomerInfluencerService(apiClient);
});

class CustomerInfluencerService {
  final ApiClient _apiClient;

  CustomerInfluencerService(this._apiClient);

  /// Fetch influencer categories from backend API.
  Future<List<InfluencerCategoryModel>> fetchCategories() async {
    await _apiClient.ensureAuthLoaded();

    debugPrint(
      '[INFLUENCER] Requesting categories: ${AppUrl.influencerCategories}',
    );

    try {
      final response = await _apiClient.get(AppUrl.influencerCategories);

      debugPrint(
        '[INFLUENCER] Categories response status: ${response.statusCode}',
      );

      if (response.statusCode == 200 && response.data != null) {
        dynamic rawList;
        dynamic payload = response.data;
        if (payload is String) {
          try {
            payload = jsonDecode(payload);
          } catch (_) {}
        }
        if (payload is List) {
          rawList = payload;
        } else if (payload is Map) {
          if (payload['data'] is List) {
            rawList = payload['data'];
          } else if (payload['items'] is List) {
            rawList = payload['items'];
          } else if (payload['data'] is Map) {
            final inner = payload['data'] as Map;
            if (inner['items'] is List) {
              rawList = inner['items'];
            } else if (inner['data'] is List) {
              rawList = inner['data'];
            }
          }
        }

        if (rawList is List) {
          final categories = <InfluencerCategoryModel>[];
          for (final item in rawList) {
            if (item is Map) {
              try {
                final model = InfluencerCategoryModel.fromJson(
                  Map<String, dynamic>.from(item),
                );
                categories.add(model);
              } catch (parseErr) {
                debugPrint(
                  '[INFLUENCER] Parse error for category item: $parseErr',
                );
              }
            }
          }

          debugPrint(
            '[INFLUENCER] Successfully parsed ${categories.length} categories from backend',
          );
          return categories;
        }
      }
      return const [];
    } on DioException catch (dioErr) {
      final status = dioErr.response?.statusCode;
      debugPrint(
        '[INFLUENCER_CATEGORY_ERROR] Dio error: HTTP $status - ${dioErr.message}',
      );
      debugPrint(
        '[INFLUENCER_CATEGORY_ERROR] Response: ${dioErr.response?.data}',
      );
      return const [];
    } catch (e) {
      debugPrint('[INFLUENCER_CATEGORY_ERROR] Unexpected: $e');
      return const [];
    }
  }

  /// Fetch active influencers from backend API with optional filters.
  Future<List<InfluencerModel>> fetchInfluencers({
    String? category,
    bool? featured,
    String? platform,
    String? search,
  }) async {
    await _apiClient.ensureAuthLoaded();

    final Map<String, dynamic> queryParams = {};
    if (category != null &&
        category.isNotEmpty &&
        category.toLowerCase() != 'all') {
      queryParams['category'] = category;
    }
    if (featured != null) {
      queryParams['featured'] = featured;
    }
    if (platform != null &&
        platform.isNotEmpty &&
        platform.toLowerCase() != 'all') {
      queryParams['platform'] = platform;
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    debugPrint(
      '[INFLUENCER] Requesting influencers: ${AppUrl.influencers} with query: $queryParams',
    );

    try {
      final response = await _apiClient.get(
        AppUrl.influencers,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      debugPrint(
        '[INFLUENCER] Influencers response status: ${response.statusCode}',
      );

      if (response.statusCode == 200 && response.data != null) {
        dynamic rawList;
        dynamic payload = response.data;
        if (payload is String) {
          try {
            payload = jsonDecode(payload);
          } catch (_) {}
        }
        if (payload is List) {
          rawList = payload;
        } else if (payload is Map) {
          if (payload['data'] is List) {
            rawList = payload['data'];
          } else if (payload['items'] is List) {
            rawList = payload['items'];
          } else if (payload['data'] is Map) {
            final inner = payload['data'] as Map;
            if (inner['items'] is List) {
              rawList = inner['items'];
            } else if (inner['data'] is List) {
              rawList = inner['data'];
            }
          }
        }

        if (rawList is List) {
          final influencers = <InfluencerModel>[];
          for (final item in rawList) {
            if (item is Map) {
              try {
                final model = InfluencerModel.fromJson(
                  Map<String, dynamic>.from(item),
                );
                if (model.isActive) {
                  influencers.add(model);
                }
              } catch (parseErr) {
                debugPrint(
                  '[INFLUENCER] Parse error for influencer item: $parseErr',
                );
              }
            }
          }

          debugPrint(
            '[INFLUENCER] Successfully parsed ${influencers.length} active influencers from backend',
          );
          return influencers;
        }
      }
      return const [];
    } on DioException catch (dioErr) {
      final status = dioErr.response?.statusCode;
      debugPrint(
        '[INFLUENCER_FETCH_ERROR] Dio error: HTTP $status - ${dioErr.message}',
      );
      debugPrint('[INFLUENCER_FETCH_ERROR] Response: ${dioErr.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[INFLUENCER_FETCH_ERROR] Unexpected: $e');
      rethrow;
    }
  }

  /// Fetch single influencer details.
  Future<InfluencerModel?> fetchInfluencerById(int id) async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.get(AppUrl.influencerDetails(id));
      if (response.statusCode == 200 && response.data != null) {
        dynamic payload = response.data;
        if (payload is Map && payload.containsKey('data')) {
          payload = payload['data'];
        }
        if (payload is Map) {
          return InfluencerModel.fromJson(Map<String, dynamic>.from(payload));
        }
      }
    } catch (e) {
      debugPrint('[INFLUENCER_DETAILS_ERROR] id: $id, error: $e');
    }
    return null;
  }

  /// Toggle favorite on backend.
  Future<bool> toggleFavorite(int id) async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.post(AppUrl.influencerFavorite(id));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[INFLUENCER_FAVORITE_ERROR] id: $id, error: $e');
      return false;
    }
  }

  /// Fetch real packages for an influencer from backend.
  Future<List<InfluencerPackageModel>> fetchPackages(int influencerId) async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.get(
        AppUrl.influencerPackages(influencerId),
      );
      if (response.statusCode == 200 && response.data != null) {
        dynamic list = response.data;
        if (list is Map && list.containsKey('data')) {
          list = list['data'];
        }
        if (list is List) {
          final packages = <InfluencerPackageModel>[];
          for (final item in list) {
            if (item is Map) {
              final raw = Map<String, dynamic>.from(item);
              final typeStr = (raw['type'] ?? 'REEL').toString().toUpperCase();
              String iconType = 'reel';
              if (typeStr.contains('STORY')) iconType = 'story';
              if (typeStr.contains('POST')) iconType = 'post';
              if (typeStr.contains('CUSTOM')) iconType = 'custom';

              packages.add(
                InfluencerPackageModel(
                  id: raw['id']?.toString() ?? 'pkg_${packages.length}',
                  name: raw['name']?.toString() ?? 'Package',
                  badgeText: raw['duration']?.toString() ?? '3-5 days',
                  subtitle:
                      raw['description']?.toString() ??
                      raw['name']?.toString() ??
                      '',
                  price:
                      double.tryParse(raw['price']?.toString() ?? '0') ?? 0.0,
                  iconType: iconType,
                  isCustom: typeStr.contains('CUSTOM'),
                ),
              );
            }
          }
          return packages;
        }
      }
    } catch (e) {
      debugPrint('[INFLUENCER_PACKAGES_ERROR] $e');
    }
    return const [];
  }

  /// Fetch availability rules & booked dates for an influencer.
  Future<List<InfluencerAvailabilityModel>> fetchAvailability(
    int influencerId, {
    String? startDate,
    String? endDate,
  }) async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.get(
        AppUrl.influencerAvailability(influencerId),
        queryParameters: {'startDate': ?startDate, 'endDate': ?endDate},
      );
      if (response.statusCode == 200 && response.data != null) {
        dynamic list = response.data;
        if (list is Map && list.containsKey('data')) {
          list = list['data'];
        }
        if (list is List) {
          return list
              .whereType<Map>()
              .map(
                (m) => InfluencerAvailabilityModel.fromJson(
                  Map<String, dynamic>.from(m),
                ),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[INFLUENCER_AVAILABILITY_ERROR] $e');
    }
    return const [];
  }

  /// Create authoritative booking in backend DB and initiate Razorpay order.
  Future<InfluencerBookingModel?> createBooking({
    required int influencerId,
    int? packageId,
    required String campaignDate,
    required String brandName,
    required String contactPerson,
    required String mobileNumber,
    required String email,
    required String businessName,
    String? instagramId,
    String? campaignObjective,
    String? notes,
  }) async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.post(
        AppUrl.influencerBookings,
        data: {
          'influencerId': influencerId,
          if (packageId != null && packageId > 0) 'packageId': packageId,
          'campaignDate': campaignDate,
          'brandName': brandName,
          'contactPerson': contactPerson,
          'mobileNumber': mobileNumber,
          'email': email,
          'businessName': businessName,
          if (instagramId != null && instagramId.isNotEmpty)
            'instagramId': instagramId,
          if (campaignObjective != null && campaignObjective.isNotEmpty)
            'campaignObjective': campaignObjective,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        dynamic payload = response.data;
        Map<String, dynamic>? paymentGatewayConfig;
        if (payload is Map &&
            payload.containsKey('paymentGatewayConfig') &&
            payload['paymentGatewayConfig'] is Map) {
          paymentGatewayConfig = Map<String, dynamic>.from(
            payload['paymentGatewayConfig'],
          );
        }
        if (payload is Map &&
            payload.containsKey('booking') &&
            payload['booking'] is Map) {
          payload = payload['booking'];
        } else if (payload is Map &&
            payload.containsKey('data') &&
            payload['data'] is Map) {
          payload = payload['data'];
        }
        if (payload is Map) {
          final map = Map<String, dynamic>.from(payload);
          if (paymentGatewayConfig != null &&
              !map.containsKey('paymentGatewayConfig')) {
            map['paymentGatewayConfig'] = paymentGatewayConfig;
          }
          return InfluencerBookingModel.fromJson(map);
        }
      }
    } on DioException catch (dioErr) {
      debugPrint(
        '[INFLUENCER_CREATE_BOOKING_ERROR] ${dioErr.response?.data ?? dioErr.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint('[INFLUENCER_CREATE_BOOKING_ERROR] $e');
      rethrow;
    }
    return null;
  }

  /// Verify Razorpay payment signature or submit offline payment on backend.
  Future<bool> verifyPayment({
    required dynamic bookingId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
    String? paymentMethod,
    String? referenceNumber,
    String? notes,
  }) async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.post(
        AppUrl.influencerVerifyPayment,
        data: {
          'bookingId': bookingId,
          'razorpayPaymentId': razorpayPaymentId,
          'razorpayOrderId': razorpayOrderId,
          'razorpaySignature': razorpaySignature,
          'paymentMethod': ?paymentMethod,
          'referenceNumber': ?referenceNumber,
          'notes': ?notes,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[INFLUENCER_VERIFY_PAYMENT_ERROR] $e');
      return false;
    }
  }

  /// Fetch all bookings for the authenticated customer from backend.
  Future<List<InfluencerBookingModel>> fetchMyBookings() async {
    await _apiClient.ensureAuthLoaded();
    try {
      final response = await _apiClient.get(AppUrl.influencerMyBookings);
      if (response.statusCode == 200 && response.data != null) {
        dynamic list = response.data;
        if (list is Map && list.containsKey('data')) {
          list = list['data'];
        }
        if (list is Map && list.containsKey('items')) {
          list = list['items'];
        }
        if (list is List) {
          return list
              .whereType<Map>()
              .map(
                (m) => InfluencerBookingModel.fromJson(
                  Map<String, dynamic>.from(m),
                ),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[INFLUENCER_MY_BOOKINGS_ERROR] $e');
    }
    return const [];
  }

  /// Self-register as an influencer (starts as PENDING, awaiting Admin approval).
  Future<InfluencerModel?> registerInfluencer(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(
        AppUrl.influencerRegister,
        data: data,
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        dynamic item = response.data;
        if (item is Map && item.containsKey('data')) {
          item = item['data'];
        }
        if (item is Map) {
          return InfluencerModel.fromJson(Map<String, dynamic>.from(item));
        }
      }
    } catch (e) {
      debugPrint('[INFLUENCER_REGISTER_ERROR] $e');
      rethrow;
    }
    return null;
  }

  /// Check influencer application status by email or ID.
  Future<InfluencerModel?> checkApplicationStatus({
    String? email,
    String? id,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (email != null && email.isNotEmpty) queryParams['email'] = email;
      if (id != null && id.isNotEmpty) queryParams['id'] = id;

      final response = await _apiClient.get(
        AppUrl.influencerApplicationStatus,
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data != null) {
        dynamic item = response.data;
        if (item is Map && item.containsKey('data')) {
          item = item['data'];
        }
        if (item is Map) {
          return InfluencerModel.fromJson(Map<String, dynamic>.from(item));
        }
      }
    } catch (e) {
      debugPrint('[INFLUENCER_CHECK_STATUS_ERROR] $e');
      rethrow;
    }
    return null;
  }

  /// Resubmit a rejected application with updated profile details.
  Future<InfluencerModel?> resubmitApplication(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiClient.patch(
        AppUrl.influencerResubmit(id),
        data: data,
      );
      if (response.statusCode == 200 && response.data != null) {
        dynamic item = response.data;
        if (item is Map && item.containsKey('data')) {
          item = item['data'];
        }
        if (item is Map) {
          return InfluencerModel.fromJson(Map<String, dynamic>.from(item));
        }
      }
    } catch (e) {
      debugPrint('[INFLUENCER_RESUBMIT_ERROR] $e');
      rethrow;
    }
    return null;
  }
}
