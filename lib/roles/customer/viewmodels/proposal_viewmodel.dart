import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_plan_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/proposal_model.dart';
import 'package:quickboom_crm_customer/roles/customer/services/customer_subscription_service.dart';

class CustomerProposalFeature {
  final String name;
  final String quantity;
  final String description;

  const CustomerProposalFeature({
    required this.name,
    this.quantity = '',
    this.description = '',
  });

  factory CustomerProposalFeature.fromDynamic(dynamic raw) {
    if (raw is Map) {
      return CustomerProposalFeature(
        name: (raw['name'] ?? '').toString().trim(),
        quantity: (raw['quantity'] ?? '').toString().trim(),
        description: (raw['description'] ?? '').toString().trim(),
      );
    }
    return CustomerProposalFeature(name: raw.toString().trim());
  }

  String get displayLine {
    final head = quantity.isNotEmpty ? '$quantity × $name' : name;
    return description.isNotEmpty ? '$head — $description' : head;
  }
}

class CustomerProposalRecord {
  final int id;
  final int leadId;
  final int customerId;
  final int version;
  final String proposalNo;
  final String proposalType;
  final String status;
  final int? planId;
  final String planName;
  final String? planCode;
  final String description;
  final double agreedPrice;
  final SubscriptionBillingCycle billingCycle;
  final double monthlyPrice;
  final double yearlyPrice;
  final int? userLimit;
  final int? leadLimit;
  final List<CustomerProposalFeature> features;
  final double discount;
  final String? validUntil;
  final String terms;
  final String proposalDate;
  final bool alreadyPaid;
  final double totalPaid;
  final String createdByName;

  const CustomerProposalRecord({
    required this.id,
    required this.leadId,
    required this.customerId,
    required this.version,
    required this.proposalNo,
    required this.proposalType,
    required this.status,
    this.planId,
    required this.planName,
    this.planCode,
    required this.description,
    required this.agreedPrice,
    required this.billingCycle,
    required this.monthlyPrice,
    required this.yearlyPrice,
    this.userLimit,
    this.leadLimit,
    required this.features,
    this.discount = 0,
    this.validUntil,
    this.terms = '',
    required this.proposalDate,
    this.alreadyPaid = false,
    this.totalPaid = 0,
    this.createdByName = 'Sales Team',
  });

  factory CustomerProposalRecord.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'] is List ? json['features'] as List : [];
    return CustomerProposalRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      leadId: (json['leadId'] as num?)?.toInt() ?? 0,
      customerId: (json['customerId'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 1,
      proposalNo: (json['proposalNo'] ?? 'PLAN').toString(),
      proposalType: (json['proposalType'] ?? 'DEFAULT').toString(),
      status: (json['status'] ?? 'SENT').toString(),
      planId: (json['planId'] as num?)?.toInt(),
      planName: (json['planName'] ?? 'Subscription Plan').toString(),
      planCode: json['planCode']?.toString(),
      description: (json['description'] ?? '').toString(),
      agreedPrice: (json['agreedPrice'] as num?)?.toDouble() ?? 0.0,
      billingCycle: SubscriptionBillingCycle.fromString(
        json['billingCycle']?.toString(),
      ),
      monthlyPrice: (json['monthlyPrice'] as num?)?.toDouble() ?? 0.0,
      yearlyPrice: (json['yearlyPrice'] as num?)?.toDouble() ?? 0.0,
      userLimit: (json['userLimit'] as num?)?.toInt(),
      leadLimit: (json['leadLimit'] as num?)?.toInt(),
      features: rawFeatures
          .map(CustomerProposalFeature.fromDynamic)
          .where((f) => f.name.isNotEmpty)
          .toList(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      validUntil: json['validUntil']?.toString(),
      terms: (json['terms'] ?? '').toString(),
      proposalDate: (json['proposalDate'] ?? json['createdAt'] ?? '').toString(),
      alreadyPaid: json['alreadyPaid'] == true,
      totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0.0,
      createdByName: (json['createdByName'] ?? 'Sales Team').toString(),
    );
  }

  SubscriptionPlan toCheckoutPlan() {
    return SubscriptionPlan(
      id: (planId ?? 0).toString(),
      name: planName,
      subtitle: description.isNotEmpty ? description : null,
      code: planCode ?? proposalNo,
      description: description,
      monthlyPrice: billingCycle == SubscriptionBillingCycle.monthly
          ? agreedPrice
          : monthlyPrice,
      yearlyPrice: billingCycle == SubscriptionBillingCycle.yearly
          ? agreedPrice
          : yearlyPrice,
      features: features.map((f) => f.displayLine).toList(),
      userLimit: userLimit ?? 5,
      leadLimit: leadLimit ?? 500,
    );
  }
}

final customerProposalsProvider =
    AsyncNotifierProvider<CustomerProposalsViewModel, List<CustomerProposalRecord>>(() {
      return CustomerProposalsViewModel();
    });

class CustomerProposalsViewModel
    extends AsyncNotifier<List<CustomerProposalRecord>> {
  @override
  Future<List<CustomerProposalRecord>> build() async {
    final service = ref.watch(customerSubscriptionServiceProvider);
    final rows = await service.getCustomerProposals();
    return rows.map(CustomerProposalRecord.fromJson).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(customerSubscriptionServiceProvider);
      final rows = await service.getCustomerProposals();
      return rows.map(CustomerProposalRecord.fromJson).toList();
    });
  }
}

/// Kept for compatibility with existing invalidation sites (backed by real API, no mock data).
final proposalsProvider = Provider<List<ProposalModel>>((ref) => const []);
