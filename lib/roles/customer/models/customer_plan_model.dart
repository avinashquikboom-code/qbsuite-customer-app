import 'package:flutter/foundation.dart';
import '../services/customer_subscription_service.dart';

enum SubscriptionBillingCycle {
  monthly,
  yearly;

  String get label =>
      this == SubscriptionBillingCycle.monthly ? 'Monthly' : 'Yearly';
  String get priceSuffix =>
      this == SubscriptionBillingCycle.monthly ? '/ month' : '/ year';
  String get code =>
      this == SubscriptionBillingCycle.monthly ? 'MONTHLY' : 'YEARLY';

  static SubscriptionBillingCycle fromString(String? value) {
    if (value == null) return SubscriptionBillingCycle.monthly;
    final upper = value.toUpperCase();
    if (upper == 'YEARLY' || upper == 'ANNUAL') {
      return SubscriptionBillingCycle.yearly;
    }
    return SubscriptionBillingCycle.monthly;
  }
}

enum SubscriptionStatus {
  active,
  upcoming,
  expired,
  cancelled,
  pending,
  trial;

  String get label {
    switch (this) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.upcoming:
        return 'Upcoming';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
      case SubscriptionStatus.pending:
        return 'Pending';
      case SubscriptionStatus.trial:
        return 'Trial';
    }
  }

  static SubscriptionStatus fromString(String? value) {
    if (value == null) return SubscriptionStatus.pending;
    switch (value.toUpperCase()) {
      case 'ACTIVE':
      case 'FULLY_PAID':
        return SubscriptionStatus.active;
      case 'UPCOMING':
        return SubscriptionStatus.upcoming;
      case 'EXPIRED':
      case 'PAST_DUE':
        return SubscriptionStatus.expired;
      case 'CANCELLED':
      case 'CANCELED':
        return SubscriptionStatus.cancelled;
      case 'TRIAL':
        return SubscriptionStatus.trial;
      default:
        return SubscriptionStatus.pending;
    }
  }
}

/// Missing status used to become EXPIRED whenever `isActive` was false.
/// A purchased plan with a future start date is sent that way and was hidden.
String _statusFromPlanJson(
  Map<String, dynamic> json,
  DateTime start,
  DateTime end,
) {
  final raw = json['status']?.toString().trim();
  if (raw != null && raw.isNotEmpty && raw.toLowerCase() != 'null') {
    return raw;
  }
  if (json['isActive'] == true) return 'ACTIVE';
  final now = DateTime.now();
  if (start.isAfter(now)) return 'UPCOMING';
  final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
  if (now.isAfter(endOfDay)) return 'EXPIRED';
  return 'ACTIVE';
}

List<String> _featureLabels(dynamic raw) {
  if (raw is List) {
    return raw.map((e) => e.toString()).toList();
  }
  if (raw is Map) {
    return raw.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .toList();
  }
  return const [];
}

@immutable
class UpcomingPlan {
  final String id;
  final String? subscriptionId;
  final String planId;
  final String planName;
  final String planCode;
  final DateTime startDate;
  final DateTime endDate;
  final SubscriptionStatus status;
  final SubscriptionBillingCycle billingCycle;
  final double price;

  const UpcomingPlan({
    required this.id,
    this.subscriptionId,
    required this.planId,
    required this.planName,
    required this.planCode,
    required this.startDate,
    required this.endDate,
    this.status = SubscriptionStatus.upcoming,
    this.billingCycle = SubscriptionBillingCycle.monthly,
    this.price = 0.0,
  });

  factory UpcomingPlan.fromJson(Map<String, dynamic> json) {
    final start =
        DateTime.tryParse(json['startDate']?.toString() ?? '') ??
        DateTime.now();
    final end =
        DateTime.tryParse(json['endDate']?.toString() ?? '') ??
        start.add(const Duration(days: 30));
    final priceVal = (json['price'] as num?)?.toDouble() ?? 0.0;

    return UpcomingPlan(
      id: json['id']?.toString() ?? json['subscriptionId']?.toString() ?? '',
      subscriptionId:
          json['subscriptionId']?.toString() ?? json['id']?.toString(),
      planId: json['planId']?.toString() ?? '',
      planName:
          json['planName']?.toString() ??
          json['name']?.toString() ??
          'Upcoming Plan',
      planCode:
          json['planCode']?.toString() ?? json['code']?.toString() ?? 'PLAN',
      startDate: start,
      endDate: end,
      status: SubscriptionStatus.fromString(
        json['status']?.toString() ?? 'UPCOMING',
      ),
      billingCycle: SubscriptionBillingCycle.fromString(
        json['billingCycle']?.toString(),
      ),
      price: priceVal,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subscriptionId': subscriptionId,
    'planId': planId,
    'planName': planName,
    'planCode': planCode,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'status': status.name.toUpperCase(),
    'billingCycle': billingCycle.code,
    'price': price,
  };
}

@immutable
class PaymentMethodsConfig {
  final bool online;
  final bool offline;
  final String paymentMode;
  final String? razorpayKeyId;
  final Map<String, dynamic>? bankDetails;

  const PaymentMethodsConfig({
    required this.online,
    required this.offline,
    this.paymentMode = 'TEST',
    this.razorpayKeyId,
    this.bankDetails,
  });

  bool get hasAnyPaymentMethod => online || offline;

  factory PaymentMethodsConfig.fromJson(Map<String, dynamic> json) {
    bool onlineVal = true;
    bool offlineVal = true;

    if (json['paymentMethods'] is Map) {
      final pm = json['paymentMethods'] as Map;
      if (pm['online'] != null) onlineVal = pm['online'] == true;
      if (pm['offline'] != null) offlineVal = pm['offline'] == true;
    } else {
      if (json['online'] != null) {
        onlineVal = json['online'] == true;
      } else if (json['razorpayEnabled'] != null) {
        onlineVal = json['razorpayEnabled'] == true;
      } else if (json['enableRazorpay'] != null) {
        onlineVal = json['enableRazorpay'] == true;
      }

      if (json['offline'] != null) {
        offlineVal = json['offline'] == true;
      } else if (json['offlinePaymentEnabled'] != null) {
        offlineVal = json['offlinePaymentEnabled'] == true;
      } else if (json['enableOfflinePayment'] != null) {
        offlineVal = json['enableOfflinePayment'] == true;
      }
    }

    Map<String, dynamic>? bankDet;
    if (json['bankDetails'] is Map) {
      bankDet = Map<String, dynamic>.from(json['bankDetails'] as Map);
    }

    return PaymentMethodsConfig(
      online: onlineVal,
      offline: offlineVal,
      paymentMode: json['paymentMode']?.toString() ?? 'TEST',
      razorpayKeyId: json['razorpayKeyId']?.toString(),
      bankDetails: bankDet,
    );
  }

  Map<String, dynamic> toJson() => {
    'online': online,
    'offline': offline,
    'paymentMethods': {
      'online': online,
      'offline': offline,
    },
    'paymentMode': paymentMode,
    'razorpayKeyId': razorpayKeyId,
    'bankDetails': bankDetails,
  };
}

@immutable
class SubscriptionPlan {
  final String id;
  final String name;
  final String? subtitle;
  final String code;
  final String description;
  final double monthlyPrice;
  final double yearlyPrice;
  final String currency;
  final List<String> features;
  final bool isRecommended;
  final bool isActive;
  final int userLimit;
  final int leadLimit;
  final int storageLimitBytes;
  final PaymentMethodsConfig? paymentMethods;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    this.subtitle,
    required this.code,
    required this.description,
    required this.monthlyPrice,
    required this.yearlyPrice,
    this.currency = 'INR',
    required this.features,
    this.isRecommended = false,
    this.isActive = true,
    this.userLimit = 5,
    this.leadLimit = 500,
    this.storageLimitBytes = 5368709120, // 5GB
    this.paymentMethods,
  });

  double priceFor(SubscriptionBillingCycle cycle) =>
      cycle == SubscriptionBillingCycle.monthly ? monthlyPrice : yearlyPrice;

  /// Dynamic Yearly Savings Formula:
  /// monthlyEquivalent = monthlyPrice * 12
  /// savingAmount = monthlyEquivalent - yearlyPrice
  /// savingPercentage = ((monthlyEquivalent - yearlyPrice) / monthlyEquivalent) * 100
  double get monthlyEquivalent => monthlyPrice * 12;

  double get yearlySavingsAmount {
    final diff = monthlyEquivalent - yearlyPrice;
    return diff > 0 ? diff : 0;
  }

  double get yearlySavingsPercentage {
    if (monthlyEquivalent <= 0) return 0;
    final pct = ((monthlyEquivalent - yearlyPrice) / monthlyEquivalent) * 100;
    return pct > 0 ? pct : 0;
  }

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    List<String> feats = [];
    if (json['features'] is List) {
      feats = (json['features'] as List).map((e) => e.toString()).toList();
    }

    final code = json['code']?.toString() ?? 'STANDARD';
    String? subtitle = json['subtitle']?.toString();
    if (subtitle == null || subtitle.isEmpty) {
      subtitle = json['description']?.toString() ?? json['name']?.toString();
    }

    final monthly = (json['monthlyPrice'] as num?)?.toDouble() ?? 0.0;
    final yearly = (json['yearlyPrice'] as num?)?.toDouble() ?? (monthly * 10);

    PaymentMethodsConfig? pmConfig;
    if (json['paymentMethods'] is Map) {
      pmConfig = PaymentMethodsConfig.fromJson(
        Map<String, dynamic>.from(json['paymentMethods'] as Map),
      );
    } else if (json['offlinePaymentEnabled'] != null || json['onlinePaymentEnabled'] != null || json['razorpayEnabled'] != null) {
      pmConfig = PaymentMethodsConfig.fromJson(json);
    }

    return SubscriptionPlan(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Plan',
      subtitle: subtitle,
      code: code,
      description: json['description']?.toString() ?? '',
      monthlyPrice: monthly,
      yearlyPrice: yearly,
      currency: json['currency']?.toString() ?? 'INR',
      features: feats,
      isRecommended: json['isRecommended'] == true || code == 'STANDARD',
      isActive: json['isActive'] != false,
      userLimit: (json['userLimit'] as num?)?.toInt() ?? 5,
      leadLimit: (json['leadLimit'] as num?)?.toInt() ?? 500,
      storageLimitBytes:
          int.tryParse(
            json['storageLimitBytes']?.toString() ??
                json['storageLimit']?.toString() ??
                '',
          ) ??
          5368709120,
      paymentMethods: pmConfig,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subtitle': subtitle,
    'code': code,
    'description': description,
    'monthlyPrice': monthlyPrice,
    'yearlyPrice': yearlyPrice,
    'currency': currency,
    'features': features,
    'isRecommended': isRecommended,
    'isActive': isActive,
    'userLimit': userLimit,
    'leadLimit': leadLimit,
    'storageLimit': storageLimitBytes,
    if (paymentMethods != null) 'paymentMethods': paymentMethods!.toJson(),
  };
}

@immutable
class CustomerSubscription {
  final String id;
  final String customerId;
  final String planId;
  final String planName;
  final String planCode;
  final String planType; // 'DEFAULT' or 'CUSTOM'
  final SubscriptionStatus status;
  final SubscriptionBillingCycle billingCycle;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime purchaseDate;
  final DateTime expiryDate;
  final double price;
  final double purchasedPrice;
  final String currency;
  final bool autoRenew;
  final List<String> features;
  final int userLimit;
  final int leadLimit;
  final String? reminder; // '10_DAYS', '5_DAYS', '1_DAY', 'EXPIRED', or null
  final String? statusMessage;
  final UpcomingPlan? upcomingPlan;
  final String? couponCode;
  final double? originalAmount;
  final double? discountAmount;
  final double? paidAmount;

  const CustomerSubscription({
    required this.id,
    required this.customerId,
    required this.planId,
    required this.planName,
    required this.planCode,
    this.planType = 'DEFAULT',
    required this.status,
    required this.billingCycle,
    required this.startDate,
    required this.endDate,
    required this.purchaseDate,
    required this.expiryDate,
    required this.price,
    required this.purchasedPrice,
    this.currency = 'INR',
    this.autoRenew = true,
    this.features = const [],
    this.userLimit = 5,
    this.leadLimit = 500,
    this.reminder,
    this.statusMessage,
    this.upcomingPlan,
    this.couponCode,
    this.originalAmount,
    this.discountAmount,
    this.paidAmount,
  });

  bool get isUpcoming => status == SubscriptionStatus.upcoming;
  bool get isPending => status == SubscriptionStatus.pending;

  bool get isExpired {
    if (status == SubscriptionStatus.expired || reminder == 'EXPIRED') {
      return true;
    }
    if (status == SubscriptionStatus.pending || status == SubscriptionStatus.upcoming) {
      return false;
    }
    final endOfDay = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
      23,
      59,
      59,
    );
    return DateTime.now().isAfter(endOfDay);
  }

  bool get isExpiringSoon =>
      !isExpired &&
      !isUpcoming &&
      !isPending &&
      (reminder == '10_DAYS' ||
          reminder == '5_DAYS' ||
          reminder == '1_DAY' ||
          daysRemaining <= 10);

  bool get isActive => status == SubscriptionStatus.active && !isExpired;

  /// Purchased plan that Plans/Calendar should display (not cancelled/expired).
  /// Upcoming means DB status is ACTIVE but startDate is still in the future.
  /// Pending means offline order or payment awaiting approval.
  bool get isPurchasedPlanVisible =>
      !isExpired &&
      (status == SubscriptionStatus.active ||
          status == SubscriptionStatus.upcoming ||
          status == SubscriptionStatus.pending ||
          status == SubscriptionStatus.trial);

  bool get isCustomPlan =>
      planType.toUpperCase() == 'CUSTOM' ||
      planCode.toUpperCase() == 'CUSTOM' ||
      planCode.toUpperCase().startsWith('CUSTOM_');

  int get daysRemaining {
    final diff = expiryDate.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  factory CustomerSubscription.fromJson(Map<String, dynamic> json) {
    final start =
        DateTime.tryParse(json['startDate']?.toString() ?? '') ??
        DateTime.tryParse(json['purchaseDate']?.toString() ?? '') ??
        DateTime.now();
    final end =
        DateTime.tryParse(json['endDate']?.toString() ?? '') ??
        DateTime.tryParse(json['expiryDate']?.toString() ?? '') ??
        start.add(const Duration(days: 30));
    double readAmount(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    final priceVal = readAmount(
      json['price'] ??
          json['purchasedPrice'] ??
          json['customPrice'] ??
          json['basePrice'],
    );

    final planName =
        json['planName']?.toString() ??
        json['name']?.toString() ??
        'Active Plan';
    final planCode =
        json['planCode']?.toString() ?? json['code']?.toString() ?? 'STARTER';
    final planId = json['planId']?.toString() ?? json['id']?.toString() ?? '';
    final subId =
        json['subscriptionId']?.toString() ?? json['id']?.toString() ?? '';

    UpcomingPlan? upPlan;
    if (json['upcomingPlan'] is Map) {
      upPlan = UpcomingPlan.fromJson(
        Map<String, dynamic>.from(json['upcomingPlan'] as Map),
      );
    }

    return CustomerSubscription(
      id: subId,
      customerId: json['customerId']?.toString() ?? '',
      planId: planId,
      planName: planName,
      planCode: planCode,
      planType:
          json['planType']?.toString() ??
          (json['isCustomized'] == true ? 'CUSTOM' : 'DEFAULT'),
      status: SubscriptionStatus.fromString(_statusFromPlanJson(json, start, end)),
      billingCycle: SubscriptionBillingCycle.fromString(
        json['billingCycle']?.toString(),
      ),
      startDate: start,
      endDate: end,
      purchaseDate: start,
      expiryDate: end,
      price: priceVal,
      purchasedPrice: priceVal,
      currency: json['currency']?.toString() ?? 'INR',
      autoRenew: json['autoRenew'] != false,
      features: _featureLabels(json['features']),
      userLimit: (json['userLimit'] as num?)?.toInt() ?? 5,
      leadLimit: (json['leadLimit'] as num?)?.toInt() ?? 500,
      reminder: json['reminder']?.toString(),
      statusMessage: json['statusMessage']?.toString(),
      upcomingPlan: upPlan,
      couponCode: json['couponCode']?.toString(),
      originalAmount: json['originalAmount'] == null
          ? null
          : double.tryParse(json['originalAmount'].toString()),
      discountAmount: json['discountAmount'] == null
          ? null
          : double.tryParse(json['discountAmount'].toString()),
      paidAmount: json['paidAmount'] == null
          ? null
          : double.tryParse(json['paidAmount'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'planId': planId,
    'planName': planName,
    'planCode': planCode,
    'planType': planType,
    'status': status.name,
    'billingCycle': billingCycle.code,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'purchaseDate': purchaseDate.toIso8601String(),
    'expiryDate': expiryDate.toIso8601String(),
    'price': price,
    'purchasedPrice': purchasedPrice,
    'currency': currency,
    'autoRenew': autoRenew,
    'features': features,
    'userLimit': userLimit,
    'leadLimit': leadLimit,
    'reminder': reminder,
    'statusMessage': statusMessage,
    'upcomingPlan': upcomingPlan?.toJson(),
  };
}

@immutable
class OrderInstallment {
  final int number;
  final String title;
  final double amount;
  final String status;
  final bool receiptAvailable;
  final String? receiptId;
  final String? receiptNumber;
  final String? downloadUrl;
  final String? lockReason;

  const OrderInstallment({
    required this.number,
    required this.title,
    required this.amount,
    required this.status,
    required this.receiptAvailable,
    this.receiptId,
    this.receiptNumber,
    this.downloadUrl,
    this.lockReason,
  });

  bool get isPaid =>
      status.toUpperCase() == 'PAID' || status.toUpperCase() == 'SUCCESS';

  factory OrderInstallment.fromJson(Map<String, dynamic> json) {
    return OrderInstallment(
      number: (json['number'] as num?)?.toInt() ?? 1,
      title: json['title']?.toString() ?? 'Installment',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'PENDING',
      receiptAvailable: json['receiptAvailable'] == true,
      receiptId: json['receiptId']?.toString(),
      receiptNumber: json['receiptNumber']?.toString(),
      downloadUrl: json['downloadUrl']?.toString(),
      lockReason: json['lockReason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'title': title,
    'amount': amount,
    'status': status,
    'receiptAvailable': receiptAvailable,
    'receiptId': receiptId,
    'receiptNumber': receiptNumber,
    'downloadUrl': downloadUrl,
    'lockReason': lockReason,
  };
}

class CustomerOrder {
  final String id;
  final String orderNumber; // e.g. #QB-MS5TTJE3TBZC
  final String planId;
  final String planName;
  final SubscriptionBillingCycle billingCycle;
  final double amount;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String currency;
  final String paymentStatus; // PAID, PENDING, PARTIALLY_PAID, FAILED
  final String paymentMethod;
  final String? transactionId;
  final DateTime purchaseDate;
  final DateTime activationDate;
  final DateTime expiryDate;
  final List<String> features;
  final String? invoiceUrl;
  final bool receiptAvailable;
  final String? receiptId;
  final String? receiptNumber;
  final String? receiptDownloadUrl;
  final String? receiptLockReason;
  final bool invoiceAvailable;
  final String? invoiceId;
  final String? invoiceNumber;
  final String? invoiceDownloadUrl;
  final String? invoiceLockReason;
  final bool hasAgreement;
  final List<OrderInstallment> installments;

  const CustomerOrder({
    required this.id,
    required this.orderNumber,
    required this.planId,
    required this.planName,
    required this.billingCycle,
    required this.amount,
    required this.taxAmount,
    required this.totalAmount,
    this.paidAmount = 0.0,
    this.remainingAmount = 0.0,
    this.currency = 'INR',
    required this.paymentStatus,
    this.paymentMethod = 'Online / Razorpay',
    this.transactionId,
    required this.purchaseDate,
    required this.activationDate,
    required this.expiryDate,
    this.features = const [],
    this.invoiceUrl,
    this.receiptAvailable = false,
    this.receiptId,
    this.receiptNumber,
    this.receiptDownloadUrl,
    this.receiptLockReason,
    this.invoiceAvailable = false,
    this.invoiceId,
    this.invoiceNumber,
    this.invoiceDownloadUrl,
    this.invoiceLockReason,
    this.hasAgreement = false,
    this.installments = const [],
  });

  bool get isPaid =>
      paymentStatus.toUpperCase() == 'PAID' ||
      paymentStatus.toUpperCase() == 'SUCCESS' ||
      paymentStatus.toUpperCase() == 'FULLY_PAID';
  bool get isPartiallyPaid => paymentStatus.toUpperCase() == 'PARTIALLY_PAID';

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    final amt = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final tax = (json['taxAmount'] as num?)?.toDouble() ?? (amt * 0.18);
    final total = (json['totalAmount'] as num?)?.toDouble() ?? (amt + tax);
    final paid =
        (json['paidAmount'] as num?)?.toDouble() ??
        (json['paymentStatus'] == 'PAID' ? total : 0.0);
    final remaining =
        (json['remainingAmount'] as num?)?.toDouble() ?? (total - paid);

    final rawInstallments = json['installments'] as List?;
    final instList = rawInstallments != null
        ? rawInstallments
              .map(
                (i) => OrderInstallment.fromJson(
                  Map<String, dynamic>.from(i as Map),
                ),
              )
              .toList()
        : <OrderInstallment>[];

    final isPaidStatus =
        json['paymentStatus']?.toString().toUpperCase() == 'PAID' ||
        json['paymentStatus']?.toString().toUpperCase() == 'SUCCESS' ||
        json['paymentStatus']?.toString().toUpperCase() == 'FULLY_PAID';

    final billingCycle = SubscriptionBillingCycle.fromString(
      json['billingCycle']?.toString(),
    );
    final purchaseDate =
        CustomerSubscriptionService.parseOrderCalendarDate(
          json['purchaseDate'],
        ) ??
        DateTime.now();
    // Order details activation date uses the subscription start date.
    final subscription = json['subscription'];
    final subscriptionStart = subscription is Map
        ? subscription['startDate']
        : null;
    final activationDate =
        CustomerSubscriptionService.parseOrderCalendarDate(
          json['startDate'] ??
              json['subscriptionStartDate'] ??
              subscriptionStart ??
              json['activationDate'],
        ) ??
        purchaseDate;
    final expiryDate =
        CustomerSubscriptionService.parseOrderCalendarDate(
          json['expiryDate'] ?? json['endDate'],
        ) ??
        activationDate;

    return CustomerOrder(
      id: json['id']?.toString() ?? '',
      orderNumber:
          json['orderId']?.toString() ??
          json['orderNumber']?.toString() ??
          '#QB-${json['id']}',
      planId: json['planId']?.toString() ?? '',
      planName: json['planName']?.toString() ?? 'Subscription Plan',
      billingCycle: billingCycle,
      amount: amt,
      taxAmount: tax,
      totalAmount: total,
      paidAmount: paid,
      remainingAmount: remaining,
      currency: json['currency']?.toString() ?? 'INR',
      paymentStatus: json['paymentStatus']?.toString() ?? 'PAID',
      paymentMethod: json['paymentMethod']?.toString() ?? 'Razorpay',
      transactionId: json['transactionId']?.toString(),
      purchaseDate: purchaseDate,
      activationDate: activationDate,
      expiryDate: expiryDate,
      features:
          (json['features'] as List?)?.map((e) => e.toString()).toList() ?? [],
      invoiceUrl: json['invoiceUrl']?.toString(),
      receiptAvailable:
          json['receiptAvailable'] == true ||
          (isPaidStatus && json['receiptAvailable'] != false),
      receiptId:
          json['receiptId']?.toString() ?? json['invoiceUrl']?.toString(),
      receiptNumber:
          json['receiptNumber']?.toString() ??
          json['receiptId']?.toString() ??
          json['invoiceUrl']?.toString(),
      receiptDownloadUrl:
          json['receiptDownloadUrl']?.toString() ??
          (json['receiptId'] != null
              ? '/receipts/${json['receiptId']}/download'
              : null),
      receiptLockReason: json['receiptLockReason']?.toString(),
      invoiceAvailable: json['invoiceAvailable'] == true,
      invoiceId: json['invoiceId']?.toString(),
      invoiceNumber: json['invoiceNumber']?.toString(),
      invoiceDownloadUrl:
          json['invoiceDownloadUrl']?.toString() ??
          (json['invoiceId'] != null
              ? '/invoices/${json['invoiceId']}/download'
              : null),
      invoiceLockReason:
          json['invoiceLockReason']?.toString() ??
          'Available after complete payment',
      hasAgreement:
          json['hasAgreement'] == true ||
          (isPaidStatus && json['hasAgreement'] != false),
      installments: instList,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderNumber,
    'orderNumber': orderNumber,
    'planId': planId,
    'planName': planName,
    'billingCycle': billingCycle.code,
    'amount': amount,
    'taxAmount': taxAmount,
    'totalAmount': totalAmount,
    'paidAmount': paidAmount,
    'remainingAmount': remainingAmount,
    'currency': currency,
    'paymentStatus': paymentStatus,
    'paymentMethod': paymentMethod,
    'transactionId': transactionId,
    'purchaseDate': purchaseDate.toIso8601String(),
    'activationDate': activationDate.toIso8601String(),
    'expiryDate': expiryDate.toIso8601String(),
    'features': features,
    'invoiceUrl': invoiceUrl,
    'receiptAvailable': receiptAvailable,
    'receiptId': receiptId,
    'receiptNumber': receiptNumber,
    'receiptDownloadUrl': receiptDownloadUrl,
    'receiptLockReason': receiptLockReason,
    'invoiceAvailable': invoiceAvailable,
    'invoiceId': invoiceId,
    'invoiceNumber': invoiceNumber,
    'invoiceDownloadUrl': invoiceDownloadUrl,
    'invoiceLockReason': invoiceLockReason,
    'installments': installments.map((i) => i.toJson()).toList(),
  };
}

@immutable
class CurrentInstallment {
  final int number;
  final double amount;
  final double paidAmount;
  final String status;
  final String? expiryDate;

  const CurrentInstallment({
    required this.number,
    required this.amount,
    required this.paidAmount,
    required this.status,
    this.expiryDate,
  });

  factory CurrentInstallment.fromJson(Map<String, dynamic> json) {
    return CurrentInstallment(
      number: (json['number'] as num?)?.toInt() ?? 1,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'DUE',
      expiryDate: json['expiryDate']?.toString(),
    );
  }
}

@immutable
class RenewalInfo {
  final String status;
  final bool canRenew;
  final String? bufferStartDate;
  final String? bufferEndDate;
  final int daysRemaining;

  const RenewalInfo({
    required this.status,
    required this.canRenew,
    this.bufferStartDate,
    this.bufferEndDate,
    required this.daysRemaining,
  });

  factory RenewalInfo.fromJson(Map<String, dynamic> json) {
    return RenewalInfo(
      status: json['status']?.toString() ?? 'ACTIVE',
      canRenew: json['canRenew'] == true,
      bufferStartDate: json['bufferStartDate']?.toString(),
      bufferEndDate: json['bufferEndDate']?.toString(),
      daysRemaining: (json['daysRemaining'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class CurrentSubscription {
  final String? subscriptionId;
  final String? customerId;
  final String? planId;
  final String planName;
  final double originalPlanValue;
  final String status;
  final CurrentInstallment? currentInstallment;
  final RenewalInfo renewal;
  final bool newPlanRequired;
  final double? newPlanPrice;

  const CurrentSubscription({
    this.subscriptionId,
    this.customerId,
    this.planId,
    required this.planName,
    required this.originalPlanValue,
    required this.status,
    this.currentInstallment,
    required this.renewal,
    required this.newPlanRequired,
    this.newPlanPrice,
  });

  factory CurrentSubscription.fromJson(Map<String, dynamic> json) {
    return CurrentSubscription(
      subscriptionId: json['subscriptionId']?.toString(),
      customerId: json['customerId']?.toString(),
      planId: json['planId']?.toString(),
      planName: json['planName']?.toString() ?? 'Active Plan',
      originalPlanValue: (json['originalPlanValue'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'ACTIVE',
      currentInstallment: json['currentInstallment'] != null
          ? CurrentInstallment.fromJson(
              json['currentInstallment'] as Map<String, dynamic>,
            )
          : null,
      renewal: json['renewal'] != null
          ? RenewalInfo.fromJson(json['renewal'] as Map<String, dynamic>)
          : const RenewalInfo(
              status: 'ACTIVE',
              canRenew: false,
              daysRemaining: 0,
            ),
      newPlanRequired: json['newPlanRequired'] == true,
      newPlanPrice: (json['newPlanPrice'] as num?)?.toDouble(),
    );
  }
}

@immutable
class NextInstallment {
  final int number;
  final double amount;
  final String status;

  const NextInstallment({
    required this.number,
    required this.amount,
    required this.status,
  });

  factory NextInstallment.fromJson(Map<String, dynamic> json) {
    return NextInstallment(
      number: (json['number'] as num?)?.toInt() ?? 1,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'DUE',
    );
  }
}

@immutable
class RenewalStatus {
  final String? subscriptionId;
  final String status;
  final bool canRenew;
  final bool bufferPeriodActive;
  final String? bufferStartDate;
  final String? bufferEndDate;
  final int daysRemaining;
  final double originalPlanValue;
  final NextInstallment? nextInstallment;
  final bool newPlanRequired;

  const RenewalStatus({
    this.subscriptionId,
    required this.status,
    required this.canRenew,
    required this.bufferPeriodActive,
    this.bufferStartDate,
    this.bufferEndDate,
    required this.daysRemaining,
    required this.originalPlanValue,
    this.nextInstallment,
    required this.newPlanRequired,
  });

  factory RenewalStatus.fromJson(Map<String, dynamic> json) {
    return RenewalStatus(
      subscriptionId: json['subscriptionId']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      canRenew: json['canRenew'] == true,
      bufferPeriodActive: json['bufferPeriodActive'] == true,
      bufferStartDate: json['bufferStartDate']?.toString(),
      bufferEndDate: json['bufferEndDate']?.toString(),
      daysRemaining: (json['daysRemaining'] as num?)?.toInt() ?? 0,
      originalPlanValue: (json['originalPlanValue'] as num?)?.toDouble() ?? 0.0,
      nextInstallment: json['nextInstallment'] != null
          ? NextInstallment.fromJson(
              json['nextInstallment'] as Map<String, dynamic>,
            )
          : null,
      newPlanRequired: json['newPlanRequired'] == true,
    );
  }
}

@immutable
class PaymentOrder {
  final String subscriptionId;
  final String installmentId;
  final String status;
  final double amount;
  final String nextAction;

  const PaymentOrder({
    required this.subscriptionId,
    required this.installmentId,
    required this.status,
    required this.amount,
    required this.nextAction,
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    return PaymentOrder(
      subscriptionId: json['subscriptionId']?.toString() ?? '',
      installmentId: json['installmentId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      nextAction: json['nextAction']?.toString() ?? 'PAYMENT',
    );
  }
}
