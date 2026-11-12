/// Models for QB Marketplace AI Content Creation Studio and Social Publishing.
library;

import '../../../core/network/app_url.dart';

class AiServiceConfigModel {
  final int id;
  final String code;
  final String name;
  final String? description;
  final int creditCost;
  final double pricePerCredit;
  final double? packPrice;
  final bool isActive;
  final int sortOrder;

  const AiServiceConfigModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.creditCost,
    required this.pricePerCredit,
    this.packPrice,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory AiServiceConfigModel.fromJson(Map<String, dynamic> json) {
    return AiServiceConfigModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      creditCost: int.tryParse(json['creditCost']?.toString() ?? '1') ?? 1,
      pricePerCredit:
          double.tryParse(json['pricePerCredit']?.toString() ?? '10') ?? 10.0,
      packPrice: json['packPrice'] != null
          ? double.tryParse(json['packPrice'].toString())
          : null,
      isActive: json['isActive'] != false,
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'description': description,
    'creditCost': creditCost,
    'pricePerCredit': pricePerCredit,
    'packPrice': packPrice,
    'isActive': isActive,
    'sortOrder': sortOrder,
  };
}

class AiWalletModel {
  final int id;
  final int customerId;
  final int balance;
  final int totalPurchased;
  final int totalSpent;
  final List<AiCreditTransactionModel> transactions;

  const AiWalletModel({
    required this.id,
    required this.customerId,
    required this.balance,
    required this.totalPurchased,
    required this.totalSpent,
    this.transactions = const [],
  });

  factory AiWalletModel.fromJson(Map<String, dynamic> json) {
    final txList =
        (json['transactions'] as List<dynamic>?)
            ?.map(
              (e) =>
                  AiCreditTransactionModel.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        [];

    return AiWalletModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      customerId: int.tryParse(json['customerId']?.toString() ?? '0') ?? 0,
      balance: int.tryParse(json['balance']?.toString() ?? '0') ?? 0,
      totalPurchased:
          int.tryParse(json['totalPurchased']?.toString() ?? '0') ?? 0,
      totalSpent: int.tryParse(json['totalSpent']?.toString() ?? '0') ?? 0,
      transactions: txList,
    );
  }
}

class AiCreditTransactionModel {
  final int id;
  final int amount;
  final int balanceAfter;
  final String type; // PURCHASE, SPEND, REFUND, BONUS
  final String? serviceCode;
  final String? notes;
  final DateTime createdAt;

  const AiCreditTransactionModel({
    required this.id,
    required this.amount,
    required this.balanceAfter,
    required this.type,
    this.serviceCode,
    this.notes,
    required this.createdAt,
  });

  factory AiCreditTransactionModel.fromJson(Map<String, dynamic> json) {
    return AiCreditTransactionModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      amount: int.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      balanceAfter: int.tryParse(json['balanceAfter']?.toString() ?? '0') ?? 0,
      type: json['type']?.toString() ?? 'SPEND',
      serviceCode: json['serviceCode']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class AiGenerationModel {
  final int id;
  final String generationId;
  final String type; // POST, POSTER, VIDEO, CAPTION
  final String status; // PENDING, PROCESSING, COMPLETED, FAILED
  final String product;
  final String? objective;
  final String? platform;
  final String? language;
  final String? tone;
  final String? cta;
  final int creditsSpent;
  final String? caption;
  final List<String> hashtags;
  final String? mediaUrl;
  final String? mediaType;
  final String? errorMessage;
  final DateTime createdAt;

  const AiGenerationModel({
    required this.id,
    required this.generationId,
    required this.type,
    required this.status,
    required this.product,
    this.objective,
    this.platform,
    this.language,
    this.tone,
    this.cta,
    this.creditsSpent = 1,
    this.caption,
    this.hashtags = const [],
    this.mediaUrl,
    this.mediaType,
    this.errorMessage,
    required this.createdAt,
  });

  String? get effectiveMediaUrl {
    if (mediaUrl == null || mediaUrl!.trim().isEmpty) return null;
    final url = mediaUrl!.trim();
    if (url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('data:')) {
      return url;
    }
    final base = AppUrl.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    if (url.startsWith('/')) {
      return '$base$url';
    }
    return '$base/$url';
  }

  factory AiGenerationModel.fromJson(Map<String, dynamic> json) {
    List<String> tags = [];
    if (json['hashtags'] is List) {
      tags = (json['hashtags'] as List).map((e) => e.toString()).toList();
    }

    dynamic rawMedia =
        json['mediaUrl'] ?? json['url'] ?? json['imageUrl'] ?? json['videoUrl'];
    if (rawMedia == null &&
        json['assets'] is List &&
        (json['assets'] as List).isNotEmpty) {
      final firstAsset = (json['assets'] as List).first;
      if (firstAsset is Map) {
        rawMedia = firstAsset['url'] ?? firstAsset['mediaUrl'];
      }
    }

    final genType = json['type']?.toString() ?? 'POST';
    final inferredMediaType =
        json['mediaType']?.toString() ??
        (genType.toUpperCase() == 'VIDEO' ? 'VIDEO' : 'IMAGE');

    return AiGenerationModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      generationId: json['generationId']?.toString() ?? '',
      type: genType,
      status: json['status']?.toString() ?? 'COMPLETED',
      product: json['product']?.toString() ?? '',
      objective: json['objective']?.toString(),
      platform: json['platform']?.toString(),
      language: json['language']?.toString(),
      tone: json['tone']?.toString(),
      cta: json['cta']?.toString(),
      creditsSpent: int.tryParse(json['creditsSpent']?.toString() ?? '1') ?? 1,
      caption: json['caption']?.toString(),
      hashtags: tags,
      mediaUrl: rawMedia?.toString(),
      mediaType: inferredMediaType,
      errorMessage: json['errorMessage']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class SocialAccountModel {
  final int id;
  final String platform; // INSTAGRAM, FACEBOOK, YOUTUBE, LINKEDIN, TIKTOK
  final String accountName;
  final String? username;
  final String? profilePic;
  final bool isConnected;

  const SocialAccountModel({
    required this.id,
    required this.platform,
    required this.accountName,
    this.username,
    this.profilePic,
    this.isConnected = true,
  });

  factory SocialAccountModel.fromJson(Map<String, dynamic> json) {
    return SocialAccountModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      platform: json['platform']?.toString() ?? 'INSTAGRAM',
      accountName: json['accountName']?.toString() ?? '',
      username: json['username']?.toString(),
      profilePic: json['profilePic']?.toString(),
      isConnected: json['isConnected'] != false,
    );
  }
}

class SocialPublishModel {
  final int id;
  final String publishId;
  final String platform;
  final String? content;
  final List<String> mediaUrls;
  final String status; // QUEUED, SCHEDULED, PUBLISHED, FAILED
  final DateTime? scheduledFor;
  final DateTime? publishedAt;
  final String? externalPostUrl;
  final String? errorMessage;
  final DateTime createdAt;

  const SocialPublishModel({
    required this.id,
    required this.publishId,
    required this.platform,
    this.content,
    this.mediaUrls = const [],
    required this.status,
    this.scheduledFor,
    this.publishedAt,
    this.externalPostUrl,
    this.errorMessage,
    required this.createdAt,
  });

  factory SocialPublishModel.fromJson(Map<String, dynamic> json) {
    List<String> media = [];
    if (json['mediaUrls'] is List) {
      media = (json['mediaUrls'] as List).map((e) => e.toString()).toList();
    }

    return SocialPublishModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      publishId: json['publishId']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      content: json['content']?.toString(),
      mediaUrls: media,
      status: json['status']?.toString() ?? 'PUBLISHED',
      scheduledFor: json['scheduledFor'] != null
          ? DateTime.tryParse(json['scheduledFor'].toString())
          : null,
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'].toString())
          : null,
      externalPostUrl: json['externalPostUrl']?.toString(),
      errorMessage: json['errorMessage']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
