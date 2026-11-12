class InvoiceLineItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final double total;

  const InvoiceLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    final quantity = (json['quantity'] as num?)?.toInt() ?? 1;
    final unitPrice = (json['unitPrice'] as num?)?.toDouble() ?? 0.0;
    final total = (json['total'] as num?)?.toDouble() ?? (unitPrice * quantity);
    return InvoiceLineItem(
      name:
          json['name']?.toString() ?? json['description']?.toString() ?? 'Item',
      quantity: quantity < 1 ? 1 : quantity,
      unitPrice: unitPrice,
      total: total,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'total': total,
  };
}

class CustomerInvoice {
  final String id;
  final String invoiceNumber;
  final String clientName;
  final DateTime issueDate;
  final DateTime? activationDate;
  final DateTime? expiryDate;
  final DateTime? dueDate;
  final double totalAmount;
  final double subTotal;
  final double taxAmount;
  final double discount;
  final String status;
  final String? notes;
  final String? planName;
  final String? planType;
  final bool hasAgreement;
  final List<InvoiceLineItem> lineItems;

  const CustomerInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.clientName,
    required this.issueDate,
    this.activationDate,
    this.expiryDate,
    this.dueDate,
    required this.totalAmount,
    required this.subTotal,
    required this.taxAmount,
    this.discount = 0,
    required this.status,
    this.notes,
    this.planName,
    this.planType,
    this.hasAgreement = false,
    this.lineItems = const [],
  });

  bool get isPaid => status.toUpperCase() == 'PAID';

  static DateTime? _parseCalendarDate(dynamic raw) {
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return null;
    final u = parsed.toUtc();
    return DateTime(u.year, u.month, u.day);
  }

  static List<InvoiceLineItem> _parseLineItems(Map<String, dynamic> json) {
    final raw = json['lineItems'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => InvoiceLineItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.name.isNotEmpty)
        .toList();
  }

  factory CustomerInvoice.fromJson(Map<String, dynamic> json) {
    final amt =
        (json['totalAmount'] as num?)?.toDouble() ??
        (double.tryParse(
              json['amount']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ??
                  '',
            ) ??
            0.0);
    final sub = (json['subTotal'] as num?)?.toDouble() ?? (amt / 1.18);
    final tax = (json['taxAmount'] as num?)?.toDouble() ?? (amt - sub);
    final discount = (json['discount'] as num?)?.toDouble() ?? 0.0;

    return CustomerInvoice(
      id: json['id']?.toString() ?? '',
      invoiceNumber:
          json['invoiceNumber']?.toString() ??
          json['invoiceNo']?.toString() ??
          'INV-${json['id']}',
      clientName: json['clientName']?.toString() ?? 'Customer Account',
      issueDate:
          DateTime.tryParse(json['issueDate']?.toString() ?? '') ??
          DateTime.now(),
      activationDate: _parseCalendarDate(
        json['activationDate'] ??
            json['planStartDate'] ??
            json['subscriptionStartDate'],
      ),
      expiryDate: _parseCalendarDate(json['expiryDate'] ?? json['planEndDate']),
      dueDate: DateTime.tryParse(json['dueDate']?.toString() ?? ''),
      totalAmount: amt,
      subTotal: sub,
      taxAmount: tax,
      discount: discount,
      status: json['status']?.toString() ?? 'PAID',
      notes: json['notes']?.toString(),
      planName: json['planName']?.toString(),
      planType: json['planType']?.toString(),
      hasAgreement:
          json['hasAgreement'] == true ||
          (json['status']?.toString().toUpperCase() == 'PAID' &&
              json['hasAgreement'] != false),
      lineItems: _parseLineItems(json),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'invoiceNumber': invoiceNumber,
    'clientName': clientName,
    'issueDate': issueDate.toIso8601String(),
    'activationDate': activationDate?.toIso8601String(),
    'expiryDate': expiryDate?.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'totalAmount': totalAmount,
    'subTotal': subTotal,
    'taxAmount': taxAmount,
    'discount': discount,
    'status': status,
    'notes': notes,
    'planName': planName,
    'planType': planType,
    'lineItems': lineItems.map((e) => e.toJson()).toList(),
  };
}
