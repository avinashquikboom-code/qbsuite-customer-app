class EmployeeClaimItem {
  final int id;
  final int customerId;
  final int employeeId;
  final String category;
  final double amount;
  final double? approvedAmount;
  final String claimDate;
  final String description;
  final String? receiptUrl;
  final String status;
  final String paymentStatus;
  final String? rejectionReason;
  final String? reviewedByName;
  final String createdAt;

  EmployeeClaimItem({
    required this.id,
    required this.customerId,
    required this.employeeId,
    required this.category,
    required this.amount,
    this.approvedAmount,
    required this.claimDate,
    required this.description,
    this.receiptUrl,
    required this.status,
    required this.paymentStatus,
    this.rejectionReason,
    this.reviewedByName,
    required this.createdAt,
  });

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED' || status == 'PAID';
  bool get isRejected => status == 'REJECTED';
  bool get isPaid => status == 'PAID' || paymentStatus == 'PAID';

  factory EmployeeClaimItem.fromJson(Map<String, dynamic> json) {
    return EmployeeClaimItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      customerId: json['customerId'] is int
          ? json['customerId']
          : int.tryParse(json['customerId']?.toString() ?? '0') ?? 0,
      employeeId: json['employeeId'] is int
          ? json['employeeId']
          : int.tryParse(json['employeeId']?.toString() ?? '0') ?? 0,
      category: (json['category'] ?? 'TRAVEL').toString(),
      amount: (json['amount'] ?? 0).toDouble(),
      approvedAmount: json['approvedAmount'] != null
          ? (json['approvedAmount']).toDouble()
          : null,
      claimDate: (json['claimDate'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      receiptUrl: json['receiptUrl']?.toString(),
      status: (json['status'] ?? 'PENDING').toString(),
      paymentStatus: (json['paymentStatus'] ?? 'UNPAID').toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      reviewedByName: json['reviewedByName']?.toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }
}
