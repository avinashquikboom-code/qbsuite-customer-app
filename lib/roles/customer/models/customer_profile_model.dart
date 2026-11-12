/// Strongly typed model for currently authenticated Customer Profile from /api/v1/customers/me
class CustomerProfileUserModel {
  final int id;
  final String email;
  final String? phone;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? avatar;
  final String? designation;

  const CustomerProfileUserModel({
    required this.id,
    required this.email,
    this.phone,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.avatar,
    this.designation,
  });

  String get fullName {
    final parts = [firstName, middleName ?? '', lastName]
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && p.toLowerCase() != 'null')
        .toList();
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    return firstName.trim();
  }

  factory CustomerProfileUserModel.fromJson(Map<String, dynamic> json) {
    return CustomerProfileUserModel(
      id: json['id'] is int
          ? json['id']
          : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      firstName: json['firstName']?.toString() ?? '',
      middleName: json['middleName']?.toString(),
      lastName: json['lastName']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      designation: json['designation']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'avatar': avatar,
      'designation': designation,
    };
  }
}

class CustomerProfileModel {
  final int id;
  final String customerId;
  final String? customerCode;
  final String name;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? fullName;
  final String companyName;
  final String? domain;
  final String? logo;
  final String? profileImage;
  final String? phone;
  final String? alternatePhone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? pincode;
  final String? customerType;
  final String? industry;
  final String? source;
  final String? assignedEmployee;
  final String? department;
  final String? notes;
  final bool isActive;
  final int userLimit;
  final int leadLimit;
  final int storageUsed;
  final int storageLimit;
  final String plan;
  final String planCode;
  final String subscriptionStatus;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final CustomerProfileUserModel? user;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomerProfileModel({
    required this.id,
    required this.customerId,
    this.customerCode,
    required this.name,
    this.firstName,
    this.middleName,
    this.lastName,
    this.fullName,
    required this.companyName,
    this.domain,
    this.logo,
    this.profileImage,
    this.phone,
    this.alternatePhone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.country,
    this.pincode,
    this.customerType,
    this.industry,
    this.source,
    this.assignedEmployee,
    this.department,
    this.notes,
    required this.isActive,
    required this.userLimit,
    required this.leadLimit,
    required this.storageUsed,
    required this.storageLimit,
    required this.plan,
    required this.planCode,
    required this.subscriptionStatus,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.user,
    this.createdAt,
    this.updatedAt,
  });

  /// Formatted location string (e.g., "Mumbai, Maharashtra, India - 400051")
  String get formattedLocation {
    final parts = [
      address,
      city,
      state,
      country,
      pincode != null && pincode!.isNotEmpty ? 'Pin: $pincode' : null,
    ].where((p) => p != null && p.trim().isNotEmpty).toList();

    if (parts.isEmpty) return 'Location not specified';
    return parts.join(', ');
  }

  /// Initials derived from customer/business name for avatar fallback
  String get initials {
    final clean = name.trim();
    if (clean.isEmpty) return 'CU';
    final parts = clean.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.substring(0, clean.length.clamp(1, 2)).toUpperCase();
  }

  /// Checks if a candidate string is an invalid person name part (e.g. company name, email, ID, null placeholder)
  static bool isInvalidPersonPart(
    String? s, {
    String? company,
    String? business,
    String? customerId,
    String? customerCode,
  }) {
    if (s == null) return true;
    final clean = s.trim();
    if (clean.isEmpty) return true;
    final lower = clean.toLowerCase();
    if (lower == 'null' || lower == 'undefined') return true;
    if (lower == 'customer' ||
        lower == 'valued customer' ||
        lower == 'client' ||
        lower == 'valued client') {
      return true;
    }

    // DO NOT create from email
    if (lower.contains('@')) return true;

    // DO NOT create from customer ID
    if (RegExp(r'^(cust|qb-cust)-\d+', caseSensitive: false).hasMatch(lower)) {
      return true;
    }
    if (customerId != null &&
        customerId.trim().isNotEmpty &&
        lower == customerId.trim().toLowerCase()) {
      return true;
    }
    if (customerCode != null &&
        customerCode.trim().isNotEmpty &&
        lower == customerCode.trim().toLowerCase()) {
      return true;
    }

    // DO NOT create from business/company name
    for (final c in [company, business]) {
      if (c != null && c.trim().isNotEmpty) {
        final compLower = c.trim().toLowerCase();
        if (lower == compLower) return true;
        // Bleed checks (e.g. lastName = "test2 ovt ltd" when company = "test2 ovt ltd" or "ovt ltd")
        if (compLower.length >= 3) {
          if (lower == compLower) return true;
          if (lower.endsWith(compLower)) return true;
          if (compLower.endsWith(lower) &&
              (lower.contains('ltd') ||
                  lower.contains('pvt') ||
                  lower.contains('inc') ||
                  lower.contains('corp') ||
                  lower.contains('marketing'))) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Formatted full name of customer person (First Middle Last)
  /// Strictly separated from business/company name, email, or customer ID.
  String get personFullName {
    // 1. Gather person name parts from top-level fields or nested user
    String? pFirst = (firstName != null && firstName!.trim().isNotEmpty)
        ? firstName!.trim()
        : user?.firstName.trim();
    String? pMiddle = (middleName != null && middleName!.trim().isNotEmpty)
        ? middleName!.trim()
        : user?.middleName?.trim();
    String? pLast = (lastName != null && lastName!.trim().isNotEmpty)
        ? lastName!.trim()
        : user?.lastName.trim();

    // Invalidate any part that matches company/business name, email, or customer ID
    if (isInvalidPersonPart(
      pFirst,
      company: companyName,
      customerId: customerId,
      customerCode: customerCode,
    )) {
      pFirst = null;
    }
    if (isInvalidPersonPart(
      pMiddle,
      company: companyName,
      customerId: customerId,
      customerCode: customerCode,
    )) {
      pMiddle = null;
    }
    if (isInvalidPersonPart(
      pLast,
      company: companyName,
      customerId: customerId,
      customerCode: customerCode,
    )) {
      pLast = null;
    }

    final validParts = [
      pFirst,
      pMiddle,
      pLast,
    ].where((s) => s != null && s.isNotEmpty).map((s) => s!).toList();

    if (validParts.isNotEmpty) {
      final candidate = validParts
          .join(' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (!isInvalidPersonPart(
        candidate,
        company: companyName,
        customerId: customerId,
        customerCode: customerCode,
      )) {
        return candidate;
      }
    }

    // 2. If explicit fullName is provided (e.g. from contactFullName)
    if (fullName != null &&
        fullName!.trim().isNotEmpty &&
        !isInvalidPersonPart(
          fullName,
          company: companyName,
          customerId: customerId,
          customerCode: customerCode,
        )) {
      return fullName!.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    // 3. If customer name was entered as person name in Admin Panel (different from companyName)
    final cleanName = name.trim();
    if (cleanName.isNotEmpty &&
        !isInvalidPersonPart(
          cleanName,
          company: companyName,
          customerId: customerId,
          customerCode: customerCode,
        )) {
      return cleanName.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    return 'Customer';
  }

  /// Formatted Business Name with Customer Code (e.g. "QuikBoom Digital Marketing • CUST-0028")
  /// Strictly uses actual Business/Company Name, NOT the person's name.
  String get businessWithCode {
    final cleanCompany = companyName.trim();
    final personName = personFullName.trim().toLowerCase();

    // Never use person's name as business name
    final bool isPersonName =
        cleanCompany.isEmpty ||
        cleanCompany.toLowerCase() == personName ||
        (personName.isNotEmpty &&
            name.trim().isNotEmpty &&
            cleanCompany.toLowerCase() == name.trim().toLowerCase() &&
            name.trim().toLowerCase() == personName);

    final bName = (!isPersonName && cleanCompany.isNotEmpty)
        ? cleanCompany
        : '';

    String code = (customerCode ?? '').trim();
    if (code.isEmpty) {
      code = customerId.trim();
    }

    String formattedCode = '';
    if (code.startsWith('CUST-')) {
      formattedCode = code;
    } else if (id > 0) {
      formattedCode = 'CUST-${id.toString().padLeft(4, '0')}';
    } else if (code.isNotEmpty) {
      final numMatch = RegExp(r'\d+').stringMatch(code);
      if (numMatch != null) {
        formattedCode = 'CUST-${numMatch.padLeft(4, '0')}';
      } else {
        formattedCode = code;
      }
    }

    if (bName.isNotEmpty && formattedCode.isNotEmpty) {
      return '$bName • $formattedCode';
    } else if (bName.isNotEmpty) {
      return bName;
    } else if (formattedCode.isNotEmpty) {
      return formattedCode;
    }
    return '';
  }

  /// Avatar initials derived from person full name
  String get personInitials {
    final clean = personFullName.trim();
    if (clean.isEmpty || clean == 'Customer') return initials;
    final parts = clean.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return clean.substring(0, clean.length.clamp(1, 2)).toUpperCase();
  }

  factory CustomerProfileModel.fromJson(Map<String, dynamic> json) {
    final rawCustId = json['customerId']?.toString() ?? 'QB-CUST-000';
    final rawCode = json['customerCode']?.toString();
    final cId = json['id'] is int
        ? json['id'] as int
        : (int.tryParse(json['id']?.toString() ?? '0') ?? 0);
    final resolvedCode = (rawCode != null && rawCode.isNotEmpty)
        ? rawCode
        : (rawCustId.startsWith('CUST-')
              ? rawCustId
              : (cId > 0 ? 'CUST-${cId.toString().padLeft(4, '0')}' : null));

    final rawCompany =
        (json['companyName']?.toString() ??
                json['businessName']?.toString() ??
                '')
            .trim();
    final rawName = (json['name']?.toString() ?? '').trim();
    final resolvedCompany = rawCompany.isNotEmpty
        ? rawCompany
        : (rawName.isNotEmpty ? rawName : 'Company');

    // Parse person name parts safely
    String? fName =
        json['firstName']?.toString() ?? json['contactFirstName']?.toString();
    String? mName =
        json['middleName']?.toString() ?? json['contactMiddleName']?.toString();
    String? lName =
        json['lastName']?.toString() ?? json['contactLastName']?.toString();
    String? fullN =
        json['fullName']?.toString() ?? json['contactFullName']?.toString();

    // Invalidate company name bleed in top-level lastName
    if (lName != null &&
        resolvedCompany.isNotEmpty &&
        (lName.trim().toLowerCase() == resolvedCompany.toLowerCase() ||
            (resolvedCompany.length >= 3 &&
                lName.trim().toLowerCase().endsWith(
                  resolvedCompany.toLowerCase(),
                )))) {
      lName = null;
    }

    // Parse nested user, ensuring company name bleed into user.lastName is stripped
    CustomerProfileUserModel? parsedUser;
    if (json['user'] is Map<String, dynamic>) {
      final userMap = Map<String, dynamic>.from(json['user']);
      final uLast = userMap['lastName']?.toString().trim() ?? '';
      if (resolvedCompany.isNotEmpty &&
          (uLast.toLowerCase() == resolvedCompany.toLowerCase() ||
              (resolvedCompany.length >= 3 &&
                  uLast.toLowerCase().endsWith(
                    resolvedCompany.toLowerCase(),
                  )))) {
        userMap['lastName'] = '';
      }
      parsedUser = CustomerProfileUserModel.fromJson(userMap);
    }

    return CustomerProfileModel(
      id: cId,
      customerId: rawCustId,
      customerCode: resolvedCode,
      name: rawName.isNotEmpty ? rawName : 'Customer',
      firstName: fName,
      middleName: mName,
      lastName: lName,
      fullName: fullN,
      companyName: resolvedCompany,
      domain: json['domain']?.toString(),
      logo: json['logo']?.toString(),
      profileImage:
          json['profileImage']?.toString() ?? json['logo']?.toString(),
      phone: json['phone']?.toString(),
      alternatePhone: json['alternatePhone']?.toString(),
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString() ?? 'India',
      pincode: json['pincode']?.toString(),
      customerType: json['customerType']?.toString() ?? 'ENTERPRISE',
      industry: json['industry']?.toString() ?? 'General',
      source: json['source']?.toString() ?? 'DIRECT',
      assignedEmployee: json['assignedEmployee']?.toString(),
      department: json['department']?.toString(),
      notes: json['notes']?.toString(),
      isActive: json['isActive'] != false,
      userLimit: json['userLimit'] is int
          ? json['userLimit']
          : (int.tryParse(json['userLimit']?.toString() ?? '5') ?? 5),
      leadLimit: json['leadLimit'] is int
          ? json['leadLimit']
          : (int.tryParse(json['leadLimit']?.toString() ?? '500') ?? 500),
      storageUsed: json['storageUsed'] is int
          ? json['storageUsed']
          : (int.tryParse(json['storageUsed']?.toString() ?? '0') ?? 0),
      storageLimit: json['storageLimit'] is int
          ? json['storageLimit']
          : (int.tryParse(json['storageLimit']?.toString() ?? '0') ?? 0),
      plan: json['plan']?.toString() ?? 'Standard Plan',
      planCode: json['planCode']?.toString() ?? 'STANDARD',
      subscriptionStatus: json['subscriptionStatus']?.toString() ?? 'ACTIVE',
      subscriptionStartDate: json['subscriptionStartDate'] != null
          ? DateTime.tryParse(json['subscriptionStartDate'].toString())
          : null,
      subscriptionEndDate: json['subscriptionEndDate'] != null
          ? DateTime.tryParse(json['subscriptionEndDate'].toString())
          : null,
      user: parsedUser,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  CustomerProfileModel copyWith({
    int? id,
    String? customerId,
    String? customerCode,
    String? name,
    String? firstName,
    String? middleName,
    String? lastName,
    String? fullName,
    String? companyName,
    String? domain,
    String? logo,
    String? profileImage,
    String? phone,
    String? alternatePhone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? country,
    String? pincode,
    String? customerType,
    String? industry,
    String? source,
    String? assignedEmployee,
    String? department,
    String? notes,
    bool? isActive,
    int? userLimit,
    int? leadLimit,
    int? storageUsed,
    int? storageLimit,
    String? plan,
    String? planCode,
    String? subscriptionStatus,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    CustomerProfileUserModel? user,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerProfileModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerCode: customerCode ?? this.customerCode,
      name: name ?? this.name,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      companyName: companyName ?? this.companyName,
      domain: domain ?? this.domain,
      logo: logo ?? this.logo,
      profileImage: profileImage ?? this.profileImage,
      phone: phone ?? this.phone,
      alternatePhone: alternatePhone ?? this.alternatePhone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      pincode: pincode ?? this.pincode,
      customerType: customerType ?? this.customerType,
      industry: industry ?? this.industry,
      source: source ?? this.source,
      assignedEmployee: assignedEmployee ?? this.assignedEmployee,
      department: department ?? this.department,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      userLimit: userLimit ?? this.userLimit,
      leadLimit: leadLimit ?? this.leadLimit,
      storageUsed: storageUsed ?? this.storageUsed,
      storageLimit: storageLimit ?? this.storageLimit,
      plan: plan ?? this.plan,
      planCode: planCode ?? this.planCode,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionStartDate:
          subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      user: user ?? this.user,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
