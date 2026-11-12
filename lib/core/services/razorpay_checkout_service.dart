import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

final razorpayCheckoutServiceProvider = Provider<RazorpayCheckoutService>((
  ref,
) {
  return RazorpayCheckoutService();
});

class RazorpayPaymentResult {
  final bool isSuccess;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? errorMessage;
  final int? errorCode;

  RazorpayPaymentResult.success({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  }) : isSuccess = true,
       errorMessage = null,
       errorCode = null;

  RazorpayPaymentResult.failure({required this.errorMessage, this.errorCode})
    : isSuccess = false,
      paymentId = null,
      orderId = null,
      signature = null;
}

class RazorpayCheckoutService {
  /// Opens the native Razorpay checkout sheet and waits for payment success/error callback.
  Future<RazorpayPaymentResult> openCheckout({
    required String keyId,
    required String orderId,
    required int amountInPaise,
    required String planName,
    required String businessName,
    String? customerEmail,
    String? customerPhone,
  }) async {
    final completer = Completer<RazorpayPaymentResult>();
    Razorpay? razorpay;

    try {
      razorpay = Razorpay();

      razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (
        PaymentSuccessResponse response,
      ) {
        debugPrint(
          '[RAZORPAY_SUCCESS] paymentId=${response.paymentId} orderId=${response.orderId}',
        );
        if (!completer.isCompleted) {
          completer.complete(
            RazorpayPaymentResult.success(
              paymentId:
                  response.paymentId ??
                  'pay_${DateTime.now().millisecondsSinceEpoch}',
              orderId: response.orderId ?? orderId,
              signature:
                  response.signature ??
                  'SIG_${DateTime.now().millisecondsSinceEpoch}',
            ),
          );
        }
      });

      razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (
        PaymentFailureResponse response,
      ) {
        debugPrint(
          '[RAZORPAY_FAILURE] code=${response.code} message=${response.message}',
        );
        debugPrint(
          '[RAZORPAY_ERROR] code=${response.code} message=${response.message}',
        );
        if (!completer.isCompleted) {
          completer.complete(
            RazorpayPaymentResult.failure(
              errorMessage:
                  response.message ?? 'Payment was cancelled or failed.',
              errorCode: response.code,
            ),
          );
        }
      });

      razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (
        ExternalWalletResponse response,
      ) {
        debugPrint(
          '[RAZORPAY_EXTERNAL_WALLET] walletName=${response.walletName}',
        );
        // External wallet payments do not return a Razorpay signature at checkout time.
        // The subscription will be activated via the Razorpay webhook (payment.captured event)
        // once the payment is confirmed by the wallet provider.
        if (!completer.isCompleted) {
          completer.complete(
            RazorpayPaymentResult.failure(
              errorMessage:
                  'External wallet payment is being processed. '
                  'Your plan will activate automatically once the payment is confirmed.',
              errorCode: 2, // External wallet code
            ),
          );
        }
      });

      if (keyId.isEmpty) {
        if (!completer.isCompleted) {
          completer.complete(
            RazorpayPaymentResult.failure(
              errorMessage:
                  'Payment gateway is not configured. Please contact support.',
            ),
          );
        }
      } else {
        final options = {
          'key': keyId,
          'amount': amountInPaise,
          'name': businessName.isNotEmpty ? businessName : 'QB Suite Marketing',
          'description': 'Subscription - $planName',
          'order_id': orderId,
          'prefill': {
            'contact': customerPhone ?? '',
            'email': customerEmail ?? '',
          },
          'theme': {'color': '#0F172A'},
          'send_sms_hash': true,
        };

        debugPrint(
          '[RAZORPAY_OPEN] orderId=$orderId amount=$amountInPaise keyId=$keyId',
        );
        razorpay.open(options);
      } // end else (keyId not empty)
    } on MissingPluginException catch (e) {
      // Razorpay native plugin not available (test runner / mock environment).
      // Do NOT auto-approve with a fake signature — no real payment occurred.
      debugPrint(
        '[RAZORPAY_PLUGIN_MISSING] Razorpay native plugin unavailable: $e',
      );
      if (!completer.isCompleted) {
        completer.complete(
          RazorpayPaymentResult.failure(
            errorMessage:
                'Payment gateway is not available in this environment.',
          ),
        );
      }
    } catch (e) {
      debugPrint('[RAZORPAY_EXCEPTION] Failed to open Razorpay: $e');
      if (!completer.isCompleted) {
        completer.complete(
          RazorpayPaymentResult.failure(
            errorMessage: 'Could not open payment gateway: $e',
          ),
        );
      }
    }

    final result = await completer.future;
    try {
      razorpay?.clear();
    } catch (_) {}

    return result;
  }
}
