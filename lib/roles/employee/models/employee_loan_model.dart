class EmployeeLoanItem {
  final int id;
  final int customerId;
  final int employeeId;
  final double loanAmount;
  final double? approvedAmount;
  final String reason;
  final int termMonths;
  final double monthlyEmi;
  final double interestRate;
  final String? startDate;
  final double? remainingBalance;
  final String status;
  final String? rejectionReason;
  final String? approvedByName;
  final String createdAt;

  EmployeeLoanItem({
    required this.id,
    required this.customerId,
    required this.employeeId,
    required this.loanAmount,
    this.approvedAmount,
    required this.reason,
    required this.termMonths,
    required this.monthlyEmi,
    this.interestRate = 0.0,
    this.startDate,
    this.remainingBalance,
    required this.status,
    this.rejectionReason,
    this.approvedByName,
    required this.createdAt,
  });

  bool get isPending => status == 'PENDING';
  bool get isActive => status == 'ACTIVE' || status == 'APPROVED';
  bool get isPaid => status == 'PAID';
  bool get isRejected => status == 'REJECTED';

  factory EmployeeLoanItem.fromJson(Map<String, dynamic> json) {
    return EmployeeLoanItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      customerId: json['customerId'] is int
          ? json['customerId']
          : int.tryParse(json['customerId']?.toString() ?? '0') ?? 0,
      employeeId: json['employeeId'] is int
          ? json['employeeId']
          : int.tryParse(json['employeeId']?.toString() ?? '0') ?? 0,
      loanAmount: (json['loanAmount'] ?? 0).toDouble(),
      approvedAmount: json['approvedAmount'] != null
          ? (json['approvedAmount']).toDouble()
          : null,
      reason: (json['reason'] ?? '').toString(),
      termMonths: json['termMonths'] is int
          ? json['termMonths']
          : int.tryParse(json['termMonths']?.toString() ?? '12') ?? 12,
      monthlyEmi: (json['monthlyEmi'] ?? 0).toDouble(),
      interestRate: (json['interestRate'] ?? 0).toDouble(),
      startDate: json['startDate']?.toString(),
      remainingBalance: json['remainingBalance'] != null
          ? (json['remainingBalance']).toDouble()
          : null,
      status: (json['status'] ?? 'PENDING').toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      approvedByName: json['approvedByName']?.toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }
}
