/// Representation of an employee's leave balance item
class LeaveBalanceItem {
  final int? id;
  final String leaveType;
  final String code;
  final double totalAllowed;
  final double used;
  final double remaining;
  final double pending;
  final bool isUnlimited;

  LeaveBalanceItem({
    this.id,
    required this.leaveType,
    required this.code,
    required this.totalAllowed,
    required this.used,
    required this.remaining,
    this.pending = 0,
    this.isUnlimited = false,
  });

  factory LeaveBalanceItem.fromJson(Map<String, dynamic> json) {
    final typeName =
        (json['leaveTypeName'] ??
                json['name'] ??
                json['leaveType'] ??
                json['type'] ??
                'Leave')
            .toString();
    final total =
        (json['allocated'] as num?)?.toDouble() ??
        (json['totalAllowed'] as num?)?.toDouble() ??
        (json['total'] as num?)?.toDouble() ??
        (json['entitled'] as num?)?.toDouble() ??
        12.0;
    final usedVal =
        (json['used'] as num?)?.toDouble() ??
        (json['taken'] as num?)?.toDouble() ??
        0.0;
    final pendingVal = (json['pending'] as num?)?.toDouble() ?? 0.0;
    final remainingVal =
        (json['remaining'] as num?)?.toDouble() ??
        (json['balance'] as num?)?.toDouble() ??
        (total - usedVal);
    final rawId = json['leaveTypeId'] ?? json['id'];
    final idVal = rawId is int
        ? rawId
        : (rawId != null ? int.tryParse(rawId.toString()) : null);

    return LeaveBalanceItem(
      id: idVal,
      leaveType: typeName,
      code:
          (json['code'] ??
                  (typeName.length >= 2
                      ? typeName.substring(0, 2).toUpperCase()
                      : 'LV'))
              .toString(),
      totalAllowed: total,
      used: usedVal,
      pending: pendingVal,
      remaining: remainingVal,
      isUnlimited: json['isUnlimited'] == true,
    );
  }
}

/// Representation of a submitted Leave Request
class LeaveRequestItem {
  final String id;
  final String leaveType;
  final String fromDate;
  final String toDate;
  final int days;
  final String reason;
  final String status;
  final String? rejectionReason;
  final String? appliedOn;
  final bool isHalfDay;
  final DateTime? createdAt;

  LeaveRequestItem({
    required this.id,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.reason,
    required this.status,
    this.rejectionReason,
    this.appliedOn,
    this.isHalfDay = false,
    this.createdAt,
  });

  factory LeaveRequestItem.fromJson(Map<String, dynamic> json) {
    String parsedType = 'Casual Leave';
    final rawType = json['leaveType'];
    if (rawType is Map) {
      parsedType =
          (rawType['name'] ?? rawType['leaveTypeName'] ?? 'Casual Leave')
              .toString();
    } else if (rawType is String && rawType.trim().isNotEmpty) {
      parsedType = rawType.trim();
    } else if (json['leaveTypeName'] != null) {
      parsedType = json['leaveTypeName'].toString();
    } else if (json['type'] != null) {
      parsedType = json['type'].toString();
    }

    final rawDays = json['days'] as num? ?? json['totalDays'] as num?;
    final daysCount = rawDays?.toInt() ?? 1;
    final halfDay =
        (rawDays != null && rawDays.toDouble() < 1.0) ||
        json['isHalfDay'] == true ||
        (json['reason']?.toString().toLowerCase().contains('half') ?? false);

    final applied =
        json['appliedOn']?.toString() ??
        (json['createdAt'] != null
            ? json['createdAt'].toString().split('T')[0]
            : null);

    return LeaveRequestItem(
      id: (json['id'] ?? '').toString(),
      leaveType: parsedType,
      fromDate: (json['fromDate'] ?? json['startDate'] ?? '').toString().split(
        'T',
      )[0],
      toDate: (json['toDate'] ?? json['endDate'] ?? '').toString().split(
        'T',
      )[0],
      days: daysCount > 0 ? daysCount : 1,
      reason: (json['reason'] ?? 'Personal reasons').toString(),
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      rejectionReason: json['rejectionReason']?.toString(),
      appliedOn: applied,
      isHalfDay: halfDay,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';
}

/// Representation of a Remote Work (WFH) Request
class RemoteRequestItem {
  final String id;
  final String fromDate;
  final String toDate;
  final String startTime;
  final String endTime;
  final int days;
  final String? duration;
  final String reason;
  final String status;
  final String? rejectionReason;
  final String? appliedOn;
  final DateTime? createdAt;

  RemoteRequestItem({
    required this.id,
    required this.fromDate,
    required this.toDate,
    this.startTime = '09:00 AM',
    this.endTime = '06:00 PM',
    required this.days,
    this.duration,
    required this.reason,
    required this.status,
    this.rejectionReason,
    this.appliedOn,
    this.createdAt,
  });

  factory RemoteRequestItem.fromJson(Map<String, dynamic> json) {
    final rawDays = (json['days'] as num?)?.toInt() ?? 1;
    final dur =
        json['duration']?.toString() ??
        '$rawDays ${rawDays == 1 ? 'Day' : 'Days'}';
    final applied =
        json['appliedOn']?.toString() ??
        (json['createdAt'] != null
            ? json['createdAt'].toString().split('T')[0]
            : null);

    return RemoteRequestItem(
      id: (json['id'] ?? '').toString(),
      fromDate: (json['fromDate'] ?? json['startDate'] ?? '').toString().split(
        'T',
      )[0],
      toDate: (json['toDate'] ?? json['endDate'] ?? '').toString().split(
        'T',
      )[0],
      startTime: (json['startTime'] ?? '09:00 AM').toString(),
      endTime: (json['endTime'] ?? '06:00 PM').toString(),
      days: rawDays,
      duration: dur,
      reason: (json['reason'] ?? 'Work from home').toString(),
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      rejectionReason: json['rejectionReason']?.toString(),
      appliedOn: applied,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';
}
