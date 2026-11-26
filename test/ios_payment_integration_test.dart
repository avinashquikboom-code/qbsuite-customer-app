import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/services/apple_iap_service.dart';
import 'package:quickboom_crm_customer/core/services/razorpay_checkout_service.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/payment_status_view.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('AppleIapService builds deterministic App Store product IDs', () {
    expect(
      AppleIapService.planProductId('Growth Pro', 'MONTHLY'),
      'com.qbsuite.qbCustomer.plan.growth_pro.monthly',
    );
    expect(
      AppleIapService.planProductId('ENTERPRISE', 'YEARLY'),
      'com.qbsuite.qbCustomer.plan.enterprise.yearly',
    );
    expect(
      AppleIapService.creditPackProductId(25),
      'com.qbsuite.qbCustomer.aicredits.25',
    );
  });

  test('RazorpayPaymentResult classifies cancelled, pending, and failed states', () {
    final cancelled = RazorpayPaymentResult.failure(
      errorMessage: 'Payment cancelled by user',
      errorCode: Razorpay.PAYMENT_CANCELLED,
    );
    expect(cancelled.isCancelled, isTrue);
    expect(cancelled.status, RazorpayPaymentStatus.cancelled);

    final pending = RazorpayPaymentResult.failure(
      errorMessage: 'External wallet payment is being processed.',
      errorCode: 2,
    );
    expect(pending.isPending, isTrue);
    expect(pending.status, RazorpayPaymentStatus.pending);

    final failed = RazorpayPaymentResult.failure(
      errorMessage: 'Network error occurred',
      errorCode: Razorpay.NETWORK_ERROR,
    );
    expect(failed.status, RazorpayPaymentStatus.failed);
  });

  testWidgets('PaymentStatusView renders success state with receipt and metadata', (
    tester,
  ) async {
    var receiptTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentStatusView(
          state: PaymentUiState.success,
          title: 'Subscription Activated',
          message: 'Verified on server.',
          transactionId: 'APPLE-TX-991',
          receiptNumber: 'REC-2026-000123',
          amount: 1499.0,
          paymentMethod: 'Apple In-App Purchase (StoreKit 2)',
          onViewReceipt: () => receiptTapped = true,
          onDone: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Subscription Activated'), findsOneWidget);
    expect(find.text('APPLE-TX-991'), findsOneWidget);
    expect(find.text('REC-2026-000123'), findsOneWidget);
    expect(find.text('₹1499.00'), findsOneWidget);
    await tester.ensureVisible(find.text('View Receipt'));
    await tester.tap(find.text('View Receipt'));
    expect(receiptTapped, isTrue);
  });
}
