import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import '../models/marketing_banner_model.dart';
import '../services/customer_marketing_service.dart';

/// Dynamic home banners notifier providing `AsyncValue<List<MarketingBannerModel>>`
class CustomerHomeBannersNotifier
    extends AsyncNotifier<List<MarketingBannerModel>> {
  @override
  Future<List<MarketingBannerModel>> build() async {
    final loginState = ref.watch(loginStateProvider);
    final customerId = loginState.customerId;

    if (loginState.isInitializing) {
      await ref.read(apiClientProvider).ensureAuthLoaded();
    }

    final service = ref.watch(customerMarketingServiceProvider);
    try {
      final banners = await service.getHomeBanners();

      debugPrint('[HOME_BANNER_PROVIDER]');
      debugPrint('customerId: $customerId');
      debugPrint('count: ${banners.length}');
      debugPrint('status: ${banners.isNotEmpty ? "ACTIVE" : "EMPTY"}');

      debugPrint('[HOME_BANNER_PROVIDER_DEBUG]');
      debugPrint('request: /api/v1/customer/marketing/banners');
      debugPrint('responseCount: ${banners.length}');
      debugPrint('mappedCount: ${banners.length}');
      debugPrint('filteredCount: ${banners.length}');
      debugPrint('finalCount: ${banners.length}');

      return banners;
    } catch (e) {
      debugPrint('[HOME_BANNER_PROVIDER_ERROR] $e');
      return const [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(customerMarketingServiceProvider);
      final banners = await service.getHomeBanners();

      debugPrint('[HOME_BANNER_PROVIDER_DEBUG]');
      debugPrint('request: /api/v1/customer/marketing/banners (refresh)');
      debugPrint('responseCount: ${banners.length}');
      debugPrint('mappedCount: ${banners.length}');
      debugPrint('filteredCount: ${banners.length}');
      debugPrint('finalCount: ${banners.length}');

      return banners;
    });
  }
}

final customerHomeBannersProvider =
    AsyncNotifierProvider<
      CustomerHomeBannersNotifier,
      List<MarketingBannerModel>
    >(CustomerHomeBannersNotifier.new);

/// Provider specifically for main promotional banners (active, published, with image or title)
final customerPromotionalBannersProvider =
    Provider<AsyncValue<List<MarketingBannerModel>>>((ref) {
      final bannersAsync = ref.watch(customerHomeBannersProvider);
      return bannersAsync.whenData((banners) {
        final now = DateTime.now();
        return banners.where((b) {
          if (!b.isActive || !b.isPublished) return false;
          if (b.startAt != null) {
            final start = b.startAt!;
            final effectiveStart =
                (start.hour == 0 && start.minute == 0 && start.second == 0)
                ? DateTime(start.year, start.month, start.day, 0, 0, 0, 0)
                : start;
            if (effectiveStart.isAfter(now)) return false;
          }
          if (b.endAt != null) {
            final end = b.endAt!;
            final effectiveEnd =
                (end.hour == 0 && end.minute == 0 && end.second == 0)
                ? DateTime(end.year, end.month, end.day, 23, 59, 59, 999)
                : end;
            if (effectiveEnd.isBefore(now)) return false;
          }
          return b.effectiveImageUrl.isNotEmpty ||
              (b.title != null && b.title!.isNotEmpty);
        }).toList();
      });
    });

/// Provider specifically for active coupons / offers
final customerCouponsProvider =
    Provider<AsyncValue<List<MarketingBannerModel>>>((ref) {
      final bannersAsync = ref.watch(customerHomeBannersProvider);
      return bannersAsync.whenData((banners) {
        final now = DateTime.now();
        final validBanners = banners.where((b) {
          if (!b.isActive || !b.isPublished) return false;
          if (b.startAt != null) {
            final start = b.startAt!;
            final effectiveStart =
                (start.hour == 0 && start.minute == 0 && start.second == 0)
                ? DateTime(start.year, start.month, start.day, 0, 0, 0, 0)
                : start;
            if (effectiveStart.isAfter(now)) return false;
          }
          if (b.endAt != null) {
            final end = b.endAt!;
            final effectiveEnd =
                (end.hour == 0 && end.minute == 0 && end.second == 0)
                ? DateTime(end.year, end.month, end.day, 23, 59, 59, 999)
                : end;
            if (effectiveEnd.isBefore(now)) return false;
          }
          final hasCoupon =
              (b.couponCode != null && b.couponCode!.trim().isNotEmpty) ||
              (b.discount != null && b.discount!.trim().isNotEmpty) ||
              (b.brand != null && b.brand!.trim().isNotEmpty) ||
              (b.category != null &&
                  (b.category!.trim().toUpperCase() == 'COUPON' ||
                      b.category!.trim().toUpperCase() == 'OFFER' ||
                      b.category!.trim().toUpperCase() == 'DISCOUNT' ||
                      b.category!.trim().toUpperCase() == 'PROMO' ||
                      b.category!.trim().toUpperCase() == 'MARKETING')) ||
              (b.actionType != null &&
                  (b.actionType!.trim().toUpperCase() == 'OPEN_COUPON' ||
                      b.actionType!.trim().toUpperCase() == 'COUPON' ||
                      b.actionType!.trim().toUpperCase() == 'CLAIM_REWARD' ||
                      b.actionType!.trim().toUpperCase() == 'OPEN_PLAN' ||
                      b.actionType!.trim().toUpperCase() == 'OPEN_DETAILS' ||
                      b.actionType!.trim().toUpperCase() == 'OPEN_URL')) ||
              (b.metadata != null &&
                  (b.metadata!['couponCode'] != null ||
                      b.metadata!['coupon_code'] != null ||
                      b.metadata!['code'] != null ||
                      b.metadata!['discount'] != null ||
                      b.metadata!['discountValue'] != null ||
                      b.metadata!['discountPct'] != null ||
                      b.metadata!['isCoupon'] == true ||
                      b.metadata!['offer'] != null)) ||
              (b.ctaText != null && b.ctaText!.trim().isNotEmpty) ||
              (b.title != null &&
                  (b.title!.contains('%') ||
                      b.title!.toUpperCase().contains('OFF') ||
                      b.title!.toUpperCase().contains('FLAT') ||
                      b.title!.toUpperCase().contains('COUPON') ||
                      b.title!.toUpperCase().contains('DISCOUNT') ||
                      b.title!.toUpperCase().contains('PROMO') ||
                      b.title!.toUpperCase().contains('OFFER') ||
                      b.title!.toUpperCase().contains('DEAL') ||
                      b.title!.toUpperCase().contains('SALE') ||
                      b.title!.toUpperCase().contains('BASH') ||
                      b.title!.toUpperCase().contains('SAVE') ||
                      b.title!.toUpperCase().contains('CLAIM') ||
                      b.title!.toUpperCase().contains('SPECIAL') ||
                      b.title!.toUpperCase().contains('FREE') ||
                      b.title!.toUpperCase().contains('CASHBACK') ||
                      b.title!.toUpperCase().contains('VOUCHER')));
          return hasCoupon;
        }).toList();

        validBanners.sort((a, b) {
          final aHasCouponCode =
              (a.couponCode != null && a.couponCode!.trim().isNotEmpty) ? 1 : 0;
          final bHasCouponCode =
              (b.couponCode != null && b.couponCode!.trim().isNotEmpty) ? 1 : 0;
          if (aHasCouponCode != bHasCouponCode) {
            return bHasCouponCode.compareTo(aHasCouponCode);
          }
          final aHasDiscount =
              (a.discount != null && a.discount!.trim().isNotEmpty) ? 1 : 0;
          final bHasDiscount =
              (b.discount != null && b.discount!.trim().isNotEmpty) ? 1 : 0;
          if (aHasDiscount != bHasDiscount) {
            return bHasDiscount.compareTo(aHasDiscount);
          }
          return b.priority.compareTo(a.priority);
        });

        return validBanners;
      });
    });
