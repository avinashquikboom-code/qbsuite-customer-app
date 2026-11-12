import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import 'package:quickboom_crm_customer/core/services/secure_storage_service.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_plan_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_invoice_model.dart';

final customerSubscriptionServiceProvider =
    Provider<CustomerSubscriptionService>((ref) {
      final apiClient = ref.watch(apiClientProvider);
      return CustomerSubscriptionService(apiClient: apiClient);
    });

class CustomerSubscriptionService {
  static const String _kCachedPlansKey = 'quikboom_customer_cached_plans';
  static const String _kCachedSubscriptionKey =
      'quikboom_customer_cached_subscription';
  static const String _kCachedOrdersKey = 'quikboom_customer_cached_orders';

  final ApiClient? _apiClient;

  CustomerSubscriptionService({ApiClient? apiClient}) : _apiClient = apiClient;

  /// Live API rejects unknown `activationDate` until that DTO is deployed.
  /// Retry the same call without the field so checkout can continue.
  Future<Response> _postDroppingUnknownActivationDate(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final client = _apiClient;
    if (client == null) {
      throw Exception('Authentication required.');
    }
    try {
      return await client.post(path, data: payload);
    } on DioException catch (e) {
      final message = _extractDioErrorMessage(e, defaultMessage: '');
      final rejectedActivation =
          message.contains('activationDate') &&
          message.contains('should not exist');
      if (!rejectedActivation || !payload.containsKey('activationDate')) {
        rethrow;
      }
      final retryPayload = Map<String, dynamic>.from(payload)
        ..remove('activationDate');
      debugPrint(
        '[PAYMENT] Server rejected activationDate; retrying $path without it.',
      );
      return client.post(path, data: retryPayload);
    }
  }

  String? get customerId => _apiClient?.customerId;

  String? get _scopedCustomerId {
    final cid = _apiClient?.customerId?.trim();
    if (cid == null || cid.isEmpty || cid == 'null' || cid == 'undefined') {
      return null;
    }
    return cid;
  }

  String get _customerScopedSubscriptionKey {
    final cid = _scopedCustomerId;
    if (cid != null) return '${_kCachedSubscriptionKey}_$cid';
    return _kCachedSubscriptionKey;
  }

  String get _customerScopedPlansKey {
    final cid = _scopedCustomerId;
    if (cid != null) return '${_kCachedPlansKey}_$cid';
    return _kCachedPlansKey;
  }

  String get _customerScopedOrdersKey {
    final cid = _scopedCustomerId;
    if (cid != null) return '${_kCachedOrdersKey}_$cid';
    return _kCachedOrdersKey;
  }

  /// Subscription start date is strictly 2 calendar days after purchase date (UTC calendar, matches backend).
  /// Example: Purchase 29 Sep -> Activation 1 Oct
  static DateTime calculateSubscriptionStartDate([DateTime? purchaseDate]) {
    final purchase = purchaseDate ?? DateTime.now();
    final u = purchase.toUtc();
    return DateTime(u.year, u.month, u.day + 2);
  }

  /// Parse API date as calendar day (UTC components) to avoid timezone shifting display by one day.
  static DateTime? parseOrderCalendarDate(dynamic raw) {
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return null;
    final u = parsed.toUtc();
    return DateTime(u.year, u.month, u.day);
  }

  /// Calendar-selected activation date for API (YYYY-MM-DD, local calendar day).
  static String formatCalendarDateForApi(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Proper Calendar Arithmetic:
  /// Monthly: 1 calendar month from activation date (e.g. 3 Sep 2026 -> 3 Oct 2026)
  /// Yearly: 12 calendar months from activation date (e.g. 3 Sep 2026 -> 3 Sep 2027)
  static DateTime calculateExpiryDate(
    DateTime startDate,
    SubscriptionBillingCycle cycle,
  ) {
    if (cycle == SubscriptionBillingCycle.monthly) {
      final year = startDate.year;
      final month = startDate.month;
      final day = startDate.day;

      final targetMonth = month + 1;
      final targetYear = year + ((targetMonth - 1) ~/ 12);
      final normalizedMonth = ((targetMonth - 1) % 12) + 1;

      // Find last day of target month to prevent day overflow (e.g., Jan 31 -> Feb 28/29)
      final lastDayOfTargetMonth = DateTime(
        targetYear,
        normalizedMonth + 1,
        0,
      ).day;
      final targetDay = day <= lastDayOfTargetMonth
          ? day
          : lastDayOfTargetMonth;

      return DateTime(
        targetYear,
        normalizedMonth,
        targetDay,
        startDate.hour,
        startDate.minute,
        startDate.second,
      );
    } else {
      final year = startDate.year + 1;
      final month = startDate.month;
      final day = startDate.day;

      final lastDayOfTargetMonth = DateTime(year, month + 1, 0).day;
      final targetDay = day <= lastDayOfTargetMonth
          ? day
          : lastDayOfTargetMonth;

      return DateTime(
        year,
        month,
        targetDay,
        startDate.hour,
        startDate.minute,
        startDate.second,
      );
    }
  }

  static String generateOrderNumber() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final randomPart = List.generate(
      10,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
    return '#QB-$randomPart';
  }

  /// Default standard plans from reference design as fallback
  static List<SubscriptionPlan> get defaultPlans => [
    const SubscriptionPlan(
      id: '2',
      name: 'Basic Package',
      subtitle: 'Starter Plan',
      code: 'BASIC',
      description: 'Essential digital & social growth for startups',
      monthlyPrice: 9999,
      yearlyPrice: 95990,
      currency: 'INR',
      isRecommended: false,
      userLimit: 5,
      leadLimit: 500,
      storageLimitBytes: 5368709120,
      features: [
        '4 Reels',
        '3 Creative Posts',
        '1 Influencer Promotion',
        '3 Stories',
        'Social Media Account Management',
        'Content Writing & Captions',
        'Trending Hashtags',
        'Meta Ads Campaign Setup & Management',
        'Google Ads Campaign Setup & Management',
        'Monthly Performance Report',
        'Ads will run only during the content execution period.',
        'Meta & Google Ads Budget will be paid by the client.',
      ],
    ),
    const SubscriptionPlan(
      id: '3',
      name: 'Standard Package',
      subtitle: 'Growth Plan',
      code: 'STANDARD',
      description: 'Strategic social presence and targeted advertising',
      monthlyPrice: 14999,
      yearlyPrice: 143990,
      currency: 'INR',
      isRecommended: true,
      userLimit: 25,
      leadLimit: 5000,
      storageLimitBytes: 26843545600,
      features: [
        '6 Reels',
        '4 Creative Posts',
        '2 Influencer Promotions',
        '5 Stories',
        'Social Media Account Management',
        'Trending Hashtags',
        'Meta Ads Campaign Setup & Management',
        'Google Ads Campaign Setup & Management',
        'Monthly Performance Report',
        'Ads will run only during the content execution period.',
        'Meta & Google Ads Budget will be paid by the client.',
      ],
    ),
    const SubscriptionPlan(
      id: '4',
      name: 'Premium Package',
      subtitle: 'Scale Plan',
      code: 'PREMIUM',
      description: 'Full-service enterprise scale suite',
      monthlyPrice: 25999,
      yearlyPrice: 249590,
      currency: 'INR',
      isRecommended: false,
      userLimit: 100,
      leadLimit: 50000,
      storageLimitBytes: 107374182400,
      features: [
        '2 Product Reels',
        '8 Influencer Reels (Total 10 Reels)',
        '8 Creative Posts',
        '30 Stories',
        'Complete Social Media Management',
        'Premium Content Strategy & Caption Writing',
        'Advanced Hashtag Research',
        'Meta Ads Campaign Setup & Management',
        'Google Ads Campaign Setup & Management',
        'Detailed Monthly Analytics Report',
        'Priority Graphic Designing',
        'Ads will run throughout the campaign/content execution period.',
        'Meta & Google Ads Budget will be paid by the client.',
      ],
    ),
  ];

  /// Fetch all available subscription plans from Backend DB API
  Future<List<SubscriptionPlan>> getPlans() async {
    if (_apiClient != null) {
      try {
        final response = await _apiClient.get(AppUrl.plans);
        debugPrint(
          '[PLAN_API_DEBUG]\nendpoint: ${AppUrl.plans}\nstatusCode: ${response.statusCode}\nRaw response: ${response.data}',
        );
        if (response.statusCode == 200 && response.data != null) {
          dynamic rawList;
          if (response.data is List) {
            rawList = response.data;
          } else if (response.data is Map && response.data['data'] is List) {
            rawList = response.data['data'];
          } else if (response.data is Map && response.data['data'] is Map) {
            rawList = [response.data['data']];
          } else if (response.data is Map && response.data['items'] is List) {
            rawList = response.data['items'];
          } else if (response.data is Map && response.data['plans'] is List) {
            rawList = response.data['plans'];
          }

          if (rawList is List) {
            final plans = rawList
                .where((e) => e != null && e is Map)
                .map(
                  (e) => SubscriptionPlan.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList();

            final planIds = plans.map((p) => p.id).join(', ');
            debugPrint(
              '[PLAN_LIST_DEBUG]\ncustomerId: ${_apiClient.customerId ?? 'N/A'}\nreturnedPlanIds: $planIds\nreturnedPlanCount: ${plans.length}',
            );
            debugPrint('[PLAN_MOBILE]\nAPI planIds: $planIds');

            debugPrint('[CACHE] Updating plans from server (${plans.length})');
            await _cachePlans(plans);
            return plans;
          }
        }
      } catch (e) {
        debugPrint(
          '[CustomerSubscriptionService] Network error fetching plans: $e',
        );
      }
    }

    debugPrint('[CACHE] Plans request failed. Using last saved plans.');
    final cached = await _getCachedPlans();
    if (cached.isNotEmpty) {
      return cached;
    }
    return defaultPlans;
  }

  /// Fast load from cache or default plans so UI displays instantly without lag
  Future<List<SubscriptionPlan>> getCachedPlansFast() async {
    final cached = await _getCachedPlans();
    if (cached.isNotEmpty) {
      return cached;
    }
    return defaultPlans;
  }

  /// Get current active/effective subscription from Backend API
  Future<CustomerSubscription?> getCurrentSubscription() async {
    if (_apiClient == null ||
        _apiClient.token == null ||
        _apiClient.token!.isEmpty) {
      return null;
    }

    CustomerSubscription? found;
    var subscriptionEndpointSucceeded = false;
    try {
      final response = await _apiClient.get(AppUrl.effectivePlan);
      if (response.statusCode == 200) {
        subscriptionEndpointSucceeded = true;
        found = _subscriptionFromResponse(response.data);
      }
    } catch (e) {
      debugPrint(
        '[CustomerSubscriptionService] Effective plan request failed: $e',
      );
    }

    if (found == null || !found.isPurchasedPlanVisible) {
      try {
        final currResponse = await _apiClient.get(AppUrl.currentSubscription);
        if (currResponse.statusCode == 200) {
          subscriptionEndpointSucceeded = true;
          final parsed = _subscriptionFromResponse(currResponse.data);
          if (parsed != null &&
              (parsed.isPurchasedPlanVisible || found == null)) {
            found = parsed;
          }
        }
      } catch (e) {
        debugPrint(
          '[CustomerSubscriptionService] Current subscription request failed: $e',
        );
      }
    }

    // Subscription endpoints can return an empty body for a paid offline
    // purchase whose start date is still ahead. The existing orders API already
    // has that purchase. Use it only when no subscription record was returned.
    found ??= await _subscriptionFromPaidOrders();

    if (found != null && found.isPurchasedPlanVisible) {
      debugPrint(
        '[SUBSCRIPTION_SYNC_FLUTTER] CUSTOMER ID: ${found.customerId} | PLAN ID: ${found.planId} | SUBSCRIPTION ID: ${found.id} | STATUS: ${found.status.name.toUpperCase()}',
      );
      await _cacheSubscription(found);
      return found;
    }

    if (!subscriptionEndpointSucceeded) {
      final cached = await _getCachedSubscription();
      if (cached != null && cached.isPurchasedPlanVisible) return cached;
    }

    await _clearCachedSubscription();
    return null;
  }

  /// Fully paid, unexpired order for the same customer. Pending, failed, and
  /// rejected payments are ignored so they cannot appear as an active plan.
  Future<CustomerSubscription?> _subscriptionFromPaidOrders() async {
    try {
      final orders = await getOrders(limit: 50);
      final now = DateTime.now();
      CustomerOrder? latestPaid;
      for (final order in orders) {
        if (!order.isPaid || order.isPartiallyPaid) continue;
        if (order.planId.trim().isEmpty && order.planName.trim().isEmpty) {
          continue;
        }
        final endOfDay = DateTime(
          order.expiryDate.year,
          order.expiryDate.month,
          order.expiryDate.day,
          23,
          59,
          59,
        );
        final startsLater = order.activationDate.isAfter(now);
        if (!startsLater && now.isAfter(endOfDay)) continue;
        if (latestPaid == null ||
            order.purchaseDate.isAfter(latestPaid.purchaseDate)) {
          latestPaid = order;
        }
      }
      if (latestPaid == null) return null;
      final startsLater = latestPaid.activationDate.isAfter(now);
      return CustomerSubscription(
        id: latestPaid.id,
        customerId: _apiClient?.customerId ?? '',
        planId: latestPaid.planId,
        planName: latestPaid.planName,
        planCode: '',
        status: startsLater
            ? SubscriptionStatus.upcoming
            : SubscriptionStatus.active,
        billingCycle: latestPaid.billingCycle,
        startDate: latestPaid.activationDate,
        endDate: latestPaid.expiryDate,
        purchaseDate: latestPaid.purchaseDate,
        expiryDate: latestPaid.expiryDate,
        price: latestPaid.amount,
        purchasedPrice: latestPaid.amount,
        features: latestPaid.features,
      );
    } catch (e) {
      debugPrint(
        '[CustomerSubscriptionService] Paid order fallback failed: $e',
      );
      return null;
    }
  }

  CustomerSubscription? _subscriptionFromResponse(dynamic raw) {
    if (raw is! Map) return null;
    final upcoming = _extractUpcomingPlan(raw, raw['data']);
    final nested = raw['data'];
    final candidates = <dynamic>[
      raw['subscription'],
      raw['currentPlan'],
      raw['effectivePlan'],
      nested,
      if (nested is Map) nested['subscription'],
      if (nested is Map) nested['data'],
      if (nested is Map) nested['currentPlan'],
    ];
    for (final candidate in candidates) {
      if (candidate is! Map) continue;
      final map = Map<String, dynamic>.from(candidate);
      final plan = map['plan'];
      if (plan is Map) {
        map.putIfAbsent('planName', () => plan['planName'] ?? plan['name']);
        map.putIfAbsent('name', () => plan['name'] ?? plan['planName']);
        map.putIfAbsent('planId', () => plan['planId'] ?? plan['id']);
        map.putIfAbsent('planCode', () => plan['planCode'] ?? plan['code']);
        map.putIfAbsent('code', () => plan['code'] ?? plan['planCode']);
      }
      final hasPlan = map['planName'] != null ||
          map['name'] != null ||
          map['planId'] != null ||
          map['subscriptionId'] != null ||
          map['planCode'] != null ||
          map['code'] != null;
      if (!hasPlan) continue;
      if (upcoming != null && map['upcomingPlan'] is! Map) {
        map['upcomingPlan'] = upcoming;
      }
      try {
        final sub = CustomerSubscription.fromJson(map);
        if (sub.isPurchasedPlanVisible) return sub;
      } catch (e) {
        debugPrint(
          '[CustomerSubscriptionService] Skipped unreadable plan payload: $e',
        );
      }
    }
    if (upcoming != null) {
      final up = UpcomingPlan.fromJson(upcoming);
      return CustomerSubscription(
        id: up.id,
        customerId: _apiClient?.customerId ?? '',
        planId: up.planId,
        planName: up.planName,
        planCode: up.planCode,
        status: SubscriptionStatus.upcoming,
        billingCycle: up.billingCycle,
        startDate: up.startDate,
        endDate: up.endDate,
        purchaseDate: up.startDate,
        expiryDate: up.endDate,
        price: up.price,
        purchasedPrice: up.price,
        upcomingPlan: up,
      );
    }
    return null;
  }


  Map<String, dynamic>? _extractUpcomingPlan(dynamic raw, dynamic nestedData) {
    if (raw is Map && raw['upcomingPlan'] is Map) {
      return Map<String, dynamic>.from(raw['upcomingPlan'] as Map);
    }
    if (nestedData is Map && nestedData['upcomingPlan'] is Map) {
      return Map<String, dynamic>.from(nestedData['upcomingPlan'] as Map);
    }
    return null;
  }

  /// Get upcoming subscription plan if scheduled in the future
  Future<UpcomingPlan?> getUpcomingPlan() async {
    if (_apiClient != null &&
        _apiClient.token != null &&
        _apiClient.token!.isNotEmpty) {
      try {
        final response = await _apiClient.get(AppUrl.effectivePlan);
        if (response.statusCode == 200 && response.data != null) {
          final resData = response.data;
          final nested = resData is Map ? resData['data'] : null;
          final extracted = _extractUpcomingPlan(resData, nested);
          if (extracted != null) {
            return UpcomingPlan.fromJson(extracted);
          }
        }
      } catch (e) {
        debugPrint(
          '[CustomerSubscriptionService] Error fetching upcoming plan: $e',
        );
      }
    }
    final sub = await getCurrentSubscription();
    if (sub?.upcomingPlan != null) return sub!.upcomingPlan;
    if (sub != null && sub.isUpcoming) {
      return UpcomingPlan(
        id: sub.id,
        subscriptionId: sub.id,
        planId: sub.planId,
        planName: sub.planName,
        planCode: sub.planCode,
        startDate: sub.startDate,
        endDate: sub.endDate,
        status: SubscriptionStatus.upcoming,
        billingCycle: sub.billingCycle,
        price: sub.price,
      );
    }
    return null;
  }

  /// Get structured Current Subscription & Installment state from GET /subscriptions/current
  Future<CurrentSubscription> getCurrentSubscriptionDetails() async {
    debugPrint('[SUBSCRIPTION_REQUEST] customerId: AUTH_USER');
    if (_apiClient != null &&
        _apiClient.token != null &&
        _apiClient.token!.isNotEmpty) {
      try {
        final response = await _apiClient.get(AppUrl.currentSubscription);
        if (response.statusCode == 200 && response.data != null) {
          dynamic data = response.data;
          if (data is Map && data.containsKey('data')) {
            data = data['data'];
          }
          if (data is Map<String, dynamic>) {
            return CurrentSubscription.fromJson(data);
          }
        }
      } on DioException catch (dioErr) {
        final status = dioErr.response?.statusCode;
        final msg = dioErr.response?.data?['message']?.toString();
        if (status == 401) {
          throw Exception('Session expired. Please login again.');
        } else if (status == 403) {
          throw Exception('You are not authorized to access this customer.');
        } else if (status == 404) {
          throw Exception('Subscription not found.');
        } else if (status == 400 && msg != null) {
          throw Exception(msg);
        } else if (status != null && status >= 500) {
          throw Exception('Something went wrong. Please try again.');
        }
        rethrow;
      } catch (e) {
        debugPrint(
          '[CustomerSubscriptionService] Error fetching current subscription: $e',
        );
        rethrow;
      }
    }
    throw Exception('Authentication required to fetch subscription status.');
  }

  /// Get Renewal and Buffer Period Status from GET /subscriptions/renewal-status
  Future<RenewalStatus?> getRenewalStatus() async {
    final customerId = _apiClient?.customerId ?? '';
    final token = _apiClient?.token;
    final baseUrl = AppUrl.baseUrl;
    final fullUrl = '$baseUrl${AppUrl.renewalStatus}';

    debugPrint('[RENEWAL_STATUS_DEBUG]');
    debugPrint('customerId: $customerId');
    debugPrint('endpoint: ${AppUrl.renewalStatus}');
    debugPrint('request URL: $fullUrl');
    debugPrint('x-customer-id: $customerId');
    debugPrint('authenticatedUserId: $customerId');

    if (_apiClient != null && token != null && token.isNotEmpty) {
      try {
        final response = await _apiClient.get(AppUrl.renewalStatus);
        if (response.statusCode == 200 && response.data != null) {
          dynamic data = response.data;
          if (data is Map && data.containsKey('data')) {
            data = data['data'];
          }
          if (data is Map<String, dynamic>) {
            return RenewalStatus.fromJson(data);
          }
        }
      } on DioException catch (dioErr) {
        final status = dioErr.response?.statusCode;
        final rawMsg = dioErr.response?.data?['message']?.toString() ?? '';
        final errorDetails =
            dioErr.response?.data?['errorDetails']?.toString() ?? '';
        final msgLower = '$rawMsg $errorDetails'.toLowerCase();

        if (status == 404 &&
            (msgLower.contains('no subscription found') ||
                msgLower.contains('subscription not found'))) {
          debugPrint(
            '[RENEWAL_STATUS_DEBUG] No subscription found for customer $customerId - treating as null',
          );
          return null;
        }

        if (status == 401) {
          throw Exception('Session expired. Please login again.');
        } else if (status == 403) {
          throw Exception('You are not authorized to access this customer.');
        } else if (status == 404) {
          throw Exception('Subscription not found.');
        } else if (status == 400 && rawMsg.isNotEmpty) {
          throw Exception(rawMsg);
        } else if (status != null && status >= 500) {
          throw Exception('Something went wrong. Please try again.');
        }
        rethrow;
      } catch (e) {
        debugPrint(
          '[CustomerSubscriptionService] Error fetching renewal status: $e',
        );
        rethrow;
      }
    }
    throw Exception('Authentication required to fetch renewal status.');
  }

  /// Renew existing installment under active buffer period POST /subscriptions/:subscriptionId/renew
  Future<PaymentOrder> renewInstallment({
    required String subscriptionId,
    required String installmentId,
    String paymentMethod = 'ONLINE',
  }) async {
    debugPrint(
      '[RENEWAL_REQUEST] customerId: AUTH_USER, subscriptionId: $subscriptionId, installmentId: $installmentId',
    );
    if (_apiClient != null &&
        _apiClient.token != null &&
        _apiClient.token!.isNotEmpty) {
      try {
        final response = await _apiClient.post(
          '/subscriptions/$subscriptionId/renew',
          data: {
            'installmentId': installmentId,
            'paymentMethod': paymentMethod,
          },
        );
        if ((response.statusCode == 200 || response.statusCode == 201) &&
            response.data != null) {
          dynamic data = response.data;
          if (data is Map && data.containsKey('data')) {
            data = data['data'];
          }
          if (data is Map<String, dynamic>) {
            return PaymentOrder.fromJson(data);
          }
        }
      } on DioException catch (dioErr) {
        final status = dioErr.response?.statusCode;
        final msg = dioErr.response?.data?['message']?.toString();
        if (status == 401) {
          throw Exception('Session expired. Please login again.');
        } else if (status == 403) {
          throw Exception('You are not authorized to access this customer.');
        } else if (status == 404) {
          throw Exception('Subscription not found.');
        } else if (status == 400 && msg != null) {
          throw Exception(msg);
        } else if (status != null && status >= 500) {
          throw Exception('Something went wrong. Please try again.');
        }
        rethrow;
      }
    }
    throw Exception('Authentication required to initiate renewal.');
  }

  /// Start a completely new plan when prior installment renewal has failed POST /subscriptions/new-plan
  Future<Map<String, dynamic>> startNewPlan({
    required String planId,
    int? totalInstallments,
    String paymentMethod = 'ONLINE',
  }) async {
    debugPrint(
      '[NEW_PLAN_REQUEST] planId: $planId, totalInstallments: $totalInstallments',
    );
    if (_apiClient != null &&
        _apiClient.token != null &&
        _apiClient.token!.isNotEmpty) {
      try {
        final response = await _apiClient.post(
          AppUrl.newPlan,
          data: {
            'planId': planId,
            'totalInstallments': ?totalInstallments,
            'paymentMethod': paymentMethod,
          },
        );
        if ((response.statusCode == 200 || response.statusCode == 201) &&
            response.data != null) {
          dynamic data = response.data;
          if (data is Map && data.containsKey('data')) {
            return Map<String, dynamic>.from(data['data'] as Map);
          }
          if (data is Map<String, dynamic>) {
            return data;
          }
        }
      } on DioException catch (dioErr) {
        final status = dioErr.response?.statusCode;
        final msg = dioErr.response?.data?['message']?.toString();
        if (status == 401) {
          throw Exception('Session expired. Please login again.');
        } else if (status == 403) {
          throw Exception('You are not authorized to access this customer.');
        } else if (status == 404) {
          throw Exception('Subscription or plan not found.');
        } else if (status == 400 && msg != null) {
          throw Exception(msg);
        } else if (status != null && status >= 500) {
          throw Exception('Something went wrong. Please try again.');
        }
        rethrow;
      }
    }
    throw Exception('Authentication required to start new plan.');
  }

  /// Get customer purchase and orders history with search, status filter & pagination from Backend API
  Future<List<CustomerOrder>> getOrders({
    String? search,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    if (_apiClient != null &&
        _apiClient.token != null &&
        _apiClient.token!.isNotEmpty) {
      try {
        final response = await _apiClient.get(
          AppUrl.customerOrders,
          queryParameters: {
            if (search != null && search.isNotEmpty) 'search': search,
            if (status != null && status.isNotEmpty) 'status': status,
            'page': page,
            'limit': limit,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          dynamic rawList;
          if (response.data is List) {
            rawList = response.data;
          } else if (response.data is Map) {
            final dataMap = response.data as Map;
            if (dataMap['data'] is List) {
              rawList = dataMap['data'];
            } else if (dataMap['data'] is Map &&
                dataMap['data']['items'] is List) {
              rawList = dataMap['data']['items'];
            } else if (dataMap['items'] is List) {
              rawList = dataMap['items'];
            }
          }

          if (rawList is List) {
            final orders = rawList
                .map(
                  (e) => CustomerOrder.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList();
            debugPrint('[CACHE] Updating orders from server (${orders.length})');
            await _cacheOrders(orders);
            return orders;
          }
          return const [];
        }
      } catch (e) {
        debugPrint(
          '[CustomerSubscriptionService] Network error fetching orders: $e',
        );
      }
    }

    debugPrint('[CACHE] Orders request failed. Using last saved orders.');
    final cached = await _getCachedOrders();
    return cached;
  }

  /// Get customer final tax invoices from Backend API
  Future<List<CustomerInvoice>> getInvoices({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    // Ensure in-memory token is loaded from secure storage (handles cold-start)
    if (_apiClient != null) {
      await _apiClient.ensureAuthLoaded();
    }

    debugPrint('[AUTH_DEBUG]');
    debugPrint(
      'Authorization header present: ${_apiClient?.token != null && _apiClient!.token!.isNotEmpty}',
    );
    debugPrint('Token received: ${_apiClient?.token != null}');

    if (_apiClient == null ||
        _apiClient.token == null ||
        _apiClient.token!.isEmpty) {
      debugPrint('[AUTH_DEBUG] No valid token — cannot fetch invoices.');
      return const [];
    }

    try {
      final response = await _apiClient.get(
        AppUrl.invoices,
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          'page': page,
          'limit': limit,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        dynamic rawList;
        if (response.data is List) {
          rawList = response.data;
        } else if (response.data is Map) {
          final dataMap = response.data as Map;
          if (dataMap['data'] is List) {
            rawList = dataMap['data'];
          } else if (dataMap['data'] is Map &&
              dataMap['data']['items'] is List) {
            rawList = dataMap['data']['items'];
          } else if (dataMap['items'] is List) {
            rawList = dataMap['items'];
          }
        }

        if (rawList is List) {
          return rawList
              .map(
                (e) => CustomerInvoice.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      }
      return const [];
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      debugPrint(
        '[CustomerSubscriptionService] Invoice API error: HTTP $status - ${e.message}',
      );
      // Re-throw 401/403 so the interceptor refresh flow and the caller handle it properly.
      // Do NOT convert auth errors into empty invoice lists — that hides authentication bugs.
      if (status == 401 || status == 403) {
        rethrow;
      }
      // For other network/server errors, return empty and log
      debugPrint(
        '[CustomerSubscriptionService] Non-auth error fetching invoices: $e',
      );
      return const [];
    } catch (e) {
      debugPrint('[CustomerSubscriptionService] Error fetching invoices: $e');
      return const [];
    }
  }

  /// Validate a coupon. The returned amounts are calculated by the server.
  Future<Map<String, dynamic>> applyCoupon({
    required SubscriptionPlan plan,
    required SubscriptionBillingCycle billingCycle,
    required String couponCode,
    String paymentOption = 'FULL',
  }) async {
    if (_apiClient == null ||
        _apiClient.token == null ||
        _apiClient.token!.isEmpty) {
      throw Exception('Authentication required to apply a coupon.');
    }
    final dynamic planIdPayload = int.tryParse(plan.id) ?? plan.id;
    try {
      final response = await _apiClient.post(
        '/subscriptions/apply-coupon',
        data: {
          'planId': planIdPayload,
          'couponCode': couponCode.trim(),
          'billingCycle': billingCycle.code,
          'paymentOption': paymentOption,
        },
      );
      final raw = response.data;
      if (raw is Map && raw['data'] is Map) {
        return Map<String, dynamic>.from(raw['data'] as Map);
      }
      if (raw is Map) return Map<String, dynamic>.from(raw);
      throw Exception('Coupon could not be applied.');
    } on DioException catch (e) {
      final data = e.response?.data;
      String message = 'Coupon could not be applied.';
      if (data is Map && data['message'] != null) {
        final rawMessage = data['message'];
        message = rawMessage is List
            ? rawMessage.join(', ')
            : rawMessage.toString();
      }
      throw Exception(message);
    }
  }

  /// Step 1: Create a Razorpay Order on Backend (Supports FULL or ADVANCE payment)
  Future<Map<String, dynamic>> createRazorpayOrder({
    required SubscriptionPlan plan,
    required SubscriptionBillingCycle billingCycle,
    String paymentOption = 'FULL',
    DateTime? activationDate,
    String? couponCode,
  }) async {
    // Ensure credentials from secure storage are loaded into memory
    final storedToken = await SecureStorageService.getAccessToken();
    final storedCustId = await SecureStorageService.getCustomerId() ?? '';
    final storedRefresh = await SecureStorageService.getRefreshToken();
    if (storedToken != null && storedToken.isNotEmpty) {
      _apiClient?.setAuth(
        storedToken,
        storedCustId,
        refreshToken: storedRefresh,
      );
    }

    if (_apiClient == null ||
        _apiClient.token == null ||
        _apiClient.token!.isEmpty) {
      throw Exception('Authentication required to create a purchase order.');
    }

    final startDate = DateTime.now();
    final expiryDate = calculateExpiryDate(startDate, billingCycle);
    final basePrice = plan.priceFor(billingCycle);
    final gstTax = basePrice * 0.18;
    final totalAmount = basePrice + gstTax;
    final isAdvance =
        paymentOption.toUpperCase() == 'ADVANCE' ||
        paymentOption.toUpperCase() == 'HALF';
    final payableAmount = isAdvance ? (totalAmount * 0.5) : totalAmount;
    final amountInPaise = (payableAmount * 100).round();

    final dynamic planIdPayload = int.tryParse(plan.id) ?? plan.id;
    final payload = {
      'planId': planIdPayload,
      'billingCycle': billingCycle.code,
      'paymentOption': paymentOption,
      'currency': plan.currency,
      if (activationDate != null)
        'activationDate': formatCalendarDateForApi(activationDate),
      if (couponCode != null && couponCode.trim().isNotEmpty)
        'couponCode': couponCode.trim(),
    };

    debugPrint('==================================================');
    debugPrint('[PAYMENT_ORDER_REQUEST] Outgoing Create Order API:');
    debugPrint('URL: ${AppUrl.razorpayOrder}');
    debugPrint('Method: POST');
    debugPrint(
      'Authorization header attached: ${_apiClient.token?.isNotEmpty == true}',
    );
    debugPrint('Payload: ${jsonEncode(payload)}');
    debugPrint('Plan ID: ${plan.id} (${plan.name})');
    debugPrint('Billing Cycle: ${billingCycle.label} (${billingCycle.code})');
    debugPrint('Payment Option: $paymentOption');
    debugPrint('Payable Amount: ₹${payableAmount.round()}');
    debugPrint('Amount in Paise: $amountInPaise paise');
    debugPrint(
      'Validity Period: ${startDate.toIso8601String().split('T').first} -> ${expiryDate.toIso8601String().split('T').first}',
    );
    debugPrint('==================================================');

    try {
      final response = await _postDroppingUnknownActivationDate(
        AppUrl.razorpayOrder,
        payload,
      );

      debugPrint(
        '[PAYMENT_ORDER_SUCCESS] HTTP ${response.statusCode}: ${response.data}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic> resMap = {};
        if (response.data is Map) {
          resMap = Map<String, dynamic>.from(response.data as Map);
        }
        // If data is nested under 'data', merge into root map for convenient direct access
        if (resMap['data'] is Map) {
          final inner = Map<String, dynamic>.from(resMap['data'] as Map);
          resMap.addAll(inner);
        }
        return resMap;
      }
      throw Exception(
        'Failed creating payment order. Status: ${response.statusCode}',
      );
    } on DioException catch (dioErr) {
      final errorMsg = _extractDioErrorMessage(
        dioErr,
        defaultMessage: 'Unable to initiate payment order. Please try again.',
      );
      debugPrint(
        '[CustomerSubscriptionService] createRazorpayOrder error: $errorMsg',
      );
      throw Exception(errorMsg);
    } catch (e) {
      debugPrint('[CustomerSubscriptionService] createRazorpayOrder error: $e');
      rethrow;
    }
  }

  /// Step 2: Verify Razorpay Payment Signature on Backend & Activate Subscription
  Future<Map<String, dynamic>> verifyRazorpayPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required String planId,
    required SubscriptionBillingCycle billingCycle,
    String paymentOption = 'FULL',
    DateTime? activationDate,
    String? couponCode,
  }) async {
    if (_apiClient == null ||
        _apiClient.token == null ||
        _apiClient.token!.isEmpty) {
      throw Exception('Authentication required to verify payment.');
    }

    final dynamic planIdPayload = int.tryParse(planId) ?? planId;
    final payload = {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
      'planId': planIdPayload,
      'billingCycle': billingCycle.code,
      'paymentOption': paymentOption,
      if (activationDate != null)
        'activationDate': formatCalendarDateForApi(activationDate),
      if (couponCode != null && couponCode.trim().isNotEmpty)
        'couponCode': couponCode.trim(),
    };

    debugPrint('==================================================');
    debugPrint('[PAYMENT_VERIFY_REQUEST] Outgoing Verify API:');
    debugPrint('URL: ${AppUrl.razorpayVerify}');
    debugPrint('Method: POST');
    debugPrint('Order ID: $razorpayOrderId');
    debugPrint('Payment ID: $razorpayPaymentId');
    debugPrint('Plan ID: $planId');
    debugPrint('Billing Cycle: ${billingCycle.code}');
    debugPrint('==================================================');

    try {
      final response = await _postDroppingUnknownActivationDate(
        AppUrl.razorpayVerify,
        payload,
      );

      debugPrint(
        '[PAYMENT_VERIFY_SUCCESS] HTTP ${response.statusCode}: ${response.data}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        dynamic data = response.data;
        if (data is Map && data['success'] == false) {
          final errMsg =
              data['message']?.toString() ??
              'Payment verification rejected by server.';
          throw Exception(errMsg);
        }

        if (data is Map && data['data'] != null) {
          data = data['data'];
        }

        CustomerOrder? order;
        CustomerSubscription? subscription;

        if (data is Map) {
          if (data['order'] != null && data['order'] is Map) {
            order = CustomerOrder.fromJson(
              Map<String, dynamic>.from(data['order'] as Map),
            );
          }
          if (data['subscription'] != null && data['subscription'] is Map) {
            subscription = CustomerSubscription.fromJson(
              Map<String, dynamic>.from(data['subscription'] as Map),
            );
            await _cacheSubscription(subscription);
          }
        }

        if (order != null) {
          final existing = await getOrders();
          await _cacheOrders([
            order,
            ...existing.where((o) => o.id != order!.id),
          ]);
        }

        return {
          'success': true,
          'message':
              (response.data is Map ? response.data['message'] : null) ??
              'Payment verified and plan subscription activated successfully!',
          'order': order,
          'subscription': subscription,
        };
      }
      throw Exception('Payment verification failed.');
    } on DioException catch (dioErr) {
      final errorMsg = _extractDioErrorMessage(
        dioErr,
        defaultMessage:
            'Payment verification could not be completed. Please try again.',
      );
      debugPrint(
        '[CustomerSubscriptionService] verifyRazorpayPayment error: $errorMsg',
      );
      throw Exception(errorMsg);
    } catch (e) {
      debugPrint(
        '[CustomerSubscriptionService] verifyRazorpayPayment error: $e',
      );
      rethrow;
    }
  }

  /// Cleanly extract user-friendly error message from DioException
  String _extractDioErrorMessage(
    DioException dioErr, {
    String defaultMessage = 'Payment could not be completed. Please try again.',
  }) {
    final resData = dioErr.response?.data;
    final statusCode = dioErr.response?.statusCode;
    String? serverMsg;

    if (resData is Map) {
      if (resData['message'] is String) {
        serverMsg = resData['message'];
      } else if (resData['message'] is List &&
          (resData['message'] as List).isNotEmpty) {
        serverMsg = (resData['message'] as List).join(', ');
      } else if (resData['errors'] is List &&
          (resData['errors'] as List).isNotEmpty) {
        serverMsg = (resData['errors'] as List).join(', ');
      } else if (resData['error'] is String) {
        serverMsg = resData['error'];
      }
    }

    if (statusCode != null) {
      if (statusCode == 400 || statusCode == 422) {
        return serverMsg ??
            'Invalid payment details provided. Please check and try again.';
      } else if (statusCode == 401) {
        return 'Session expired. Please login again.';
      } else if (statusCode == 403) {
        return 'Payment is not permitted for this account.';
      } else if (statusCode == 404) {
        return serverMsg ?? 'Requested subscription plan was not found.';
      } else if (statusCode >= 500) {
        return 'Payment service is temporarily unavailable. Please try again.';
      }
    }

    if (dioErr.type == DioExceptionType.connectionTimeout ||
        dioErr.type == DioExceptionType.sendTimeout ||
        dioErr.type == DioExceptionType.receiveTimeout ||
        dioErr.type == DioExceptionType.connectionError) {
      return 'Network connection issue. Please check your internet connection.';
    }

    return serverMsg ?? defaultMessage;
  }

  /// Get verified invoice details for a specific order
  Future<Map<String, dynamic>?> getOrderInvoice(String orderIdOrNumber) async {
    final orders = await getOrders();
    final match = orders
        .where(
          (o) => o.id == orderIdOrNumber || o.orderNumber == orderIdOrNumber,
        )
        .firstOrNull;
    if (match != null) {
      return {
        'invoiceNumber': match.orderNumber,
        'amount': match.amount,
        'taxAmount': match.taxAmount,
        'totalAmount': match.totalAmount,
        'paymentStatus': match.paymentStatus,
        'paymentMethod': match.paymentMethod,
        'purchaseDate': match.purchaseDate.toIso8601String(),
      };
    }
    return null;
  }

  // ── Cache helpers ──────────────────────────────────────────────────────────

  Future<void> _cachePlans(List<SubscriptionPlan> plans) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (plans.isEmpty) {
        await prefs.remove(_customerScopedPlansKey);
        await prefs.remove(_kCachedPlansKey);
      } else {
        final jsonList = plans.map((p) => p.toJson()).toList();
        await prefs.setString(_customerScopedPlansKey, jsonEncode(jsonList));
        if (_customerScopedPlansKey != _kCachedPlansKey) {
          await prefs.remove(_kCachedPlansKey);
        }
      }
    } catch (e) {
      debugPrint('[CustomerSubscriptionService] Error caching plans: $e');
    }
  }

  Future<List<SubscriptionPlan>> _getCachedPlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_customerScopedPlansKey);
      if (str != null) {
        final list = jsonDecode(str) as List;
        return list
            .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint(
        '[CustomerSubscriptionService] Error reading cached plans: $e',
      );
    }
    return [];
  }

  Future<void> _cacheSubscription(CustomerSubscription sub) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customerScopedSubscriptionKey,
      jsonEncode(sub.toJson()),
    );
  }

  Future<void> _clearCachedSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_customerScopedSubscriptionKey);
      await prefs.remove(_kCachedSubscriptionKey);
    } catch (_) {}
  }

  /// Fetch dynamic payment configuration from backend (database is source of truth)
  Future<Map<String, dynamic>> getPaymentConfig() async {
    if (_apiClient != null) {
      try {
        final response = await _apiClient.get(AppUrl.paymentConfig);
        if (response.statusCode == 200 && response.data != null) {
          if (response.data is Map && response.data['data'] is Map) {
            return Map<String, dynamic>.from(response.data['data'] as Map);
          } else if (response.data is Map<String, dynamic>) {
            return response.data;
          }
        }
      } catch (e) {
        debugPrint(
          '[CustomerSubscriptionService] Error fetching payment config: $e',
        );
      }
    }
    return {
      'razorpayEnabled': true,
      'offlinePaymentEnabled': true,
      'paymentMode': 'TEST',
    };
  }

  /// Create Offline / Cash Payment Order
  Future<Map<String, dynamic>> createOfflinePaymentOrder({
    required SubscriptionPlan plan,
    required SubscriptionBillingCycle billingCycle,
    String paymentMethod = 'CASH',
    String paymentOption = 'FULL',
    String? referenceNumber,
    String? notes,
    DateTime? activationDate,
    String? couponCode,
  }) async {
    // Ensure credentials from secure storage are loaded into memory
    final storedToken = await SecureStorageService.getAccessToken();
    final storedCustId = await SecureStorageService.getCustomerId() ?? '';
    final storedRefresh = await SecureStorageService.getRefreshToken();
    if (storedToken != null && storedToken.isNotEmpty) {
      _apiClient?.setAuth(
        storedToken,
        storedCustId,
        refreshToken: storedRefresh,
      );
    }

    if (_apiClient == null ||
        _apiClient.token == null ||
        _apiClient.token!.isEmpty) {
      throw Exception('Authentication required to create a purchase order.');
    }

    final dynamic planIdPayload = int.tryParse(plan.id) ?? plan.id;
    final payload = {
      'planId': planIdPayload,
      'billingCycle': billingCycle.code,
      'paymentMethod': paymentMethod,
      'paymentOption': paymentOption,
      'referenceNumber': referenceNumber ?? '',
      'notes': notes ?? '',
      if (activationDate != null)
        'activationDate': formatCalendarDateForApi(activationDate),
      if (couponCode != null && couponCode.trim().isNotEmpty)
        'couponCode': couponCode.trim(),
    };

    try {
      final response = await _postDroppingUnknownActivationDate(
        '/payments/offline/order',
        payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic> resMap = {};
        if (response.data is Map) {
          resMap = Map<String, dynamic>.from(response.data as Map);
        }
        if (resMap['data'] is Map) {
          final inner = Map<String, dynamic>.from(resMap['data'] as Map);
          resMap.addAll(inner);
        }
        return resMap;
      }
      throw Exception('Failed creating offline payment request.');
    } on DioException catch (dioErr) {
      final errMsg = _extractDioErrorMessage(
        dioErr,
        defaultMessage: 'Failed creating offline payment request.',
      );
      throw Exception(errMsg);
    }
  }

  /// Direct plan purchase with auto-created activity schedules
  Future<Map<String, dynamic>> purchaseSubscription(int planId) async {
    try {
      debugPrint('[SUBSCRIPTION] Purchasing plan: $planId');
      final response = await _apiClient!.post(
        '/works/subscription/purchase',
        data: {'planId': planId},
      );
      debugPrint('[SUBSCRIPTION] Purchase successful: ${response.data}');
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {'success': true};
    } on DioException catch (e) {
      final errMsg = _extractDioErrorMessage(
        e,
        defaultMessage: 'Purchase failed',
      );
      debugPrint('[SUBSCRIPTION] Error: $errMsg');
      throw Exception(errMsg);
    }
  }

  /// Get scheduled calendar events for date
  Future<Map<String, dynamic>> getCalendarSchedule(String date) async {
    try {
      debugPrint('[CALENDAR] Fetching schedule for: $date');
      final response = await _apiClient!.get(
        '/works/calendar',
        queryParameters: {'date': date},
      );
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      } else if (response.data is List) {
        return {'date': date, 'activities': response.data};
      }
      return {'date': date, 'activities': []};
    } catch (e) {
      debugPrint('[CALENDAR] Error: $e');
      throw Exception('Failed to load calendar');
    }
  }

  /// Get month calendar view
  Future<Map<String, dynamic>> getMonthCalendar(int year, int month) async {
    try {
      final response = await _apiClient!.get(
        '/works/calendar/month',
        queryParameters: {'year': year, 'month': month},
      );
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {'year': year, 'month': month, 'calendar': {}};
    } catch (e) {
      throw Exception('Failed to load month calendar');
    }
  }

  /// Mark activity schedule as completed
  Future<void> completeActivity(int activityScheduleId) async {
    try {
      debugPrint('[ACTIVITY] Marking complete: $activityScheduleId');
      await _apiClient!.post(
        '/works/activity/complete',
        data: {'activityScheduleId': activityScheduleId},
      );
      debugPrint('[ACTIVITY] Marked complete');
    } catch (e) {
      throw Exception('Failed to complete activity: $e');
    }
  }

  /// Skip an activity schedule
  Future<void> skipActivity(int activityScheduleId) async {
    try {
      await _apiClient!.post(
        '/works/activity/skip',
        data: {'activityScheduleId': activityScheduleId},
      );
    } catch (e) {
      throw Exception('Failed to skip activity: $e');
    }
  }

  Future<CustomerSubscription?> _getCachedSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_customerScopedSubscriptionKey);
      if (str != null) {
        final sub = CustomerSubscription.fromJson(
          jsonDecode(str) as Map<String, dynamic>,
        );
        // Validate customer isolation on cached subscription
        final currentCid = _apiClient?.customerId?.trim();
        if (currentCid != null &&
            currentCid.isNotEmpty &&
            sub.customerId.isNotEmpty &&
            sub.customerId != currentCid) {
          debugPrint(
            '[CustomerSubscriptionService] Cached subscription customerId mismatch: ${sub.customerId} != $currentCid. Discarding stale cache.',
          );
          await _clearCachedSubscription();
          return null;
        }
        return sub;
      }
    } catch (e) {
      debugPrint(
        '[CustomerSubscriptionService] Error reading cached subscription: $e',
      );
    }
    return null;
  }

  Future<void> _cacheOrders(List<CustomerOrder> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = orders.map((o) => o.toJson()).toList();
    await prefs.setString(_customerScopedOrdersKey, jsonEncode(jsonList));
    if (_customerScopedOrdersKey != _kCachedOrdersKey) {
      await prefs.remove(_kCachedOrdersKey);
    }
  }

  Future<List<CustomerOrder>> _getCachedOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_customerScopedOrdersKey);
      if (str != null) {
        final list = jsonDecode(str) as List;
        return list
            .map((e) => CustomerOrder.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint(
        '[CustomerSubscriptionService] Error reading cached orders: $e',
      );
    }
    return [];
  }
}
