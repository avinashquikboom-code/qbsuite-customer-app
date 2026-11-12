import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import 'package:quickboom_crm_customer/roles/customer/models/custom_plan_model.dart';

final customPlanServiceProvider = Provider<CustomPlanService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CustomPlanService(apiClient: apiClient);
});

class CustomPlanService {
  final ApiClient? _apiClient;

  CustomPlanService({ApiClient? apiClient}) : _apiClient = apiClient;

  static const List<CustomPlanOption> defaultOptions = [
    CustomPlanOption(
      id: 1,
      name: 'Social Media Reels',
      code: 'OPT_REELS',
      description:
          'High engagement scripted and edited reels with trending audio',
      category: 'CONTENT',
      monthlyPrice: 1000,
      pricingType: 'PER_UNIT',
      unitName: 'Reel',
      minQuantity: 0,
      maxQuantity: 50,
      defaultQuantity: 4,
      isIncludedInStandard: true,
    ),
    CustomPlanOption(
      id: 2,
      name: 'Creative Graphic Posts',
      code: 'OPT_CREATIVES',
      description: 'High-converting custom visual posts & infographics',
      category: 'CREATIVES',
      monthlyPrice: 600,
      pricingType: 'PER_UNIT',
      unitName: 'Post',
      minQuantity: 0,
      maxQuantity: 50,
      defaultQuantity: 3,
      isIncludedInStandard: true,
    ),
    CustomPlanOption(
      id: 3,
      name: 'Daily Story Updates',
      code: 'OPT_STORIES',
      description:
          'Engaging daily interactive stories with poll stickers & links',
      category: 'CREATIVES',
      monthlyPrice: 150,
      pricingType: 'PER_UNIT',
      unitName: 'Story',
      minQuantity: 0,
      maxQuantity: 60,
      defaultQuantity: 5,
      isIncludedInStandard: true,
    ),
    CustomPlanOption(
      id: 4,
      name: 'Influencer Collaborations',
      code: 'OPT_INFLUENCER',
      description: 'Micro/Macro creator partnership execution & shoutouts',
      category: 'CONTENT',
      monthlyPrice: 2500,
      pricingType: 'PER_UNIT',
      unitName: 'Promotion',
      minQuantity: 0,
      maxQuantity: 20,
      defaultQuantity: 1,
    ),
    CustomPlanOption(
      id: 5,
      name: 'Product Reels',
      code: 'OPT_PRODUCT_REELS',
      description: 'High definition studio shoot product reels',
      category: 'CONTENT',
      monthlyPrice: 2000,
      pricingType: 'PER_UNIT',
      unitName: 'Reel',
      minQuantity: 0,
      maxQuantity: 30,
      defaultQuantity: 2,
    ),
    CustomPlanOption(
      id: 6,
      name: 'Meta Ads Setup & Optimization',
      code: 'OPT_META_ADS',
      description:
          'Targeted Facebook & Instagram Ads management (Client pays ad spend)',
      category: 'ADS',
      monthlyPrice: 3500,
      pricingType: 'FLAT',
      unitName: 'Campaign',
      minQuantity: 0,
      maxQuantity: 1,
      defaultQuantity: 1,
    ),
    CustomPlanOption(
      id: 7,
      name: 'Google Search & Display Ads',
      code: 'OPT_GOOGLE_ADS',
      description: 'High-intent Google Ads management & keyword bidding',
      category: 'ADS',
      monthlyPrice: 3500,
      pricingType: 'FLAT',
      unitName: 'Campaign',
      minQuantity: 0,
      maxQuantity: 1,
      defaultQuantity: 1,
    ),
    CustomPlanOption(
      id: 8,
      name: 'Dedicated Account Manager',
      code: 'OPT_MANAGER',
      description: 'Single point of contact with weekly strategy calls',
      category: 'SUPPORT',
      monthlyPrice: 4000,
      pricingType: 'FLAT',
      unitName: 'Manager',
      minQuantity: 0,
      maxQuantity: 1,
      defaultQuantity: 1,
    ),
    CustomPlanOption(
      id: 9,
      name: 'Content Writing & Captions',
      code: 'OPT_CONTENT_WRITING',
      description: 'Custom captions, hashtags, and copywriting strategy',
      category: 'SUPPORT',
      monthlyPrice: 1500,
      pricingType: 'FLAT',
      unitName: 'Package',
      minQuantity: 0,
      maxQuantity: 1,
      defaultQuantity: 1,
    ),
    CustomPlanOption(
      id: 10,
      name: 'Monthly Analytics Report',
      code: 'OPT_ANALYTICS_REPORT',
      description: 'Detailed monthly performance and engagement report',
      category: 'SUPPORT',
      monthlyPrice: 1000,
      pricingType: 'FLAT',
      unitName: 'Report',
      minQuantity: 0,
      maxQuantity: 1,
      defaultQuantity: 1,
    ),
  ];

  /// Fetch all active configurable services from backend DB
  Future<List<CustomPlanOption>> getOptions() async {
    if (_apiClient == null) return defaultOptions;

    try {
      final response = await _apiClient.get(AppUrl.customPlanServices);
      final rawData = response.data;
      final List<dynamic> list = rawData is List
          ? rawData
          : (rawData is Map && rawData['data'] is List ? rawData['data'] : []);

      if (list.isNotEmpty) {
        return list
            .map(
              (item) =>
                  CustomPlanOption.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
    } catch (e) {
      debugPrint(
        '[CUSTOM_PLAN_SERVICE] Fetch services error: $e. Using fallbacks.',
      );
    }

    return defaultOptions;
  }

  /// Calculate backend-driven price breakdown and quote
  Future<CustomPlanPricePreview> previewPrice({
    required List<Map<String, dynamic>> featureSelections,
    required int duration,
  }) async {
    if (_apiClient != null) {
      try {
        final response = await _apiClient.post(
          AppUrl.customPlanQuote,
          data: {'featureSelections': featureSelections, 'duration': duration},
        );

        final raw = response.data;
        final map = raw is Map<String, dynamic>
            ? (raw['data'] is Map ? raw['data'] as Map<String, dynamic> : raw)
            : <String, dynamic>{};

        if (map.isNotEmpty) {
          return CustomPlanPricePreview.fromJson(map);
        }
      } catch (e) {
        debugPrint('[CUSTOM_PLAN_SERVICE] Preview price error: $e');
      }
    }

    // Fallback local arithmetic if offline
    double subtotal = 0;
    for (final sel in featureSelections) {
      final optId = sel['optionId'] as int?;
      final qty = (sel['quantity'] as num?)?.toInt() ?? 1;
      final opt = defaultOptions.where((o) => o.id == optId).firstOrNull;
      if (opt != null) {
        if (opt.pricingType == 'PER_UNIT') {
          subtotal += opt.monthlyPrice * qty * duration;
        } else {
          subtotal += opt.monthlyPrice * duration;
        }
      }
    }

    final discountPercentage = duration >= 12
        ? 20.0
        : (duration >= 6 ? 10.0 : (duration >= 3 ? 5.0 : 0.0));
    final discount = subtotal * (discountPercentage / 100.0);
    final taxable = subtotal - discount;
    final tax = taxable * 0.18;
    final total = taxable + tax;

    return CustomPlanPricePreview(
      items: const [],
      duration: duration,
      durationUnit: 'MONTH',
      monthlySubtotal: duration > 0 ? subtotal / duration : subtotal,
      subtotal: subtotal,
      discount: discount,
      discountPercentage: discountPercentage,
      taxableAmount: taxable,
      tax: tax,
      totalAmount: total,
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  /// TransformInterceptor wraps `{ quoteId, order }` as `{ data: { quoteId, order } }`.
  Map<String, dynamic> _unwrapCustomPlanOrderPayload(dynamic raw) {
    final root = _asMap(raw);
    if (root['order'] is Map) {
      return root;
    }
    final nested = _asMap(root['data']);
    if (nested['order'] is Map || nested['quoteId'] != null) {
      return nested;
    }
    return root;
  }

  bool _isUsableId(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    return trimmed.isNotEmpty && trimmed != 'null' && trimmed != 'undefined';
  }

  /// Create custom plan order on backend & prepare Razorpay checkout
  Future<Map<String, dynamic>> createCustomPlan({
    required List<Map<String, dynamic>> featureSelections,
    required int duration,
    String paymentMethod = 'RAZORPAY',
  }) async {
    if (_apiClient != null) {
      final response = await _apiClient.post(
        AppUrl.customPlanCreateOrder,
        data: {
          'featureSelections': featureSelections,
          'duration': duration,
          'paymentMethod': paymentMethod,
        },
      );
      return _unwrapCustomPlanOrderPayload(response.data);
    }

    final preview = await previewPrice(
      featureSelections: featureSelections,
      duration: duration,
    );
    return {
      'success': true,
      'quoteId': DateTime.now().millisecondsSinceEpoch.toString(),
      'order': {
        'id': DateTime.now().millisecondsSinceEpoch,
        'orderNumber': 'ORD-CP-${DateTime.now().millisecondsSinceEpoch}',
        'totalAmount': preview.totalAmount,
        'status': 'PENDING_PAYMENT',
      },
    };
  }

  /// Verify Razorpay payment and activate custom plan subscription
  Future<Map<String, dynamic>> verifyPayment({
    required int customPlanOrderId,
    required String paymentId,
    String? razorpayOrderId,
    String? signature,
  }) async {
    if (customPlanOrderId <= 0) {
      throw Exception(
        'Invalid Custom Plan order ID. Unable to verify payment.',
      );
    }

    if (_apiClient != null) {
      final data = <String, dynamic>{
        'orderId': customPlanOrderId.toString(),
        'customPlanOrderId': customPlanOrderId,
        'quoteId': customPlanOrderId.toString(),
        'paymentId': paymentId,
        'razorpay_payment_id': paymentId,
      };
      if (_isUsableId(razorpayOrderId)) {
        data['razorpay_order_id'] = razorpayOrderId;
      }
      if (_isUsableId(signature)) {
        data['signature'] = signature;
        data['razorpay_signature'] = signature;
      }

      final response = await _apiClient.post(
        AppUrl.customPlanVerify,
        data: data,
      );
      return _asMap(response.data);
    }

    return {'success': true, 'message': 'Custom plan activated successfully.'};
  }

  /// Fetch past custom plan orders
  Future<List<CustomPlanOrder>> getCustomerCustomPlans() async {
    if (_apiClient != null) {
      try {
        final response = await _apiClient.get(AppUrl.customPlanHistory);
        final rawData = response.data;
        final List<dynamic> list = rawData is List
            ? rawData
            : (rawData is Map && rawData['data'] is List
                  ? rawData['data']
                  : []);

        return list
            .map(
              (item) =>
                  CustomPlanOrder.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      } catch (e) {
        debugPrint('[CUSTOM_PLAN_SERVICE] Get history error: $e');
      }
    }

    return [];
  }
}
