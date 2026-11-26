import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../network/api_client.dart';
import '../network/app_url.dart';

final appleIapServiceProvider = Provider<AppleIapService>((ref) {
  return AppleIapService(ApiClient().dio);
});

enum AppleIapStatus {
  pending,
  processing,
  success,
  failed,
  cancelled,
}

class AppleIapResult {
  final AppleIapStatus status;
  final String? transactionId;
  final String? productId;
  final String? receiptNumber;
  final String? message;
  final double? amount;
  final DateTime? timestamp;
  final Map<String, dynamic>? backendData;

  const AppleIapResult({
    required this.status,
    this.transactionId,
    this.productId,
    this.receiptNumber,
    this.message,
    this.amount,
    this.timestamp,
    this.backendData,
  });

  bool get isSuccess => status == AppleIapStatus.success;
}

class AppleIapService {
  AppleIapService(this._dio);

  final Dio _dio;
  static const String defaultBundleId = 'com.qbsuite.qbCustomer';

  bool _isPurchaseInProgress = false;

  static String planProductId(String planCodeOrId, String billingCycle) {
    final slug = planCodeOrId
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final cycle = billingCycle.toUpperCase() == 'YEARLY' ? 'yearly' : 'monthly';
    return '$defaultBundleId.plan.$slug.$cycle';
  }

  static String creditPackProductId(int credits) {
    return '$defaultBundleId.aicredits.$credits';
  }

  /// Fetches server-defined App Store product mappings when available.
  Future<Map<String, dynamic>> fetchProductCatalog() async {
    try {
      final response = await _dio.get(AppUrl.appleIapProducts);
      if (response.data is Map<String, dynamic>) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      debugPrint('[APPLE_IAP_CATALOG_WARN] $e');
    }
    return const {};
  }

  /// Initiates a StoreKit 2 purchase on iOS and verifies the signed transaction on the backend.
  Future<AppleIapResult> purchaseProduct({
    required String productId,
    required String purchaseType, // 'SUBSCRIPTION' or 'AI_CREDITS'
    dynamic planId,
    String billingCycle = 'MONTHLY',
    int? credits,
    String? activationDate,
    void Function(AppleIapStatus status, String message)? onStateChanged,
  }) async {
    if (!Platform.isIOS) {
      return const AppleIapResult(
        status: AppleIapStatus.failed,
        message: 'Apple In-App Purchase is only supported on iOS devices.',
      );
    }

    if (_isPurchaseInProgress) {
      return const AppleIapResult(
        status: AppleIapStatus.failed,
        message: 'A payment is already in progress. Please wait.',
      );
    }

    _isPurchaseInProgress = true;
    StreamSubscription<List<PurchaseDetails>>? subscription;
    final completer = Completer<AppleIapResult>();

    try {
      final iap = InAppPurchase.instance;
      final available = await iap.isAvailable();
      if (!available) {
        return const AppleIapResult(
          status: AppleIapStatus.failed,
          message: 'App Store purchases are unavailable on this device.',
        );
      }

      onStateChanged?.call(
        AppleIapStatus.processing,
        'Loading App Store product details...',
      );

      final response = await iap.queryProductDetails({productId});
      if (response.error != null) {
        return AppleIapResult(
          status: AppleIapStatus.failed,
          productId: productId,
          message: response.error!.message,
        );
      }

      if (response.productDetails.isEmpty) {
        return AppleIapResult(
          status: AppleIapStatus.failed,
          productId: productId,
          message:
              'Product "$productId" is not configured in App Store Connect.',
        );
      }

      final product = response.productDetails.first;

      subscription = iap.purchaseStream.listen(
        (purchases) async {
          for (final purchase in purchases) {
            if (purchase.productID != productId) continue;

            if (purchase.status == PurchaseStatus.pending) {
              onStateChanged?.call(
                AppleIapStatus.pending,
                'Awaiting App Store approval...',
              );
              continue;
            }

            if (purchase.status == PurchaseStatus.canceled) {
              if (purchase.pendingCompletePurchase) {
                await iap.completePurchase(purchase);
              }
              if (!completer.isCompleted) {
                completer.complete(
                  AppleIapResult(
                    status: AppleIapStatus.cancelled,
                    productId: productId,
                    message: 'Purchase was cancelled.',
                  ),
                );
              }
              return;
            }

            if (purchase.status == PurchaseStatus.error) {
              if (purchase.pendingCompletePurchase) {
                await iap.completePurchase(purchase);
              }
              if (!completer.isCompleted) {
                completer.complete(
                  AppleIapResult(
                    status: AppleIapStatus.failed,
                    productId: productId,
                    message:
                        purchase.error?.message ??
                        'App Store payment failed. Please try again.',
                  ),
                );
              }
              return;
            }

            if (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored) {
              onStateChanged?.call(
                AppleIapStatus.processing,
                'Verifying purchase securely with server...',
              );

              try {
                final verified = await _verifyOnBackend(
                  purchase: purchase,
                  purchaseType: purchaseType,
                  planId: planId,
                  billingCycle: billingCycle,
                  credits: credits,
                  activationDate: activationDate,
                );

                // Only finish StoreKit transaction after backend verification succeeds
                if (purchase.pendingCompletePurchase) {
                  await iap.completePurchase(purchase);
                }

                if (!completer.isCompleted) {
                  completer.complete(
                    AppleIapResult(
                      status: AppleIapStatus.success,
                      transactionId:
                          verified['transactionId']?.toString() ??
                          purchase.purchaseID,
                      productId: productId,
                      receiptNumber: verified['receiptNumber']?.toString(),
                      amount: product.rawPrice,
                      timestamp: DateTime.now(),
                      message: 'Payment verified and activated.',
                      backendData: verified,
                    ),
                  );
                }
              } catch (err) {
                if (!completer.isCompleted) {
                  completer.complete(
                    AppleIapResult(
                      status: AppleIapStatus.failed,
                      productId: productId,
                      transactionId: purchase.purchaseID,
                      message:
                          'Server verification failed: ${err.toString().replaceFirst('Exception: ', '')}',
                    ),
                  );
                }
              }
              return;
            }
          }
        },
        onError: (Object err) {
          if (!completer.isCompleted) {
            completer.complete(
              AppleIapResult(
                status: AppleIapStatus.failed,
                productId: productId,
                message: 'App Store stream error: $err',
              ),
            );
          }
        },
      );

      final purchaseParam = PurchaseParam(productDetails: product);
      final started = purchaseType == 'AI_CREDITS'
          ? await iap.buyConsumable(purchaseParam: purchaseParam)
          : await iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!started && !completer.isCompleted) {
        completer.complete(
          AppleIapResult(
            status: AppleIapStatus.failed,
            productId: productId,
            message: 'Unable to initiate App Store checkout.',
          ),
        );
      }

      return await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => AppleIapResult(
          status: AppleIapStatus.pending,
          productId: productId,
          message:
              'Payment confirmation timed out. If charged, use Restore Purchases or check Payment History.',
        ),
      );
    } catch (e) {
      return AppleIapResult(
        status: AppleIapStatus.failed,
        productId: productId,
        message: 'Payment initialization error: $e',
      );
    } finally {
      await subscription?.cancel();
      _isPurchaseInProgress = false;
    }
  }

  Future<Map<String, dynamic>> _verifyOnBackend({
    required PurchaseDetails purchase,
    required String purchaseType,
    dynamic planId,
    required String billingCycle,
    int? credits,
    String? activationDate,
  }) async {
    final txId =
        purchase.purchaseID ?? 'apple_${DateTime.now().millisecondsSinceEpoch}';
    final signedData = purchase.verificationData.serverVerificationData;

    final response = await _dio.post(
      AppUrl.appleIapVerify,
      data: {
        'productId': purchase.productID,
        'transactionId': txId,
        'signedTransactionInfo': signedData,
        'purchaseType': purchaseType,
        'planId': ?planId,
        'billingCycle': billingCycle,
        'credits': ?credits,
        if (activationDate != null && activationDate.isNotEmpty)
          'activationDate': activationDate,
      },
    );

    final body = response.data;
    if (body is Map<String, dynamic> && body['success'] == true) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body;
    }

    throw Exception(
      (body is Map ? body['message']?.toString() : null) ??
          'Backend rejected Apple transaction verification.',
    );
  }

  /// Restores previous non-consumable/subscription App Store purchases and syncs with backend.
  Future<void> restorePurchases() async {
    if (!Platform.isIOS) return;
    await InAppPurchase.instance.restorePurchases();
  }
}
