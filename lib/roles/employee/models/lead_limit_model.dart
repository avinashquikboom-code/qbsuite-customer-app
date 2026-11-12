class LeadLimitPeriod {
  final int limit;
  final int used;
  final int remaining;

  const LeadLimitPeriod({
    required this.limit,
    required this.used,
    required this.remaining,
  });

  factory LeadLimitPeriod.fromJson(Map<String, dynamic> json) {
    return LeadLimitPeriod(
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      used: (json['used'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    );
  }

  factory LeadLimitPeriod.empty() =>
      const LeadLimitPeriod(limit: 0, used: 0, remaining: 0);

  bool get isExhausted => remaining <= 0;
  double get progressPct => limit > 0 ? (used / limit).clamp(0.0, 1.0) : 1.0;
}

class EmployeeLeadLimitModel {
  final LeadLimitPeriod daily;
  final LeadLimitPeriod monthly;
  final bool hasLeadsPermission;
  final String? roleName;
  final bool isCustom;

  const EmployeeLeadLimitModel({
    required this.daily,
    required this.monthly,
    this.hasLeadsPermission = true,
    this.roleName,
    this.isCustom = false,
  });

  factory EmployeeLeadLimitModel.fromJson(Map<String, dynamic> json) {
    return EmployeeLeadLimitModel(
      daily: json['daily'] is Map<String, dynamic>
          ? LeadLimitPeriod.fromJson(json['daily'] as Map<String, dynamic>)
          : LeadLimitPeriod.empty(),
      monthly: json['monthly'] is Map<String, dynamic>
          ? LeadLimitPeriod.fromJson(json['monthly'] as Map<String, dynamic>)
          : LeadLimitPeriod.empty(),
      hasLeadsPermission: json['hasLeadsPermission'] as bool? ?? true,
      roleName: json['roleName'] as String?,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  factory EmployeeLeadLimitModel.empty() => EmployeeLeadLimitModel(
    daily: LeadLimitPeriod.empty(),
    monthly: LeadLimitPeriod.empty(),
  );
}
