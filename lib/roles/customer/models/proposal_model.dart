/// A Proposal links a Customer to a set of items (optionally loaded from a Package).
/// Relationship: Customer → Proposal → ProposalItems → (optional) Package
class ProposalModel {
  final String id;
  final String proposalNo;
  final String customerId;
  final String leadId;

  // Customer snapshot (auto-filled from CustomerModel)
  final String customerName;
  final String contactPerson;
  final String mobile;
  final String email;

  // Dates
  final String date;
  final String? packageStartDate;
  final String? packageEndDate;

  // Items
  final List<ProposalItemModel> items;

  // Financials
  final double subtotal;
  final double discount;
  final double gstPercent;
  final double gstAmount;
  final double netTotal;

  final String? notes;
  final String status; // DRAFT, SENT, ACCEPTED, NEGOTIATION, REJECTED
  final String createdAt;

  const ProposalModel({
    required this.id,
    required this.proposalNo,
    required this.customerId,
    required this.leadId,
    required this.customerName,
    required this.contactPerson,
    required this.mobile,
    required this.email,
    required this.date,
    this.packageStartDate,
    this.packageEndDate,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.gstPercent,
    required this.gstAmount,
    required this.netTotal,
    this.notes,
    required this.status,
    required this.createdAt,
  });

  /// Returns the formatted amount with currency symbol
  String get formattedTotal => '₹${netTotal.toStringAsFixed(0)}';

  /// Convenience display for proposal card
  String get serviceDescription {
    if (items.isEmpty) return 'Custom Proposal';
    return items.map((e) => e.name).take(3).join(', ');
  }

  ProposalModel copyWith({
    String? id,
    String? proposalNo,
    String? customerId,
    String? leadId,
    String? customerName,
    String? contactPerson,
    String? mobile,
    String? email,
    String? date,
    String? packageStartDate,
    String? packageEndDate,
    List<ProposalItemModel>? items,
    double? subtotal,
    double? discount,
    double? gstPercent,
    double? gstAmount,
    double? netTotal,
    String? notes,
    String? status,
    String? createdAt,
  }) {
    return ProposalModel(
      id: id ?? this.id,
      proposalNo: proposalNo ?? this.proposalNo,
      customerId: customerId ?? this.customerId,
      leadId: leadId ?? this.leadId,
      customerName: customerName ?? this.customerName,
      contactPerson: contactPerson ?? this.contactPerson,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      date: date ?? this.date,
      packageStartDate: packageStartDate ?? this.packageStartDate,
      packageEndDate: packageEndDate ?? this.packageEndDate,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      gstPercent: gstPercent ?? this.gstPercent,
      gstAmount: gstAmount ?? this.gstAmount,
      netTotal: netTotal ?? this.netTotal,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ProposalItemModel {
  final String id;
  final String name;
  final int quantity;
  final String planType;
  final double unitPrice;

  const ProposalItemModel({
    required this.id,
    required this.name,
    required this.quantity,
    required this.planType,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  ProposalItemModel copyWith({
    String? id,
    String? name,
    int? quantity,
    String? planType,
    double? unitPrice,
  }) {
    return ProposalItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      planType: planType ?? this.planType,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}
