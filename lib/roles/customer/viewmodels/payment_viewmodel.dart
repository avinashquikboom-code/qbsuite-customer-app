import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/roles/customer/models/payment_model.dart';

import 'package:quickboom_crm_customer/roles/customer/viewmodels/current_customer_viewmodel.dart';

final paymentsProvider =
    NotifierProvider<PaymentsViewModel, List<PaymentModel>>(() {
      return PaymentsViewModel();
    });

class PaymentsViewModel extends Notifier<List<PaymentModel>> {
  @override
  List<PaymentModel> build() {
    final customerIdAsync = ref.watch(currentCustomerIdProvider);
    final cid = (customerIdAsync.asData?.value ?? customerIdAsync.value ?? '')
        .toUpperCase();
    return _mockPayments()
        .where((p) => p.customerId.toUpperCase() == cid || cid.isEmpty)
        .toList();
  }

  List<PaymentModel> _mockPayments() {
    return [
      const PaymentModel(
        id: 'pay-cf-001',
        paymentNo: 'REC-2026-CF1',
        customerId: 'T001',
        clientName: 'Care Fitness Gym',
        dealTitle: 'Growth Package Subscription',
        totalAmount: 41300.0,
        paidAmount: 41300.0,
        pendingAmount: 0.0,
        method: 'BANK_TRANSFER',
        reference: 'NEFT-991823719',
        date: '15 Aug 2026',
        status: 'PAID',
        notes: 'Monthly growth plan payment received via bank transfer.',
        createdAt: '2026-08-15T10:00:00.000Z',
      ),
      const PaymentModel(
        id: 'pay-abc-001',
        paymentNo: 'REC-2026-ABC1',
        customerId: 'T002',
        clientName: 'ABC Fitness',
        dealTitle: 'Pro Video Production Retainer',
        totalAmount: 59000.0,
        paidAmount: 30000.0,
        pendingAmount: 29000.0,
        method: 'RAZORPAY',
        reference: 'pay_ABC987216',
        date: '16 Aug 2026',
        status: 'PARTIAL',
        notes: '50% advance received for crossfit video campaign.',
        createdAt: '2026-08-16T10:00:00.000Z',
      ),
      const PaymentModel(
        id: 'pay-001',
        paymentNo: 'REC-2026-089',
        customerId: 'CUST-TCS',
        clientName: 'Tata Consultancy Services',
        dealTitle: 'Enterprise CRM Suite Onboarding',
        totalAmount: 100300.0,
        paidAmount: 100300.0,
        pendingAmount: 0.0,
        method: 'BANK_TRANSFER',
        reference: 'NEFT-889201948',
        date: '16 Aug 2026',
        status: 'PAID',
        notes: 'Full payment received via NEFT corporate banking.',
        createdAt: '2026-08-16T10:00:00.000Z',
      ),
    ];
  }

  void addPayment(PaymentModel payment) {
    state = [payment, ...state];
  }

  void updatePayment(PaymentModel payment) {
    state = [
      for (final p in state)
        if (p.id == payment.id) payment else p,
    ];
  }

  void deletePayment(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void updateStatus(String id, String status) {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(status: status) else p,
    ];
  }

  String get nextReceiptNo {
    final count = state.length + 1;
    return 'REC-2026-${(89 + count).toString().padLeft(3, '0')}';
  }

  double get totalCollected => state.fold(0.0, (sum, p) => sum + p.paidAmount);

  double get totalPending => state.fold(0.0, (sum, p) => sum + p.pendingAmount);

  double get totalVolume => state.fold(0.0, (sum, p) => sum + p.totalAmount);
}
