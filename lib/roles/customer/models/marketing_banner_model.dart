import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';

/// Dynamic Marketing Banner model matching backend Prisma model
@immutable
class MarketingBannerModel {
  final int id;
  final String? title;
  final String? subtitle;
  final String? description;
  final String imageUrl;
  final String? mobileImageUrl;
  final String? ctaText;
  final String? ctaUrl;
  final String? actionType;
  final int priority;
  final bool isActive;
  final bool isPublished;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime createdAt;
  final String? couponCode;
  final String? discount;
  final String? brand;
  final String? terms;
  final String? minOrder;
  final String? category;
  final Map<String, dynamic>? metadata;

  const MarketingBannerModel({
    required this.id,
    this.title,
    this.subtitle,
    this.description,
    required this.imageUrl,
    this.mobileImageUrl,
    this.ctaText,
    this.ctaUrl,
    this.actionType,
    this.priority = 0,
    this.isActive = true,
    this.isPublished = true,
    this.startAt,
    this.endAt,
    required this.createdAt,
    this.couponCode,
    this.discount,
    this.brand,
    this.terms,
    this.minOrder,
    this.category,
    this.metadata,
  });

  String get effectiveImageUrl {
    final raw = (mobileImageUrl != null && mobileImageUrl!.trim().isNotEmpty)
        ? mobileImageUrl!.trim()
        : imageUrl.trim();

    if (raw.isEmpty) return '';

    String url = raw;

    // Fix localhost / 127.0.0.1 URLs from local development uploads so Android device/emulator can resolve them
    final base = AppUrl.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    if (url.contains('localhost:3000') ||
        url.contains('127.0.0.1:3000') ||
        url.contains('localhost:5000') ||
        url.contains('127.0.0.1:5000') ||
        url.contains('localhost:8000') ||
        url.contains('127.0.0.1:8000')) {
      url = url.replaceFirst(
        RegExp(r'https?://(localhost|127\.0\.0\.1):(3000|5000|8000)'),
        base,
      );
    }

    if (url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('data:')) {
      return url;
    }

    if (url.startsWith('/')) {
      return '$base$url';
    }
    return '$base/$url';
  }

  factory MarketingBannerModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return MarketingBannerModel(
        id: 0,
        imageUrl: '',
        createdAt: DateTime.now(),
      );
    }

    dynamic rawImgField =
        json['imageUrl'] ??
        json['image'] ??
        json['bannerImage'] ??
        json['bannerUrl'] ??
        json['mediaUrl'] ??
        json['photoUrl'] ??
        json['url'];

    String rawImg = '';
    if (rawImgField is Map) {
      rawImg =
          rawImgField['url']?.toString() ??
          rawImgField['imageUrl']?.toString() ??
          rawImgField['secure_url']?.toString() ??
          rawImgField['path']?.toString() ??
          '';
    } else if (rawImgField != null) {
      rawImg = rawImgField.toString();
    }

    final idVal = json['id'] is int
        ? json['id'] as int
        : int.tryParse(json['id']?.toString() ?? '0') ?? 0;

    final rawTitle = json['title']?.toString().trim();
    // Do not set title if null, empty, or default generic placeholder 'Home Banner'
    final cleanTitle =
        (rawTitle != null &&
            rawTitle.isNotEmpty &&
            rawTitle.toLowerCase() != 'home banner')
        ? rawTitle
        : null;

    final rawSubtitle = json['subtitle']?.toString().trim();
    final cleanSubtitle = (rawSubtitle != null && rawSubtitle.isNotEmpty)
        ? rawSubtitle
        : null;

    final rawDesc = json['description']?.toString().trim();
    final cleanDesc = (rawDesc != null && rawDesc.isNotEmpty) ? rawDesc : null;

    final rawCtaText =
        (json['ctaText'] ?? json['buttonText'] ?? json['actionLabel'])
            ?.toString()
            .trim();
    final cleanCtaText = (rawCtaText != null && rawCtaText.isNotEmpty)
        ? rawCtaText
        : null;

    final rawCtaUrl =
        (json['ctaUrl'] ??
                json['ctaLink'] ??
                json['buttonLink'] ??
                json['actionUrl'] ??
                json['redirectUrl'] ??
                json['link'] ??
                json['url'])
            ?.toString()
            .trim();
    final cleanCtaUrl = (rawCtaUrl != null && rawCtaUrl.isNotEmpty)
        ? rawCtaUrl
        : null;

    Map<String, dynamic>? meta;
    if (json['metadata'] is Map) {
      meta = Map<String, dynamic>.from(json['metadata'] as Map);
    } else if (json['metadata'] is String &&
        (json['metadata'] as String).trim().startsWith('{')) {
      try {
        meta = Map<String, dynamic>.from(
          jsonDecode(json['metadata'] as String) as Map,
        );
      } catch (_) {}
    }

    final rawActionType =
        (json['actionType'] ??
                json['action_type'] ??
                json['action'] ??
                json['targetDestination'] ??
                meta?['actionType'] ??
                meta?['action_type'] ??
                meta?['action'])
            ?.toString()
            .trim();
    final cleanActionType = (rawActionType != null && rawActionType.isNotEmpty)
        ? rawActionType
        : null;

    final rawMobileImg = (json['mobileImageUrl'] ?? json['mobileImage'])
        ?.toString()
        .trim();
    final cleanMobileImg = (rawMobileImg != null && rawMobileImg.isNotEmpty)
        ? rawMobileImg
        : null;

    final rawCouponCode =
        (json['couponCode'] ??
                json['coupon_code'] ??
                json['code'] ??
                json['promoCode'] ??
                json['promo_code'] ??
                meta?['couponCode'] ??
                meta?['coupon_code'] ??
                meta?['code'])
            ?.toString()
            .trim();
    final cleanCouponCode = (rawCouponCode != null && rawCouponCode.isNotEmpty)
        ? rawCouponCode
        : null;

    final rawDiscount =
        (json['discount'] ??
                json['discountValue'] ??
                json['discountPct'] ??
                json['offerValue'] ??
                meta?['discount'] ??
                meta?['discountValue'] ??
                meta?['discountPct'])
            ?.toString()
            .trim();
    final cleanDiscount = (rawDiscount != null && rawDiscount.isNotEmpty)
        ? rawDiscount
        : null;

    final rawBrand =
        (json['brand'] ??
                json['brandName'] ??
                meta?['brand'] ??
                meta?['brandName'])
            ?.toString()
            .trim();
    final cleanBrand = (rawBrand != null && rawBrand.isNotEmpty)
        ? rawBrand
        : null;

    final rawTerms = (json['terms'] ?? meta?['terms'])?.toString().trim();
    final cleanTerms = (rawTerms != null && rawTerms.isNotEmpty)
        ? rawTerms
        : null;

    final rawMinOrder =
        (json['minOrder'] ??
                json['minimumOrder'] ??
                meta?['minOrder'] ??
                meta?['minimumOrder'])
            ?.toString()
            .trim();
    final cleanMinOrder = (rawMinOrder != null && rawMinOrder.isNotEmpty)
        ? rawMinOrder
        : null;

    final rawCategory = (json['category'] ?? meta?['category'])
        ?.toString()
        .trim();
    final cleanCategory = (rawCategory != null && rawCategory.isNotEmpty)
        ? rawCategory
        : null;

    return MarketingBannerModel(
      id: idVal,
      title: cleanTitle,
      subtitle: cleanSubtitle,
      description: cleanDesc,
      imageUrl: rawImg.trim(),
      mobileImageUrl: cleanMobileImg,
      ctaText: cleanCtaText,
      ctaUrl: cleanCtaUrl,
      actionType: cleanActionType,
      priority: json['priority'] is int
          ? json['priority'] as int
          : int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
      isActive: json['isActive'] == null
          ? true
          : (json['isActive'] == true ||
                json['isActive'] == 'true' ||
                json['isActive'] == 1),
      isPublished: json['isPublished'] == null
          ? true
          : (json['isPublished'] == true ||
                json['isPublished'] == 'true' ||
                json['isPublished'] == 1),
      startAt: json['startAt'] != null
          ? DateTime.tryParse(json['startAt'].toString())
          : null,
      endAt: json['endAt'] != null
          ? DateTime.tryParse(json['endAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      couponCode: cleanCouponCode,
      discount: cleanDiscount,
      brand: cleanBrand,
      terms: cleanTerms,
      minOrder: cleanMinOrder,
      category: cleanCategory,
      metadata: meta,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'description': description,
    'imageUrl': imageUrl,
    'mobileImageUrl': mobileImageUrl,
    'ctaText': ctaText,
    'ctaUrl': ctaUrl,
    'actionType': actionType,
    'priority': priority,
    'isActive': isActive,
    'isPublished': isPublished,
    'startAt': startAt?.toIso8601String(),
    'endAt': endAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'couponCode': couponCode,
    'discount': discount,
    'brand': brand,
    'terms': terms,
    'minOrder': minOrder,
    'category': category,
    'metadata': metadata,
  };
}
