import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/services/razorpay_checkout_service.dart';
import 'package:quickboom_crm_customer/roles/customer/models/custom_plan_model.dart';
import 'package:quickboom_crm_customer/roles/customer/services/custom_plan_service.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_subscription_viewmodel.dart';

/// Available Options Provider
final customPlanOptionsProvider = FutureProvider<List<CustomPlanOption>>((
  ref,
) async {
  final service = ref.watch(customPlanServiceProvider);
  return service.getOptions();
});

/// Custom Plan History Provider
final customerCustomPlansHistoryProvider =
    FutureProvider<List<CustomPlanOrder>>((ref) async {
      final service = ref.watch(customPlanServiceProvider);
      return service.getCustomerCustomPlans();
    });

class CustomPlanBuilderState {
  final Map<int, int> selectedQuantities; // optionId -> quantity
  final int selectedDuration; // 1, 3, 6, 12
  final AsyncValue<CustomPlanPricePreview?> previewAsync;
  final bool isSubmitting;
  final String? errorMessage;

  const CustomPlanBuilderState({
    this.selectedQuantities = const {},
    this.selectedDuration = 1,
    this.previewAsync = const AsyncValue.data(null),
    this.isSubmitting = false,
    this.errorMessage,
  });

  CustomPlanBuilderState copyWith({
    Map<int, int>? selectedQuantities,
    int? selectedDuration,
    AsyncValue<CustomPlanPricePreview?>? previewAsync,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return CustomPlanBuilderState(
      selectedQuantities: selectedQuantities ?? this.selectedQuantities,
      selectedDuration: selectedDuration ?? this.selectedDuration,
      previewAsync: previewAsync ?? this.previewAsync,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }

  double get calculatedSubtotal {
    return previewAsync.asData?.value?.subtotal ?? 0;
  }

  double get calculatedTotal {
    return previewAsync.asData?.value?.totalAmount ?? 0;
  }

  bool isSelected(int optionId) => (selectedQuantities[optionId] ?? 0) > 0;
  int getQuantity(int optionId) => selectedQuantities[optionId] ?? 0;
}

final customPlanBuilderViewModelProvider =
    NotifierProvider<CustomPlanBuilderNotifier, CustomPlanBuilderState>(
      CustomPlanBuilderNotifier.new,
    );

class CustomPlanBuilderNotifier extends Notifier<CustomPlanBuilderState> {
  Timer? _debounceTimer;

  @override
  CustomPlanBuilderState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return const CustomPlanBuilderState();
  }

  /// Initialize default quantities based on available options
  void initializeDefaults(List<CustomPlanOption> options) {
    if (state.selectedQuantities.isNotEmpty) return;

    final initialMap = <int, int>{};
    for (final opt in options) {
      if (opt.isIncludedInStandard && opt.defaultQuantity > 0) {
        initialMap[opt.id] = opt.defaultQuantity;
      }
    }
    state = state.copyWith(selectedQuantities: initialMap);
    _triggerRecalculate();
  }

  void toggleOption(CustomPlanOption option) {
    final current = Map<int, int>.from(state.selectedQuantities);
    if (current.containsKey(option.id)) {
      current.remove(option.id);
    } else {
      current[option.id] = option.defaultQuantity > 0
          ? option.defaultQuantity
          : (option.minQuantity > 0 ? option.minQuantity : 1);
    }
    state = state.copyWith(selectedQuantities: current);
    _triggerRecalculate();
  }

  void setQuantity(CustomPlanOption option, int quantity) {
    final current = Map<int, int>.from(state.selectedQuantities);
    if (quantity <= 0) {
      current.remove(option.id);
    } else {
      int safeQty = quantity;
      if (option.minQuantity > 0 && safeQty < option.minQuantity) {
        safeQty = option.minQuantity;
      }
      if (option.maxQuantity > 0 && safeQty > option.maxQuantity) {
        safeQty = option.maxQuantity;
      }
      current[option.id] = safeQty;
    }
    state = state.copyWith(selectedQuantities: current);
    _triggerRecalculate();
  }

  void increment(CustomPlanOption option) {
    final currentQty = state.selectedQuantities[option.id] ?? 0;
    final newQty = currentQty == 0
        ? (option.minQuantity > 0 ? option.minQuantity : 1)
        : currentQty + 1;
    setQuantity(option, newQty);
  }

  void decrement(CustomPlanOption option) {
    final currentQty = state.selectedQuantities[option.id] ?? 0;
    if (currentQty <= 1) {
      setQuantity(option, 0);
    } else {
      setQuantity(option, currentQty - 1);
    }
  }

  void selectDuration(int months) {
    if (state.selectedDuration == months) return;
    state = state.copyWith(selectedDuration: months);
    _triggerRecalculate();
  }

  void setDuration(int months) => selectDuration(months);

  void _triggerRecalculate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _recalculatePrice();
    });
  }

  Future<void> _recalculatePrice() async {
    if (state.selectedQuantities.isEmpty) {
      state = state.copyWith(previewAsync: const AsyncValue.data(null));
      return;
    }

    state = state.copyWith(previewAsync: const AsyncValue.loading());

    try {
      final service = ref.read(customPlanServiceProvider);
      final selections = state.selectedQuantities.entries.map((e) {
        return {'optionId': e.key, 'quantity': e.value};
      }).toList();

      final preview = await service.previewPrice(
        featureSelections: selections,
        duration: state.selectedDuration,
      );

      state = state.copyWith(previewAsync: AsyncValue.data(preview));
    } catch (e, st) {
      state = state.copyWith(previewAsync: AsyncValue.error(e, st));
    }
  }

  /// Complete checkout flow with Razorpay
  Future<bool> processCheckoutAndPayment() async {
    if (state.selectedQuantities.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please select at least one feature',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final service = ref.read(customPlanServiceProvider);
      final selections = state.selectedQuantities.entries.map((e) {
        return {'optionId': e.key, 'quantity': e.value};
      }).toList();

      // 1. Create custom plan order
      final orderRes = await service.createCustomPlan(
        featureSelections: selections,
        duration: state.selectedDuration,
      );

      final payload = _asStringKeyedMap(orderRes);
      final nestedData = _asStringKeyedMap(payload['data']);
      final orderData = _asStringKeyedMap(
        payload['order'] ??
            nestedData['order'] ??
            (payload['id'] != null ? payload : nestedData),
      );

      final customPlanOrderId = _parsePositiveIntId(
        orderData['id'] ?? payload['quoteId'] ?? nestedData['quoteId'],
      );
      if (customPlanOrderId == null) {
        throw Exception(
          'Invalid Custom Plan order ID. Unable to verify payment.',
        );
      }

      // 2. Open Razorpay checkout if configured
      final gatewayConfig = _asStringKeyedMap(
        orderData['paymentGatewayConfig'],
      );
      String paymentId = 'pay_CP_${DateTime.now().millisecondsSinceEpoch}';
      String? razorpayOrderId = _usableString(gatewayConfig['orderId']);
      String? signature;

      final keyId = _usableString(gatewayConfig['keyId']);
      if (keyId != null) {
        if (razorpayOrderId == null) {
          throw Exception(
            'Invalid Custom Plan payment order. Unable to start checkout.',
          );
        }

        final rzpService = ref.read(razorpayCheckoutServiceProvider);
        final checkoutResult = await rzpService.openCheckout(
          keyId: keyId,
          orderId: razorpayOrderId,
          amountInPaise:
              (gatewayConfig['amountInPaise'] as num?)?.toInt() ??
              (((orderData['totalAmount'] as num?)?.toDouble() ??
                          (gatewayConfig['amount'] as num?)?.toDouble() ??
                          0.0) *
                      100)
                  .round(),
          planName: 'Custom Marketing Plan (${state.selectedDuration} Mo)',
          businessName: 'QB Suite Marketing',
          customerEmail:
              _usableString(gatewayConfig['customerEmail']) ??
              'customer@quikboom.com',
          customerPhone: '9876543210',
        );

        if (!checkoutResult.isSuccess) {
          state = state.copyWith(
            isSubmitting: false,
            errorMessage:
                checkoutResult.errorMessage ?? 'Payment cancelled or failed',
          );
          return false;
        }

        paymentId = checkoutResult.paymentId ?? paymentId;
        razorpayOrderId =
            _usableString(checkoutResult.orderId) ?? razorpayOrderId;
        signature = _usableString(checkoutResult.signature);
      }

      // 3. Verify server-side & activate custom plan
      await service.verifyPayment(
        customPlanOrderId: customPlanOrderId,
        paymentId: paymentId,
        razorpayOrderId: razorpayOrderId,
        signature: signature,
      );

      // 4. Refresh subscription, calendar, invoice, and custom-plan history
      await refreshAllCustomerSubscriptionData(ref);
      ref.invalidate(customerCustomPlansHistoryProvider);

      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      String cleanMessage =
          'Failed to process custom plan order. Please try again.';
      if (e is DioException) {
        if (e.response?.statusCode == 503) {
          cleanMessage =
              'Custom Plan Service is temporarily undergoing maintenance. Please try again in a few moments.';
        } else if (e.response?.statusCode == 400) {
          final data = e.response?.data;
          cleanMessage = (data is Map && data['message'] != null)
              ? (data['message'] is List
                    ? data['message'][0]
                    : data['message'].toString())
              : 'Invalid custom plan configuration.';
        } else if (e.response?.statusCode == 401) {
          cleanMessage =
              'Please sign in to configure and purchase a custom plan.';
        } else if (e.response?.statusCode == 404) {
          cleanMessage = 'Selected service option is no longer available.';
        } else {
          cleanMessage = e.message ?? cleanMessage;
        }
      } else {
        cleanMessage = e.toString().replaceAll('Exception:', '').trim();
      }

      state = state.copyWith(isSubmitting: false, errorMessage: cleanMessage);
      return false;
    }
  }
}

Map<String, dynamic> _asStringKeyedMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

int? _parsePositiveIntId(dynamic value) {
  if (value == null) return null;
  if (value is int) return value > 0 ? value : null;
  if (value is num) {
    final asInt = value.toInt();
    if (asInt == value && asInt > 0) return asInt;
    return null;
  }
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null' || text == 'undefined') return null;
  return int.tryParse(text);
}

String? _usableString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null' || text == 'undefined') return null;
  return text;
}
