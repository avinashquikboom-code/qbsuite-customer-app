import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/services/razorpay_checkout_service.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_plan_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_invoice_model.dart';
import 'package:quickboom_crm_customer/roles/customer/services/customer_subscription_service.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/current_customer_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_marketing_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_profile_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_notification_viewmodel.dart';

/// Centrally invalidate all customer subscription, profile, calendar, order, and invoice providers
Future<void> refreshAllCustomerSubscriptionData(
  dynamic ref, {
  bool resetSelectedDate = true,
}) async {
  try {
    debugPrint('[CACHE] Fetching latest customer data');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final monthStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}';
    final startDate = today.subtract(const Duration(days: 3));
    final startDateStr =
        '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

    ref.invalidate(currentSubscriptionProvider);
    ref.invalidate(customerUpcomingPlanProvider);
    ref.invalidate(customerEffectivePlanProvider);
    ref.invalidate(currentCustomerSubscriptionProvider);
    ref.invalidate(customerRenewalStatusProvider);
    ref.invalidate(customerProfileProvider);
    ref.invalidate(currentCustomerStateProvider);
    if (resetSelectedDate) {
      ref.invalidate(customerCalendarSelectedDateProvider);
    }
    ref.invalidate(customerCalendarActivitiesForDateProvider(dateStr));
    ref.invalidate(
      customerCalendarActivitiesFor7DayWindowProvider(startDateStr),
    );
    ref.invalidate(customerCalendarActivitiesForMonthProvider(monthStr));
    ref.invalidate(customerCalendarPlanSummaryProvider(monthStr));
    ref.invalidate(customerCalendarScheduledDatesForMonthProvider(monthStr));
    ref.invalidate(customerCalendarActivitiesProvider);
    ref.invalidate(plansProvider);
    ref.invalidate(customerInvoicesProvider);
    ref.invalidate(customerOrdersProvider);
    ref.invalidate(customerHomeBannersProvider);
    ref.invalidate(employeeNotificationProvider);
    ref.invalidate(paymentMethodsConfigProvider);
  } catch (e) {
    debugPrint('[CustomerSubscription] Error during data refresh: $e');
  }
}

/// Target refresh only for customer plans and active subscription to avoid 20-provider network storms
Future<void> refreshCustomerPlansData(dynamic ref) async {
  try {
    ref.invalidate(plansProvider);
    ref.invalidate(currentSubscriptionProvider);
    ref.invalidate(customerUpcomingPlanProvider);
    ref.invalidate(customerEffectivePlanProvider);
    ref.invalidate(customerRenewalStatusProvider);
  } catch (e) {
    debugPrint('[CustomerSubscription] Error during plans data refresh: $e');
  }
}

/// Payment Methods Config Provider: Single source of truth from backend database API
final paymentMethodsConfigProvider =
    AsyncNotifierProvider<PaymentMethodsConfigNotifier, PaymentMethodsConfig>(
      PaymentMethodsConfigNotifier.new,
    );

class PaymentMethodsConfigNotifier extends AsyncNotifier<PaymentMethodsConfig> {
  @override
  Future<PaymentMethodsConfig> build() async {
    final service = ref.watch(customerSubscriptionServiceProvider);
    final raw = await service.getPaymentConfig();
    return PaymentMethodsConfig.fromJson(raw);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(customerSubscriptionServiceProvider);
      final raw = await service.getPaymentConfig();
      return PaymentMethodsConfig.fromJson(raw);
    });
  }
}

/// Billing Cycle Provider: Defaults to YEARLY
class SelectedBillingCycleNotifier extends Notifier<SubscriptionBillingCycle> {
  @override
  SubscriptionBillingCycle build() => SubscriptionBillingCycle.monthly;

  void select(SubscriptionBillingCycle cycle) => state = cycle;
}

final selectedBillingCycleProvider =
    NotifierProvider<SelectedBillingCycleNotifier, SubscriptionBillingCycle>(
      SelectedBillingCycleNotifier.new,
    );

/// Visually Selected Plan Code (Defaults to STANDARD)
class SelectedPlanCodeNotifier extends Notifier<String> {
  @override
  String build() => 'STANDARD';

  void select(String code) => state = code;
}

final selectedPlanCodeProvider =
    NotifierProvider<SelectedPlanCodeNotifier, String>(
      SelectedPlanCodeNotifier.new,
    );

/// Idempotency & double-tap lock for checkout
class CheckoutProcessingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setProcessing(bool val) => state = val;
}

final checkoutProcessingProvider =
    NotifierProvider<CheckoutProcessingNotifier, bool>(
      CheckoutProcessingNotifier.new,
    );

/// Available Plans State from Backend Database API
final plansProvider =
    AsyncNotifierProvider<PlansNotifier, List<SubscriptionPlan>>(
      PlansNotifier.new,
    );

class PlansNotifier extends AsyncNotifier<List<SubscriptionPlan>> {
  @override
  Future<List<SubscriptionPlan>> build() async {
    final service = ref.watch(customerSubscriptionServiceProvider);

    // Instant display: Return cached plans or default plans immediately so the user
    // never encounters a blank loading screen or spinning indicator on opening Plans.
    final fastPlans = await service.getCachedPlansFast();
    if (fastPlans.isNotEmpty) {
      // Refresh with live API data in background and update state when ready
      Future.microtask(() => _fetchFreshPlans(service));
      return fastPlans;
    }

    return service.getPlans();
  }

  Future<void> _fetchFreshPlans(CustomerSubscriptionService service) async {
    try {
      final fresh = await service.getPlans();
      if (state.hasValue) {
        state = AsyncValue.data(fresh);
      }
    } catch (_) {}
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(customerSubscriptionServiceProvider);
      return service.getPlans();
    });
  }
}

/// Current Active Subscription State
final currentSubscriptionProvider =
    AsyncNotifierProvider<CurrentSubscriptionNotifier, CustomerSubscription?>(
      CurrentSubscriptionNotifier.new,
    );

class CurrentSubscriptionNotifier extends AsyncNotifier<CustomerSubscription?> {
  @override
  Future<CustomerSubscription?> build() async {
    final customerId = await ref.watch(currentCustomerIdProvider.future);
    final service = ref.watch(customerSubscriptionServiceProvider);
    debugPrint('[CACHE] Fetching latest subscription');
    debugPrint('[Riverpod] customerId: ${customerId.isEmpty ? "NONE" : customerId}');
    return service.getCurrentSubscription();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(customerSubscriptionServiceProvider);
      return service.getCurrentSubscription();
    });
  }

  void updateSubscription(CustomerSubscription newSub) {
    state = AsyncValue.data(newSub);
  }
}

/// Customer Orders & Billing History State
final customerOrdersProvider =
    AsyncNotifierProvider<CustomerOrdersNotifier, List<CustomerOrder>>(
      CustomerOrdersNotifier.new,
    );

class CustomerOrdersNotifier extends AsyncNotifier<List<CustomerOrder>> {
  @override
  Future<List<CustomerOrder>> build() async {
    final service = ref.watch(customerSubscriptionServiceProvider);
    return service.getOrders();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(customerSubscriptionServiceProvider);
      return service.getOrders();
    });
  }

  /// Complete Razorpay Purchase Flow:
  /// 1. POST /payments/razorpay/order (returns orderId & razorpayKeyId)
  /// 2. POST /payments/razorpay/verify (validates signature, activates subscription, provisions entitlements, generates schedules)
  Future<CustomerOrder?> purchasePlanWithRazorpay({
    required SubscriptionPlan plan,
    required SubscriptionBillingCycle billingCycle,
    String paymentOption = 'FULL',
    String? testPaymentId,
    String? couponCode,
  }) async {
    final isProcessing = ref.read(checkoutProcessingProvider);
    if (isProcessing) return null; // Idempotency protection

    ref.read(checkoutProcessingProvider.notifier).setProcessing(true);
    try {
      final service = ref.read(customerSubscriptionServiceProvider);
      final razorpayCheckout = ref.read(razorpayCheckoutServiceProvider);

      final selectedActivation = ref.read(customerCalendarSelectedDateProvider);
      final activationDate = DateTime(
        selectedActivation.year,
        selectedActivation.month,
        selectedActivation.day,
      );

      // 1. Create Razorpay order on backend
      final orderRes = await service.createRazorpayOrder(
        plan: plan,
        billingCycle: billingCycle,
        paymentOption: paymentOption,
        activationDate: activationDate,
        couponCode: couponCode,
      );

      final razorpayOrderId = orderRes['orderId']?.toString();
      if (razorpayOrderId == null || razorpayOrderId.isEmpty) {
        final serverErr =
            orderRes['message']?.toString() ??
            orderRes['error']?.toString() ??
            'Payment order could not be generated by server. Please check gateway configuration.';
        throw Exception(serverErr);
      }

      final keyId = orderRes['razorpayKeyId']?.toString().trim();
      if (keyId == null || keyId.isEmpty) {
        throw Exception(
          'Payment gateway credentials are not configured on server. Please contact support.',
        );
      }

      final amountInPaise =
          (orderRes['amount'] as num?)?.toInt() ??
          (plan.priceFor(billingCycle) * 1.18 * 100).round();
      final customerData = orderRes['customer'] as Map?;
      final customerEmail = customerData?['email']?.toString();
      final customerPhone = customerData?['phone']?.toString();
      final businessName =
          customerData?['name']?.toString() ?? 'QB Suite Marketing';

      String paymentId;
      String signature;

      if (testPaymentId != null) {
        // Direct test invocation
        paymentId = testPaymentId;
        signature = 'test_signature_mock';
      } else {
        // 2. Open Native Razorpay Checkout
        final checkoutResult = await razorpayCheckout.openCheckout(
          keyId: keyId,
          orderId: razorpayOrderId,
          amountInPaise: amountInPaise,
          planName: plan.name,
          businessName: businessName,
          customerEmail: customerEmail,
          customerPhone: customerPhone,
        );

        if (!checkoutResult.isSuccess) {
          throw Exception(
            checkoutResult.errorMessage ?? 'Payment was cancelled or failed.',
          );
        }

        paymentId = checkoutResult.paymentId!;
        signature = checkoutResult.signature!;
      }

      // 3. Server-side Verification & Activation
      final verifyRes = await service.verifyRazorpayPayment(
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
        planId: plan.id,
        billingCycle: billingCycle,
        paymentOption: paymentOption,
        activationDate: activationDate,
        couponCode: couponCode,
      );

      CustomerOrder? newOrder = verifyRes['order'] as CustomerOrder?;
      final CustomerSubscription? newSub =
          verifyRes['subscription'] as CustomerSubscription?;

      if (newOrder == null) {
        final basePrice = plan.priceFor(billingCycle);
        final gstTax = basePrice * 0.18;
        newOrder = CustomerOrder(
          id: newSub?.id ?? 'ord_${DateTime.now().millisecondsSinceEpoch}',
          orderNumber: '#QB-${DateTime.now().millisecondsSinceEpoch}',
          planId: plan.id,
          planName: plan.name,
          billingCycle: billingCycle,
          amount: basePrice,
          taxAmount: gstTax,
          totalAmount: basePrice + gstTax,
          paymentStatus: paymentOption.toUpperCase() == 'ADVANCE'
              ? 'PARTIALLY_PAID'
              : 'PAID',
          paymentMethod: 'RAZORPAY',
          transactionId: paymentId,
          purchaseDate: DateTime.now(),
          activationDate: newSub?.startDate ?? activationDate,
          expiryDate: newSub?.endDate ?? newSub?.expiryDate ?? activationDate,
          features: plan.features,
        );
      }

      if (newSub != null) {
        ref
            .read(currentSubscriptionProvider.notifier)
            .updateSubscription(newSub);
      }

      // Invalidate and refresh all providers to force reload real backend data everywhere
      await refreshAllCustomerSubscriptionData(ref);

      // Verify active subscription from backend (poll briefly if needed)
      var activeSub = await service.getCurrentSubscription();
      int attempts = 0;
      while ((activeSub == null || !activeSub.isPurchasedPlanVisible) &&
          attempts < 3) {
        await Future.delayed(const Duration(milliseconds: 500));
        activeSub = await service.getCurrentSubscription();
        attempts++;
      }
      if (activeSub != null) {
        ref
            .read(currentSubscriptionProvider.notifier)
            .updateSubscription(activeSub);
      }

      return newOrder;
    } catch (e) {
      debugPrint(
        '[CustomerOrdersNotifier] Error purchasing plan with Razorpay: $e',
      );
      rethrow;
    } finally {
      ref.read(checkoutProcessingProvider.notifier).setProcessing(false);
    }
  }

  /// Offline payment request (Bank Transfer / Cash)
  Future<Map<String, dynamic>> purchasePlanOffline({
    required SubscriptionPlan plan,
    required SubscriptionBillingCycle billingCycle,
    String paymentOption = 'FULL',
    String? referenceNumber,
    String? notes,
    String? couponCode,
  }) async {
    final isProcessing = ref.read(checkoutProcessingProvider);
    if (isProcessing) return {'success': false};

    ref.read(checkoutProcessingProvider.notifier).setProcessing(true);
    try {
      final selectedActivation = ref.read(customerCalendarSelectedDateProvider);
      final activationDate = DateTime(
        selectedActivation.year,
        selectedActivation.month,
        selectedActivation.day,
      );
      final service = ref.read(customerSubscriptionServiceProvider);
      final res = await service.createOfflinePaymentOrder(
        plan: plan,
        billingCycle: billingCycle,
        paymentOption: paymentOption,
        referenceNumber: referenceNumber,
        notes: notes,
        activationDate: activationDate,
        couponCode: couponCode,
      );

      final dynamic subIdRaw = res['subscriptionId'] ?? res['id'];
      if (subIdRaw != null) {
        final pendingSub = CustomerSubscription(
          id: subIdRaw.toString(),
          customerId: service.customerId ?? '',
          planId: plan.id,
          planName: plan.name,
          planCode: plan.code,
          status: SubscriptionStatus.pending,
          billingCycle: billingCycle,
          startDate: activationDate,
          endDate: activationDate.add(
            Duration(
              days: billingCycle == SubscriptionBillingCycle.yearly ? 365 : 30,
            ),
          ),
          purchaseDate: DateTime.now(),
          expiryDate: activationDate.add(
            Duration(
              days: billingCycle == SubscriptionBillingCycle.yearly ? 365 : 30,
            ),
          ),
          price: plan.priceFor(billingCycle),
          purchasedPrice: plan.priceFor(billingCycle),
          features: plan.features,
          userLimit: plan.userLimit,
          leadLimit: plan.leadLimit,
        );
        ref
            .read(currentSubscriptionProvider.notifier)
            .updateSubscription(pendingSub);
      }

      // Invalidate and refresh all providers to force reload real backend data everywhere
      await refreshAllCustomerSubscriptionData(ref);

      return res;
    } catch (e) {
      debugPrint(
        '[CustomerOrdersNotifier] Error submitting offline payment: $e',
      );
      rethrow;
    } finally {
      ref.read(checkoutProcessingProvider.notifier).setProcessing(false);
    }
  }

  /// Renew subscription
  Future<CustomerOrder?> renewCurrentPlan({
    required CustomerSubscription currentSub,
    required SubscriptionPlan plan,
    SubscriptionBillingCycle? cycle,
  }) async {
    final billingCycle = cycle ?? currentSub.billingCycle;
    return purchasePlanWithRazorpay(plan: plan, billingCycle: billingCycle);
  }
}

/// Customer Invoices State
final customerInvoicesProvider =
    AsyncNotifierProvider<CustomerInvoicesNotifier, List<CustomerInvoice>>(
      CustomerInvoicesNotifier.new,
    );

class CustomerInvoicesNotifier extends AsyncNotifier<List<CustomerInvoice>> {
  @override
  Future<List<CustomerInvoice>> build() async {
    final service = ref.watch(customerSubscriptionServiceProvider);
    return service.getInvoices();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(customerSubscriptionServiceProvider);
      return service.getInvoices();
    });
  }
}

/// Structured Current Customer Subscription Provider (GET /subscriptions/current)
final currentCustomerSubscriptionProvider =
    FutureProvider.autoDispose<CurrentSubscription>((ref) async {
      final service = ref.watch(customerSubscriptionServiceProvider);
      return service.getCurrentSubscriptionDetails();
    });

/// Installment Renewal & Buffer Period Status Provider (GET /subscriptions/renewal-status)
final customerRenewalStatusProvider =
    FutureProvider.autoDispose<RenewalStatus?>((ref) async {
      final service = ref.watch(customerSubscriptionServiceProvider);
      return service.getRenewalStatus();
    });

/// Upcoming Subscription Plan Provider (startDate > now)
final customerUpcomingPlanProvider = FutureProvider.autoDispose<UpcomingPlan?>((
  ref,
) async {
  final service = ref.watch(customerSubscriptionServiceProvider);
  return service.getUpcomingPlan();
});
