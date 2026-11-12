/// Data model for Social Media Handlers in QuikBoom CRM Mobile.
class CustomerSocialMediaHandler {
  final int id;
  final int customerId;
  final String? customerName;
  final String platform;
  final String accountName;
  final String? accountUrl;
  final String? handlerName;
  final String? handlerPhone;
  final String? handlerEmail;
  final String workType;
  final String status;
  final String? notes;
  final String? socialMediaId;
  final String? password;
  final DateTime? startDate;
  final DateTime? endDate;
  final int durationDays;
  final DateTime createdAt;

  const CustomerSocialMediaHandler({
    required this.id,
    required this.customerId,
    this.customerName,
    required this.platform,
    required this.accountName,
    this.accountUrl,
    this.handlerName,
    this.handlerPhone,
    this.handlerEmail,
    this.workType = 'Content Posting',
    this.status = 'ACTIVE',
    this.notes,
    this.socialMediaId,
    this.password,
    this.startDate,
    this.endDate,
    this.durationDays = 30,
    required this.createdAt,
  });

  factory CustomerSocialMediaHandler.fromJson(Map<String, dynamic> json) {
    DateTime? start;
    if (json['startDate'] != null && json['startDate'].toString().isNotEmpty) {
      start = DateTime.tryParse(json['startDate'].toString());
    }
    DateTime? end;
    if (json['endDate'] != null && json['endDate'].toString().isNotEmpty) {
      end = DateTime.tryParse(json['endDate'].toString());
    }
    DateTime created = DateTime.now();
    if (json['createdAt'] != null && json['createdAt'].toString().isNotEmpty) {
      created =
          DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now();
    }

    final cust = json['customer'] is Map ? json['customer'] : null;
    final custName =
        cust?['name']?.toString() ?? cust?['companyName']?.toString();

    return CustomerSocialMediaHandler(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      customerId: int.tryParse(json['customerId']?.toString() ?? '0') ?? 0,
      customerName: custName,
      platform: (json['platform']?.toString() ?? 'INSTAGRAM').toUpperCase(),
      accountName: json['accountName']?.toString() ?? '',
      accountUrl: json['accountUrl']?.toString(),
      handlerName: json['handlerName']?.toString(),
      handlerPhone: json['handlerPhone']?.toString(),
      handlerEmail: json['handlerEmail']?.toString(),
      workType: json['workType']?.toString() ?? 'Content Posting',
      status: (json['status']?.toString() ?? 'ACTIVE').toUpperCase(),
      notes: json['notes']?.toString(),
      socialMediaId: json['socialMediaId']?.toString(),
      password: json['password']?.toString(),
      startDate: start,
      endDate: end,
      durationDays:
          int.tryParse(json['durationDays']?.toString() ?? '30') ?? 30,
      createdAt: created,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'platform': platform,
      'accountName': accountName,
      'accountUrl': accountUrl,
      'handlerName': handlerName,
      'handlerPhone': handlerPhone,
      'handlerEmail': handlerEmail,
      'workType': workType,
      'status': status,
      'notes': notes,
      if (socialMediaId != null) 'socialMediaId': socialMediaId,
      if (password != null) 'password': password,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'durationDays': durationDays,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get displayName => '$platform — $accountName';
  String get accountDisplay => '$platform — $accountName';

  String get platformDisplay {
    switch (platform.toUpperCase()) {
      case 'INSTAGRAM':
        return 'Instagram';
      case 'FACEBOOK':
        return 'Facebook';
      case 'YOUTUBE':
        return 'YouTube';
      case 'LINKEDIN':
        return 'LinkedIn';
      case 'TWITTER':
      case 'X':
        return 'X (Twitter)';
      default:
        return platform;
    }
  }
}

/// Backwards compatibility alias for existing views
typedef SocialMediaWorkItem = CustomerSocialMediaHandler;
