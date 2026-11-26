import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../network/app_url.dart';

final razorpayCheckoutServiceProvider = Provider<RazorpayCheckoutService>((
  ref,
) {
  return RazorpayCheckoutService();
});

enum RazorpayPaymentStatus {
  success,
  cancelled,
  failed,
  pending,
}

class RazorpayPaymentResult {
  final bool isSuccess;
  final RazorpayPaymentStatus status;
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
       status = RazorpayPaymentStatus.success,
       errorMessage = null,
       errorCode = null;

  RazorpayPaymentResult.failure({
    required this.errorMessage,
    this.errorCode,
    RazorpayPaymentStatus? status,
  }) : isSuccess = false,
       status = status ?? _inferStatus(errorMessage, errorCode),
       paymentId = null,
       orderId = null,
       signature = null;

  bool get isCancelled => status == RazorpayPaymentStatus.cancelled;
  bool get isPending => status == RazorpayPaymentStatus.pending;

  static RazorpayPaymentStatus _inferStatus(String? message, int? code) {
    final msg = (message ?? '').toLowerCase();
    if (msg.contains('external wallet') || msg.contains('being processed')) {
      return RazorpayPaymentStatus.pending;
    }
    if (code == Razorpay.PAYMENT_CANCELLED ||
        msg.contains('cancel') ||
        msg.contains('dismiss')) {
      return RazorpayPaymentStatus.cancelled;
    }
    return RazorpayPaymentStatus.failed;
  }
}

class RazorpayCheckoutService {
  bool _isCheckoutOpen = false;

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
    if (_isCheckoutOpen) {
      return RazorpayPaymentResult.failure(
        errorMessage: 'A payment checkout session is already open.',
        status: RazorpayPaymentStatus.failed,
      );
    }

    _isCheckoutOpen = true;
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
              paymentId: response.paymentId,
              orderId: response.orderId ?? orderId,
              signature: response.signature,
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
        if (!completer.isCompleted) {
          final isCancel =
              response.code == Razorpay.PAYMENT_CANCELLED ||
              (response.message ?? '').toLowerCase().contains('cancel');
          completer.complete(
            RazorpayPaymentResult.failure(
              errorMessage:
                  response.message ??
                  (isCancel
                      ? 'Payment was cancelled by user.'
                      : 'Payment failed. Please try again.'),
              errorCode: response.code,
              status: isCancel
                  ? RazorpayPaymentStatus.cancelled
                  : RazorpayPaymentStatus.failed,
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
        if (!completer.isCompleted) {
          completer.complete(
            RazorpayPaymentResult.failure(
              errorMessage:
                  'External wallet payment (${response.walletName ?? 'wallet'}) is being processed. Your booking/plan will update once confirmed.',
              errorCode: 2,
              status: RazorpayPaymentStatus.pending,
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
              status: RazorpayPaymentStatus.failed,
            ),
          );
        }
      } else {
        final options = <String, dynamic>{
          'key': keyId,
          'amount': amountInPaise,
          'name': businessName.isNotEmpty ? businessName : 'QB Suite',
          'description': planName,
          'order_id': orderId,
          'timeout': 300,
          'retry': {'enabled': true, 'max_count': 2},
          'prefill': {
            'contact': customerPhone ?? '',
            'email': customerEmail ?? '',
          },
          'theme': {'color': '#0F172A'},
          if (Platform.isAndroid) 'send_sms_hash': true,
          if (Platform.isIOS)
            'external': {
              'wallets': ['paytm', 'phonepe', 'gpay'],
            },
        };

        debugPrint(
          '[RAZORPAY_OPEN] platform=${Platform.operatingSystem} orderId=$orderId amount=$amountInPaise',
        );
        razorpay.open(options);
      }
    } on MissingPluginException catch (e) {
      debugPrint(
        '[RAZORPAY_PLUGIN_MISSING] Razorpay native plugin unavailable: $e',
      );
      if (!completer.isCompleted) {
        completer.complete(
          RazorpayPaymentResult.failure(
            errorMessage:
                'Payment gateway plugin is not available on this device.',
            status: RazorpayPaymentStatus.failed,
          ),
        );
      }
    } catch (e) {
      debugPrint('[RAZORPAY_EXCEPTION] Failed to open Razorpay: $e');
      if (!completer.isCompleted) {
        completer.complete(
          RazorpayPaymentResult.failure(
            errorMessage: 'Failed to launch payment sheet: $e',
            status: RazorpayPaymentStatus.failed,
          ),
        );
      }
    }

    try {
      return await completer.future.timeout(
        const Duration(minutes: 6),
        onTimeout: () => RazorpayPaymentResult.failure(
          errorMessage:
              'Payment session timed out. If amount was debited, check Payment History.',
          status: RazorpayPaymentStatus.pending,
        ),
      );
    } finally {
      razorpay?.clear();
      _isCheckoutOpen = false;
    }
  }

  /// Checks authoritative backend payment status when confirmation is delayed.
  Future<Map<String, dynamic>?> checkPaymentStatus(
    Dio dio, {
    String? orderId,
    String? paymentId,
  }) async {
    try {
      final response = await dio.get(
        AppUrl.paymentStatus,
        queryParameters: {
          if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
          if (paymentId != null && paymentId.isNotEmpty) 'paymentId': paymentId,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data['data'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('[PAYMENT_STATUS_CHECK_ERROR] $e');
    }
    return null;
  }
}
