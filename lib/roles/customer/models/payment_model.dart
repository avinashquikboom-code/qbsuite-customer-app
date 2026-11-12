/// Deal payment transaction model representing payments recorded for closed deals and proposals.
class PaymentModel {
  final String id;
  final String paymentNo;
  final String customerId;
  final String leadId;
  final String clientName;
  final String dealTitle;
  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final String method; // BANK_TRANSFER, UPI, RAZORPAY, CASH, CHEQUE
  final String reference;
  final String date;
  final String status; // PAID, PARTIAL, PENDING, FAILED
  final String? notes;
  final String createdAt;

  const PaymentModel({
    required this.id,
    required this.paymentNo,
    this.customerId = '',
    this.leadId = '',
    required this.clientName,
    required this.dealTitle,
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.method,
    required this.reference,
    required this.date,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  double get progressRatio =>
      totalAmount > 0 ? (paidAmount / totalAmount).clamp(0.0, 1.0) : 0.0;
  int get progressPercent => (progressRatio * 100).round();

  String get formattedTotal => '₹${totalAmount.toStringAsFixed(0)}';
  String get formattedPaid => '₹${paidAmount.toStringAsFixed(0)}';
  String get formattedPending => '₹${pendingAmount.toStringAsFixed(0)}';

  String get methodLabel {
    switch (method.toUpperCase()) {
      case 'BANK_TRANSFER':
      case 'NEFT':
      case 'RTGS':
        return 'Bank Transfer (NEFT/RTGS)';
      case 'UPI':
        return 'UPI / GPay';
      case 'RAZORPAY':
        return 'Razorpay Gateway';
      case 'CASH':
        return 'Cash Receipt';
      case 'CHEQUE':
        return 'Cheque Deposit';
      default:
        return method.replaceAll('_', ' ');
    }
  }

  PaymentModel copyWith({
    String? id,
    String? paymentNo,
    String? customerId,
    String? leadId,
    String? clientName,
    String? dealTitle,
    double? totalAmount,
    double? paidAmount,
    double? pendingAmount,
    String? method,
    String? reference,
    String? date,
    String? status,
    String? notes,
    String? createdAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      paymentNo: paymentNo ?? this.paymentNo,
      customerId: customerId ?? this.customerId,
      leadId: leadId ?? this.leadId,
      clientName: clientName ?? this.clientName,
      dealTitle: dealTitle ?? this.dealTitle,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      method: method ?? this.method,
      reference: reference ?? this.reference,
      date: date ?? this.date,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
