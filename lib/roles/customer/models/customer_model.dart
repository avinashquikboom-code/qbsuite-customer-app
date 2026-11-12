import 'package:flutter/foundation.dart';
import 'lead_model.dart';

/// A Customer represents a client organization / account in QuikBoom CRM.
/// It can be created directly or converted from a Lead.
class CustomerModel {
  final String customerId;
  final String leadId;
  final String customerName;
  final String companyName;
  final String businessName;
  final String contactPerson;
  final String mobile;
  final String email;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String source;
  final String assignedEmployee;
  final String leadClosingDate;
  final String status;
  final String customerStatus;
  final String? leadStatus;
  final String? leadStageName;
  final String? leadStageColor;
  final String? planName;

  /// Subscription status from backend: 'ACTIVE', 'EXPIRED', 'NO_PLAN', 'PENDING', etc.
  final String? subscriptionStatus;

  /// ISO date strings for subscription start and end dates.
  final String? subscriptionStartDate;
  final String? subscriptionEndDate;

  final String notes;
  final double value;

  /// Upcoming Call metadata
  final bool hasUpcomingCall;
  final String? upcomingCallType;
  final String? upcomingCallDate;
  final String? upcomingCallTime;

  /// Upcoming commission for the logged-in employee (null or <= 0 if not eligible / none).
  final double? upcomingCommission;

  const CustomerModel({
    required this.customerId,
    required this.leadId,
    this.customerName = '',
    this.companyName = '',
    required this.businessName,
    required this.contactPerson,
    required this.mobile,
    required this.email,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.source,
    required this.assignedEmployee,
    required this.leadClosingDate,
    required this.status,
    this.customerStatus = 'ACTIVE',
    this.leadStatus,
    this.leadStageName,
    this.leadStageColor,
    this.planName,
    this.subscriptionStatus,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    required this.notes,
    required this.value,
    this.hasUpcomingCall = false,
    this.upcomingCallType,
    this.upcomingCallDate,
    this.upcomingCallTime,
    this.upcomingCommission,
  });

  /// Whether this customer was converted from a Lead
  bool get isConvertedFromLead =>
      leadId.isNotEmpty && leadId != '0' && leadId != 'null';

  /// Whether this customer has a currently active subscription.
  bool get isSubscriptionActive {
    final s = (subscriptionStatus ?? '').toUpperCase();
    return s == 'ACTIVE';
  }

  /// Formatted start date for display (dd/mm/yyyy or 'N/A')
  String get formattedStartDate => _formatDate(subscriptionStartDate);

  /// Formatted end date for display (dd/mm/yyyy or 'N/A')
  String get formattedEndDate => _formatDate(subscriptionEndDate);

  /// Effective display title: defaults to companyName if present, else businessName or customerName
  String get displayTitle {
    if (companyName.trim().isNotEmpty &&
        !companyName.trim().toLowerCase().contains('unnamed') &&
        !companyName.trim().toLowerCase().contains('no business name') &&
        companyName.trim().toLowerCase() != 'business lead') {
      return companyName.trim();
    }
    if (businessName.trim().isNotEmpty &&
        !businessName.trim().toLowerCase().contains('unnamed') &&
        !businessName.trim().toLowerCase().contains('no business name') &&
        businessName.trim().toLowerCase() != 'business lead') {
      return businessName.trim();
    }
    if (customerName.trim().isNotEmpty &&
        !customerName.trim().toLowerCase().contains('unnamed') &&
        !customerName.trim().toLowerCase().contains('no business name') &&
        customerName.trim().toLowerCase() != 'primary contact') {
      return customerName.trim();
    }
    if (contactPerson.trim().isNotEmpty &&
        !contactPerson.trim().toLowerCase().contains('unnamed') &&
        !contactPerson.trim().toLowerCase().contains('no business name') &&
        contactPerson.trim().toLowerCase() != 'primary contact') {
      return contactPerson.trim();
    }
    return companyName.isNotEmpty
        ? companyName
        : (businessName.isNotEmpty
              ? businessName
              : (customerName.isNotEmpty ? customerName : 'Customer'));
  }

  /// Effective display subtitle: shows customerName when companyName is the title, or companyName when customerName is the title
  String? get displaySubtitle {
    final title = displayTitle.trim().toLowerCase();
    if (customerName.trim().isNotEmpty &&
        customerName.trim().toLowerCase() != title &&
        customerName.trim().toLowerCase() != 'primary contact') {
      return customerName.trim();
    }
    if (companyName.trim().isNotEmpty &&
        companyName.trim().toLowerCase() != title) {
      return companyName.trim();
    }
    if (contactPerson.trim().isNotEmpty &&
        contactPerson.trim().toLowerCase() != title &&
        contactPerson.trim().toLowerCase() != 'primary contact') {
      return contactPerson.trim();
    }
    return null;
  }

  /// Parse CustomerModel from API JSON payload.
  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    final rawCustStatus = (json['customerStatus'] ?? json['status'] ?? 'ACTIVE')
        .toString()
        .toUpperCase();
    final custStatus =
        ['ACTIVE', 'UPCOMING', 'COMPLETED', 'INACTIVE'].contains(rawCustStatus)
        ? rawCustStatus
        : (json['isActive'] == false ? 'INACTIVE' : 'ACTIVE');

    final rawCustomerName =
        (json['customerName'] ??
                json['contactFullName'] ??
                json['contactPerson'] ??
                '')
            .toString()
            .trim();
    final rawCompanyName =
        (json['companyName'] ?? json['company'] ?? json['workspaceName'] ?? '')
            .toString()
            .trim();
    final rawName = (json['name'] ?? json['businessName'] ?? '')
        .toString()
        .trim();
    final rawContact = (json['contactFullName'] ?? json['contactPerson'] ?? '')
        .toString()
        .trim();

    final cName =
        rawCustomerName.isNotEmpty &&
            rawCustomerName.toLowerCase() != 'primary contact'
        ? rawCustomerName
        : (rawContact.isNotEmpty &&
                  rawContact.toLowerCase() != 'primary contact'
              ? rawContact
              : (rawName.isNotEmpty ? rawName : 'Customer'));

    final compName = rawCompanyName.isNotEmpty
        ? rawCompanyName
        : (rawName.isNotEmpty && rawName.toLowerCase() != cName.toLowerCase()
              ? rawName
              : '');

    final bName = compName.isNotEmpty
        ? compName
        : (cName.isNotEmpty ? cName : 'Enterprise Client');
    final cPerson = cName.isNotEmpty
        ? cName
        : (rawContact.isNotEmpty ? rawContact : 'Primary Contact');

    final lStatus = json['leadStatus']?.toString();
    final lStage = json['leadStageName']?.toString();
    final lColor = json['leadStageColor']?.toString();

    final rawSubStatus = (json['subscriptionStatus'] ?? '')
        .toString()
        .toUpperCase();

    final upcomingCallMap = json['upcomingCall'] is Map<String, dynamic>
        ? json['upcomingCall'] as Map<String, dynamic>
        : null;
    final isFinalCall =
        lStatus?.toUpperCase() == 'FINAL_CALL' ||
        lStage?.toLowerCase().contains('final') == true;
    final isFollowUp =
        lStatus?.toUpperCase() == 'FOLLOW_UP' ||
        lStatus?.toUpperCase() == 'FOLLOWUP' ||
        lStage?.toLowerCase().contains('follow') == true;

    final explicitApiStatus =
        (json['customerStatus'] ?? json['status'])?.toString().toUpperCase();

    bool subscriptionVerifiedActive() {
      if (rawSubStatus != 'ACTIVE') return false;
      final endRaw = json['subscriptionEndDate'];
      if (endRaw == null || endRaw.toString().trim().isEmpty) return true;
      try {
        final end = DateTime.parse(endRaw.toString());
        return !end.isBefore(DateTime.now());
      } catch (_) {
        return true;
      }
    }

    final verifiedActiveSub = subscriptionVerifiedActive();
    final isSubActive = verifiedActiveSub;
    final explicitUpcoming = json['hasUpcomingCall'];

    final bool hasUpcoming = isSubActive
        ? false
        : (explicitApiStatus == 'UPCOMING' ||
              custStatus == 'UPCOMING' ||
              (explicitUpcoming == true));
    final upcomingType = isSubActive
        ? null
        : (json['upcomingCallType']?.toString() ??
              upcomingCallMap?['type']?.toString() ??
              (isFinalCall ? 'Final Call' : (isFollowUp ? 'Follow-up' : null)));
    final upcomingDate = isSubActive
        ? null
        : (json['upcomingCallDate']?.toString() ??
              upcomingCallMap?['formattedDate']?.toString() ??
              upcomingCallMap?['date']?.toString() ??
              (isFinalCall
                  ? 'Final Call Stage'
                  : (isFollowUp ? 'Follow-up Stage' : null)));
    final upcomingTime = isSubActive
        ? null
        : (json['upcomingCallTime']?.toString() ??
              upcomingCallMap?['formattedTime']?.toString() ??
              upcomingCallMap?['time']?.toString() ??
              ((isFinalCall || isFollowUp) ? '11:00 AM' : null));

    final String effectiveCustStatus;
    if (verifiedActiveSub) {
      effectiveCustStatus = 'ACTIVE';
    } else if (explicitApiStatus != null &&
        ['UPCOMING', 'INACTIVE', 'ACTIVE'].contains(explicitApiStatus)) {
      effectiveCustStatus =
          explicitApiStatus == 'ACTIVE' ? 'INACTIVE' : explicitApiStatus;
    } else if (['UPCOMING', 'INACTIVE', 'ACTIVE'].contains(custStatus)) {
      effectiveCustStatus = custStatus == 'ACTIVE' ? 'INACTIVE' : custStatus;
    } else {
      effectiveCustStatus = hasUpcoming ? 'UPCOMING' : 'INACTIVE';
    }

    // Parse Upcoming Commission (strict employee & active pending/approved status)
    double? parsedCommission;
    if (json['upcomingCommission'] != null) {
      final val = (json['upcomingCommission'] as num).toDouble();
      if (val > 0) parsedCommission = val;
    } else if (json['commission'] is Map<String, dynamic>) {
      final commMap = json['commission'] as Map<String, dynamic>;
      final status = (commMap['status'] ?? '').toString().toUpperCase();
      if (commMap['amount'] != null &&
          (status == 'UPCOMING' ||
              status == 'PENDING' ||
              status == 'APPROVED')) {
        final val = (commMap['amount'] as num).toDouble();
        if (val > 0) parsedCommission = val;
      }
    }

    final rawLeadId = (json['leadId'] ?? json['originLeadId'] ?? '')
        .toString()
        .trim();

    return CustomerModel(
      customerId: (json['customerId'] ?? 'CUST-${json['id'] ?? ''}').toString(),
      leadId: rawLeadId == 'null' ? '' : rawLeadId,
      customerName: cName,
      companyName: compName,
      businessName: bName,
      contactPerson: cPerson,
      mobile: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      pincode: (json['pincode'] ?? '').toString(),
      source: (json['source'] ?? 'DIRECT').toString(),
      assignedEmployee: (json['assignedEmployee'] ?? '').toString(),
      leadClosingDate: _formatDate((json['createdAt'] ?? '').toString()),
      status: effectiveCustStatus,
      customerStatus: effectiveCustStatus,
      leadStatus: lStatus,
      leadStageName: lStage,
      leadStageColor: lColor,
      planName: json['plan']?.toString() ?? json['planName']?.toString(),
      subscriptionStatus: rawSubStatus.isNotEmpty ? rawSubStatus : null,
      subscriptionStartDate: json['subscriptionStartDate']?.toString(),
      subscriptionEndDate: json['subscriptionEndDate']?.toString(),
      notes: (json['notes'] ?? '').toString(),
      value: (json['value'] != null) ? (json['value'] as num).toDouble() : 0.0,
      hasUpcomingCall: hasUpcoming,
      upcomingCallType: upcomingType,
      upcomingCallDate: upcomingDate,
      upcomingCallTime: upcomingTime,
      upcomingCommission: parsedCommission,
    );
  }

  /// Build a Customer from a closed Lead record.
  factory CustomerModel.fromLead(LeadModel lead) {
    debugPrint('''
[FROM LEAD DEBUG]

leadId: ${lead.id}
companyName: ${lead.companyName}
displayName: ${lead.displayName}
title: ${lead.title}
firstName: ${lead.firstName}
lastName: ${lead.lastName}
source: ${lead.source}
''');

    // 1. Authoritative business/company name:
    // If Lead has an actual companyName or businessName, preserve it without corruption.
    final rawCompany = lead.companyName?.trim() ?? '';
    final rawBiz = lead.businessName?.trim() ?? '';
    final resolvedBiz =
        (rawCompany.isNotEmpty && !LeadModel.isPlaceholder(rawCompany))
        ? rawCompany
        : ((rawBiz.isNotEmpty && !LeadModel.isPlaceholder(rawBiz))
              ? rawBiz
              : '');

    // 2. Genuine contact person (firstName + lastName)
    final validContact = lead.validContactPerson;

    // 3. Meaningful title fallback
    final rawTitle = lead.title.trim();
    final validTitle =
        (rawTitle.isNotEmpty && !LeadModel.isPlaceholder(rawTitle))
        ? rawTitle
        : '';

    // 4. Primary display name for customer entity:
    // Priority: real company name -> genuine contact person -> meaningful title -> empty
    final String resolvedDisplayName = resolvedBiz.isNotEmpty
        ? resolvedBiz
        : (validContact != null && validContact.isNotEmpty
              ? validContact
              : (validTitle.isNotEmpty ? validTitle : ''));

    final String finalCompanyName = resolvedBiz.isNotEmpty
        ? resolvedBiz
        : (validTitle.isNotEmpty ? validTitle : '');

    final String finalBusinessName = resolvedBiz.isNotEmpty
        ? resolvedBiz
        : (validTitle.isNotEmpty ? validTitle : '');

    // 5. Contact person field: genuine contact name if present, otherwise fallback to business/customer name
    final String finalContactPerson =
        (validContact != null && validContact.isNotEmpty)
        ? validContact
        : (resolvedBiz.isNotEmpty ? resolvedBiz : '');

    final isFinalCall =
        lead.status.toUpperCase() == 'FINAL_CALL' ||
        lead.stageName.toLowerCase().contains('final');
    final isFollowUp =
        lead.status.toUpperCase() == 'FOLLOW_UP' ||
        lead.status.toUpperCase() == 'FOLLOWUP' ||
        lead.stageName.toLowerCase().contains('follow');
    final hasNextFollowUp =
        lead.nextFollowUpDate != null &&
        lead.nextFollowUpDate!.trim().isNotEmpty;
    final isUpcomingLead = isFinalCall;

    final customer = CustomerModel(
      customerId: 'CUST-${lead.id}',
      leadId: lead.id,
      customerName: resolvedDisplayName,
      companyName: finalCompanyName,
      businessName: finalBusinessName,
      contactPerson: finalContactPerson,
      mobile: lead.phone ?? '',
      email: lead.email ?? '',
      address: lead.address ?? '',
      city: lead.city ?? '',
      state: lead.state ?? '',
      pincode: lead.pincode ?? '',
      source: lead.source,
      assignedEmployee: lead.assignedToName ?? '',
      leadClosingDate: _formatDate(lead.createdAt),
      status: isUpcomingLead ? 'UPCOMING' : 'INACTIVE',
      customerStatus: isUpcomingLead ? 'UPCOMING' : 'INACTIVE',
      leadStatus: lead.status,
      leadStageName: lead.stageName,
      leadStageColor: lead.stageColorHex ?? '#10B981',
      notes: lead.workNotes ?? '',
      value: lead.value,
      hasUpcomingCall: isUpcomingLead,
      upcomingCallType: isFinalCall
          ? 'Final Call'
          : (isFollowUp ? 'Follow-up' : (hasNextFollowUp ? 'Follow-up' : null)),
      upcomingCallDate:
          (lead.nextFollowUpDate != null &&
              lead.nextFollowUpDate!.trim().isNotEmpty)
          ? lead.nextFollowUpDate!
          : (isFinalCall
                ? 'Final Call Stage'
                : (isFollowUp ? 'Follow-up Stage' : null)),
      upcomingCallTime:
          (lead.nextFollowUpTime != null &&
              lead.nextFollowUpTime!.trim().isNotEmpty)
          ? lead.nextFollowUpTime!
          : (isUpcomingLead ? '11:00 AM' : null),
      upcomingCommission: null,
    );

    debugPrint('''
[NAME FLOW]

Data Capture businessName: ${lead.businessName ?? lead.companyName ?? 'N/A'}
Lead.companyName: ${lead.companyName ?? 'N/A'}
LeadModel.companyName: ${lead.companyName ?? 'N/A'}
CustomerModel.companyName: ${customer.companyName}
CustomerModel.customerName: ${customer.customerName}
CustomerModel.contactPerson: ${customer.contactPerson}
''');

    return customer;
  }

  /// Checks if the given lead qualifies as a customer (is closed/won).
  static bool isClosedLead(LeadModel lead) {
    final s = lead.status.toUpperCase();
    return s == 'WON' ||
        s == 'CONVERTED' ||
        s == 'WORK_STARTED' ||
        s == 'CLOSED';
  }

  static String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  /// Helper for searching customers
  bool matchesQuery(String query) {
    final q = query.toLowerCase();
    return businessName.toLowerCase().contains(q) ||
        customerName.toLowerCase().contains(q) ||
        companyName.toLowerCase().contains(q) ||
        contactPerson.toLowerCase().contains(q) ||
        mobile.contains(q) ||
        email.toLowerCase().contains(q) ||
        city.toLowerCase().contains(q) ||
        (leadStatus?.toLowerCase().contains(q) ?? false) ||
        (leadStageName?.toLowerCase().contains(q) ?? false) ||
        (planName?.toLowerCase().contains(q) ?? false) ||
        (upcomingCallType?.toLowerCase().contains(q) ?? false) ||
        (upcomingCallDate?.toLowerCase().contains(q) ?? false);
  }
}
