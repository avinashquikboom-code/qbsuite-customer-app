class CommissionItem {
  final int id;
  final int customerId;
  final int employeeId;
  final int? leadId;
  final int? planId;
  final int? purchaseId;
  final String? orderId;
  final String commissionType; // 'PERCENTAGE' or 'FIXED'
  final double commissionRate;
  final double? originalCommissionRate;
  final double? employeeShareAmount;
  final double? leaderShareAmount;
  final String recipientRole;
  final String? sourceEmployeeName;
  final String? payrollPeriod;
  final String? reviewReason;
  final double? customerCommissionTotal;
  final String? qualifyingAt;
  final String? employeeShareStatus;
  final double purchaseAmount;
  final double commissionAmount;
  final String status; // 'PENDING' | 'APPROVED' | 'PAID' | 'CANCELLED'
  final String? paidAt;
  final String createdAt;
  final LeadSummary? lead;
  final CustomerSummary? customer;
  final PlanSummary? plan;
  final PurchaseSummary? purchase;

  CommissionItem({
    required this.id,
    required this.customerId,
    required this.employeeId,
    this.leadId,
    this.planId,
    this.purchaseId,
    this.orderId,
    required this.commissionType,
    required this.commissionRate,
    this.originalCommissionRate,
    this.employeeShareAmount,
    this.leaderShareAmount,
    this.recipientRole = 'LEGACY',
    this.sourceEmployeeName,
    this.payrollPeriod,
    this.reviewReason,
    this.customerCommissionTotal,
    this.qualifyingAt,
    this.employeeShareStatus,
    required this.purchaseAmount,
    required this.commissionAmount,
    required this.status,
    this.paidAt,
    required this.createdAt,
    this.lead,
    this.customer,
    this.plan,
    this.purchase,
  });

  bool get isEarned => status == 'APPROVED';
  bool get isApproved => status == 'APPROVED';
  bool get isPaid => status == 'PAID';
  bool get isPending => status == 'PENDING';
  bool get isCancelled => status == 'CANCELLED';

  factory CommissionItem.fromJson(Map<String, dynamic> json) {
    return CommissionItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      customerId: json['customerId'] is int
          ? json['customerId']
          : int.tryParse(json['customerId']?.toString() ?? '0') ?? 0,
      employeeId: json['employeeId'] is int
          ? json['employeeId']
          : int.tryParse(json['employeeId']?.toString() ?? '0') ?? 0,
      leadId: json['leadId'] != null
          ? (json['leadId'] is int
                ? json['leadId']
                : int.tryParse(json['leadId'].toString()))
          : null,
      planId: json['planId'] != null
          ? (json['planId'] is int
                ? json['planId']
                : int.tryParse(json['planId'].toString()))
          : null,
      purchaseId: json['purchaseId'] != null
          ? (json['purchaseId'] is int
                ? json['purchaseId']
                : int.tryParse(json['purchaseId'].toString()))
          : null,
      orderId: json['orderId']?.toString(),
      commissionType: (json['commissionType'] ?? 'PERCENTAGE').toString(),
      originalCommissionRate: (json['originalCommissionRate'] as num?)
          ?.toDouble(),
      employeeShareAmount: (json['employeeShareAmount'] as num?)?.toDouble(),
      leaderShareAmount: (json['leaderShareAmount'] as num?)?.toDouble(),
      recipientRole: (json['recipientRole'] ?? 'LEGACY').toString(),
      sourceEmployeeName: json['employee'] is Map
          ? '${json['employee']['firstName'] ?? ''} ${json['employee']['lastName'] ?? ''}'
                .trim()
          : null,
      payrollPeriod: json['payrollPeriod']?.toString(),
      reviewReason: json['reviewReason']?.toString(),
      customerCommissionTotal: (json['customerCommissionTotal'] as num?)
          ?.toDouble(),
      qualifyingAt: json['qualifyingAt']?.toString(),
      employeeShareStatus: json['employeeShareStatus']?.toString(),
      commissionRate:
          (json['commissionRate'] is num
              ? json['commissionRate'].toDouble()
              : double.tryParse(json['commissionRate']?.toString() ?? '0')) ??
          0.0,
      purchaseAmount:
          (json['purchaseAmount'] is num
              ? json['purchaseAmount'].toDouble()
              : double.tryParse(json['purchaseAmount']?.toString() ?? '0')) ??
          0.0,
      commissionAmount:
          (json['commissionAmount'] is num
              ? json['commissionAmount'].toDouble()
              : double.tryParse(json['commissionAmount']?.toString() ?? '0')) ??
          0.0,
      status: (json['status'] ?? 'PENDING').toString(),
      paidAt: json['paidAt']?.toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      lead: json['lead'] != null ? LeadSummary.fromJson(json['lead']) : null,
      customer: json['customer'] != null
          ? CustomerSummary.fromJson(json['customer'])
          : null,
      plan: json['plan'] != null ? PlanSummary.fromJson(json['plan']) : null,
      purchase: json['purchase'] != null
          ? PurchaseSummary.fromJson(json['purchase'])
          : null,
    );
  }
}

class LeadSummary {
  final int id;
  final String? firstName;
  final String? lastName;
  final String? companyName;
  final String? title;

  LeadSummary({
    required this.id,
    this.firstName,
    this.lastName,
    this.companyName,
    this.title,
  });

  String get displayName {
    if (companyName != null && companyName!.trim().isNotEmpty) {
      return companyName!;
    }
    if (title != null && title!.trim().isNotEmpty) return title!;
    final name = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    return name.isNotEmpty ? name : 'Lead #$id';
  }

  factory LeadSummary.fromJson(Map<String, dynamic> json) {
    return LeadSummary(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      companyName: json['companyName']?.toString(),
      title: json['title']?.toString(),
    );
  }
}

class CustomerSummary {
  final int id;
  final String? name;
  final String? companyName;

  CustomerSummary({required this.id, this.name, this.companyName});

  String get displayName {
    if (companyName != null && companyName!.trim().isNotEmpty) {
      return companyName!;
    }
    return name?.isNotEmpty == true ? name! : 'Customer #$id';
  }

  factory CustomerSummary.fromJson(Map<String, dynamic> json) {
    return CustomerSummary(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString(),
      companyName: json['companyName']?.toString(),
    );
  }
}

class PlanSummary {
  final int id;
  final String name;
  final double? monthlyPrice;
  final double? yearlyPrice;

  PlanSummary({
    required this.id,
    required this.name,
    this.monthlyPrice,
    this.yearlyPrice,
  });

  factory PlanSummary.fromJson(Map<String, dynamic> json) {
    return PlanSummary(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: (json['name'] ?? 'Plan').toString(),
      monthlyPrice: json['monthlyPrice'] is num
          ? json['monthlyPrice'].toDouble()
          : null,
      yearlyPrice: json['yearlyPrice'] is num
          ? json['yearlyPrice'].toDouble()
          : null,
    );
  }
}

class PurchaseSummary {
  final int id;
  final String? orderNumber;
  final String? paymentId;
  final double? amount;
  final double? totalAmount;

  PurchaseSummary({
    required this.id,
    this.orderNumber,
    this.paymentId,
    this.amount,
    this.totalAmount,
  });

  factory PurchaseSummary.fromJson(Map<String, dynamic> json) {
    return PurchaseSummary(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      orderNumber: json['orderNumber']?.toString(),
      paymentId: json['paymentId']?.toString(),
      amount: json['amount'] is num ? json['amount'].toDouble() : null,
      totalAmount: json['totalAmount'] is num
          ? json['totalAmount'].toDouble()
          : null,
    );
  }
}

class CommissionSummary {
  final double totalCommission;
  final double pendingCommission;
  final double approvedCommission; // Earned
  final double paidCommission;
  final int totalCount;
  final int pendingCount;
  final int approvedCount;
  final int paidCount;

  CommissionSummary({
    required this.totalCommission,
    required this.pendingCommission,
    required this.approvedCommission,
    required this.paidCommission,
    required this.totalCount,
    required this.pendingCount,
    required this.approvedCount,
    required this.paidCount,
  });

  factory CommissionSummary.fromJson(Map<String, dynamic> json) {
    return CommissionSummary(
      totalCommission:
          (json['totalCommission'] is num
              ? json['totalCommission'].toDouble()
              : double.tryParse(json['totalCommission']?.toString() ?? '0')) ??
          0.0,
      pendingCommission:
          (json['pendingCommission'] is num
              ? json['pendingCommission'].toDouble()
              : double.tryParse(
                  json['pendingCommission']?.toString() ?? '0',
                )) ??
          0.0,
      approvedCommission:
          (json['approvedCommission'] is num
              ? json['approvedCommission'].toDouble()
              : double.tryParse(
                  json['approvedCommission']?.toString() ?? '0',
                )) ??
          0.0,
      paidCommission:
          (json['paidCommission'] is num
              ? json['paidCommission'].toDouble()
              : double.tryParse(json['paidCommission']?.toString() ?? '0')) ??
          0.0,
      totalCount:
          (json['totalCount'] is int
              ? json['totalCount']
              : int.tryParse(json['totalCount']?.toString() ?? '0')) ??
          0,
      pendingCount:
          (json['pendingCount'] is int
              ? json['pendingCount']
              : int.tryParse(json['pendingCount']?.toString() ?? '0')) ??
          0,
      approvedCount:
          (json['approvedCount'] is int
              ? json['approvedCount']
              : int.tryParse(json['approvedCount']?.toString() ?? '0')) ??
          0,
      paidCount:
          (json['paidCount'] is int
              ? json['paidCount']
              : int.tryParse(json['paidCount']?.toString() ?? '0')) ??
          0,
    );
  }

  factory CommissionSummary.empty() {
    return CommissionSummary(
      totalCommission: 0,
      pendingCommission: 0,
      approvedCommission: 0,
      paidCommission: 0,
      totalCount: 0,
      pendingCount: 0,
      approvedCount: 0,
      paidCount: 0,
    );
  }
}

class CommissionEmployeeInfo {
  final int id;
  final String name;
  final String employeeCode;
  final String designation;

  CommissionEmployeeInfo({
    required this.id,
    required this.name,
    required this.employeeCode,
    required this.designation,
  });

  factory CommissionEmployeeInfo.fromJson(Map<String, dynamic> json) {
    return CommissionEmployeeInfo(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: (json['name'] ?? '').toString(),
      employeeCode: (json['employeeCode'] ?? '').toString(),
      designation: (json['designation'] ?? 'Staff').toString(),
    );
  }
}

class EmployeeCommissionResponse {
  final List<CommissionItem> items;
  final CommissionSummary summary;
  final CommissionEmployeeInfo? employee;
  final int total;
  final int page;
  final int limit;

  EmployeeCommissionResponse({
    required this.items,
    required this.summary,
    this.employee,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory EmployeeCommissionResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] as List<dynamic>? ?? [];
    final items = rawData
        .map((e) => CommissionItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final summary = json['summary'] != null
        ? CommissionSummary.fromJson(json['summary'] as Map<String, dynamic>)
        : CommissionSummary.empty();
    final employee = json['employee'] != null
        ? CommissionEmployeeInfo.fromJson(
            json['employee'] as Map<String, dynamic>,
          )
        : null;
    final meta = json['meta'] as Map<String, dynamic>? ?? {};

    return EmployeeCommissionResponse(
      items: items,
      summary: summary,
      employee: employee,
      total:
          (meta['total'] is int
              ? meta['total']
              : int.tryParse(meta['total']?.toString() ?? '0')) ??
          items.length,
      page:
          (meta['page'] is int
              ? meta['page']
              : int.tryParse(meta['page']?.toString() ?? '1')) ??
          1,
      limit:
          (meta['limit'] is int
              ? meta['limit']
              : int.tryParse(meta['limit']?.toString() ?? '20')) ??
          20,
    );
  }
}
