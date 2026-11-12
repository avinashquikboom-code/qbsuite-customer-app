/// Influencer model representing verified creators returned by the real backend API.
class InfluencerModel {
  final int id;
  final String name;
  final String? handle;
  final String? avatarUrl;
  final String? profileImage;
  final String platform;
  final int? categoryId;
  final String categoryName;
  final String location;
  final String? city;
  final int followers;
  final String followersCount;
  final double engagementRate;
  final bool isVerified;
  final bool isFeatured;
  final bool isActive;
  final String? bio;
  final String? bookingUrl;
  final double? pricing;
  final double rating;
  final int sortOrder;
  final bool isFavorited;
  final String status;
  final String? email;
  final String? phone;
  final String? rejectionReason;
  final String? approvedAt;
  final String? rejectedAt;
  final String? suspendedAt;
  final Map<String, dynamic>? socialLinks;
  final List<String> languages;
  final List<String> portfolioUrls;
  final List<InfluencerPackageModel> packages;

  const InfluencerModel({
    required this.id,
    required this.name,
    this.handle,
    this.avatarUrl,
    this.profileImage,
    this.platform = 'INSTAGRAM',
    this.categoryId,
    this.categoryName = 'Creator',
    this.location = '',
    this.city,
    this.followers = 0,
    this.followersCount = '0',
    this.engagementRate = 0.0,
    this.isVerified = false,
    this.isFeatured = false,
    this.isActive = true,
    this.bio,
    this.bookingUrl,
    this.pricing,
    this.rating = 0.0,
    this.sortOrder = 0,
    this.isFavorited = false,
    this.status = 'APPROVED',
    this.email,
    this.phone,
    this.rejectionReason,
    this.approvedAt,
    this.rejectedAt,
    this.suspendedAt,
    this.socialLinks,
    this.languages = const [],
    this.portfolioUrls = const [],
    this.packages = const [],
  });

  factory InfluencerModel.fromJson(Map<String, dynamic> json) {
    final int parsedId = int.tryParse(json['id']?.toString() ?? '0') ?? 0;
    final int parsedFollowers =
        int.tryParse(json['followers']?.toString() ?? '0') ?? 0;
    final double parsedEngRate =
        double.tryParse(json['engagementRate']?.toString() ?? '0.0') ?? 0.0;
    final double parsedRating =
        double.tryParse(json['rating']?.toString() ?? '0.0') ?? 0.0;
    final double? parsedPricing = json['pricing'] != null
        ? double.tryParse(json['pricing'].toString())
        : (json['startingPrice'] != null
              ? double.tryParse(json['startingPrice'].toString())
              : null);

    String catName = json['categoryName']?.toString() ?? '';
    if (catName.isEmpty && json['category'] is Map) {
      catName = (json['category'] as Map)['name']?.toString() ?? 'Creator';
    }
    if (catName.isEmpty) catName = 'Creator';

    final List<String> parsedLangs = [];
    if (json['languages'] is List) {
      for (final l in json['languages'] as List) {
        if (l != null && l.toString().trim().isNotEmpty) {
          parsedLangs.add(l.toString().trim());
        }
      }
    }

    final List<String> parsedPortfolios = [];
    if (json['portfolios'] is List) {
      for (final p in json['portfolios'] as List) {
        if (p is Map) {
          final url =
              p['mediaUrl']?.toString() ??
              p['imageUrl']?.toString() ??
              p['url']?.toString();
          if (url != null && url.trim().isNotEmpty) {
            parsedPortfolios.add(url.trim());
          }
        } else if (p is String && p.trim().isNotEmpty) {
          parsedPortfolios.add(p.trim());
        }
      }
    }

    final List<InfluencerPackageModel> parsedPackages = [];
    if (json['packages'] is List) {
      for (final p in (json['packages'] as List)) {
        if (p is Map) {
          try {
            parsedPackages.add(
              InfluencerPackageModel.fromJson(Map<String, dynamic>.from(p)),
            );
          } catch (_) {}
        }
      }
    }

    final String computedFollowersCount =
        json['followersCount']?.toString() ??
        (parsedFollowers >= 1000000
            ? '${(parsedFollowers / 1000000).toStringAsFixed(1)}M'
            : (parsedFollowers >= 1000
                  ? '${(parsedFollowers / 1000).toStringAsFixed(0)}K'
                  : '$parsedFollowers'));

    return InfluencerModel(
      id: parsedId,
      name: json['name']?.toString() ?? 'Creator',
      handle: json['handle']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      profileImage:
          json['profileImage']?.toString() ?? json['avatarUrl']?.toString(),
      platform: (json['platform']?.toString() ?? 'INSTAGRAM').toUpperCase(),
      categoryId: json['categoryId'] != null
          ? int.tryParse(json['categoryId'].toString())
          : null,
      categoryName: catName,
      location: json['location']?.toString() ?? json['city']?.toString() ?? '',
      city: json['city']?.toString(),
      followers: parsedFollowers,
      followersCount: computedFollowersCount,
      engagementRate: parsedEngRate,
      isVerified:
          json['isVerified'] == true ||
          json['isVerified'] == 1 ||
          json['isVerified'] == 'true',
      isFeatured:
          json['isFeatured'] == true ||
          json['isFeatured'] == 1 ||
          json['isFeatured'] == 'true',
      isActive: json['isActive'] != false,
      bio: json['bio']?.toString(),
      bookingUrl: json['bookingUrl']?.toString(),
      pricing: parsedPricing,
      rating: parsedRating,
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '0') ?? 0,
      isFavorited: json['isFavorited'] == true,
      status: json['status']?.toString() ?? 'APPROVED',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      approvedAt: json['approvedAt']?.toString(),
      rejectedAt: json['rejectedAt']?.toString(),
      suspendedAt: json['suspendedAt']?.toString(),
      socialLinks: json['socialLinks'] is Map<String, dynamic>
          ? json['socialLinks'] as Map<String, dynamic>
          : null,
      languages: parsedLangs,
      portfolioUrls: parsedPortfolios,
      packages: parsedPackages,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'handle': handle,
    'avatarUrl': avatarUrl,
    'profileImage': profileImage,
    'platform': platform,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'location': location,
    'city': city,
    'followers': followers,
    'followersCount': followersCount,
    'engagementRate': engagementRate,
    'isVerified': isVerified,
    'isFeatured': isFeatured,
    'isActive': isActive,
    'bio': bio,
    'bookingUrl': bookingUrl,
    'pricing': pricing,
    'rating': rating,
    'sortOrder': sortOrder,
    'isFavorited': isFavorited,
    'status': status,
    'email': email,
    'phone': phone,
    'rejectionReason': rejectionReason,
    'approvedAt': approvedAt,
    'rejectedAt': rejectedAt,
    'suspendedAt': suspendedAt,
    'socialLinks': socialLinks,
    'languages': languages,
    'portfolioUrls': portfolioUrls,
  };

  InfluencerModel copyWith({
    int? id,
    String? name,
    String? handle,
    String? avatarUrl,
    String? profileImage,
    String? platform,
    int? categoryId,
    String? categoryName,
    String? location,
    String? city,
    int? followers,
    String? followersCount,
    double? engagementRate,
    bool? isVerified,
    bool? isFeatured,
    bool? isActive,
    String? bio,
    String? bookingUrl,
    double? pricing,
    double? rating,
    int? sortOrder,
    bool? isFavorited,
    List<String>? languages,
    List<String>? portfolioUrls,
  }) {
    return InfluencerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      profileImage: profileImage ?? this.profileImage,
      platform: platform ?? this.platform,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      location: location ?? this.location,
      city: city ?? this.city,
      followers: followers ?? this.followers,
      followersCount: followersCount ?? this.followersCount,
      engagementRate: engagementRate ?? this.engagementRate,
      isVerified: isVerified ?? this.isVerified,
      isFeatured: isFeatured ?? this.isFeatured,
      isActive: isActive ?? this.isActive,
      bio: bio ?? this.bio,
      bookingUrl: bookingUrl ?? this.bookingUrl,
      pricing: pricing ?? this.pricing,
      rating: rating ?? this.rating,
      sortOrder: sortOrder ?? this.sortOrder,
      isFavorited: isFavorited ?? this.isFavorited,
      languages: languages ?? this.languages,
      portfolioUrls: portfolioUrls ?? this.portfolioUrls,
    );
  }

  /// Primary image to display in cards
  String get effectiveImageUrl {
    if (profileImage != null && profileImage!.trim().isNotEmpty) {
      return profileImage!.trim();
    }
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return avatarUrl!.trim();
    }
    return '';
  }

  String get displayPlatform {
    switch (platform.toUpperCase()) {
      case 'INSTAGRAM':
        return 'Instagram';
      case 'YOUTUBE':
        return 'YouTube';
      case 'SNAPCHAT':
        return 'Snapchat';
      case 'FACEBOOK':
        return 'Facebook';
      case 'TIKTOK':
        return 'TikTok';
      default:
        return platform;
    }
  }

  String get displayFollowers {
    if (followersCount.toLowerCase().contains('follower')) {
      return followersCount;
    }
    return '$followersCount Followers';
  }

  String get displayEngagement {
    if (engagementRate <= 0) return '';
    return '${engagementRate.toStringAsFixed(1)}% Engagement';
  }
}

/// Influencer category model for horizontal scroll category filters.
class InfluencerCategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? icon;
  final int creatorCount;

  const InfluencerCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.creatorCount = 0,
  });

  factory InfluencerCategoryModel.fromJson(Map<String, dynamic> json) {
    return InfluencerCategoryModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Category',
      slug: json['slug']?.toString() ?? '',
      icon: json['icon']?.toString(),
      creatorCount: int.tryParse(json['creatorCount']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'icon': icon,
    'creatorCount': creatorCount,
  };
}

/// Influencer package model matching Screen 3 (Packages & Pricing).
class InfluencerPackageModel {
  final String id;
  final String name;
  final String badgeText;
  final String subtitle;
  final double price;
  final String? priceDisplay;
  final bool isCustom;
  final String iconType; // 'story', 'reel', 'post', 'custom'

  const InfluencerPackageModel({
    required this.id,
    required this.name,
    required this.badgeText,
    required this.subtitle,
    required this.price,
    this.priceDisplay,
    this.isCustom = false,
    this.iconType = 'reel',
  });

  String get formattedPrice {
    if (priceDisplay != null && priceDisplay!.isNotEmpty) {
      return priceDisplay!;
    }
    return '₹${price.toStringAsFixed(0)}';
  }

  factory InfluencerPackageModel.fromJson(Map<String, dynamic> json) {
    final String typeStr = (json['type'] ?? json['iconType'] ?? 'REEL')
        .toString()
        .toUpperCase();
    String iconType = 'reel';
    if (typeStr.contains('STORY')) iconType = 'story';
    if (typeStr.contains('POST')) iconType = 'post';
    if (typeStr.contains('CUSTOM')) iconType = 'custom';

    return InfluencerPackageModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Package',
      badgeText:
          json['badgeText']?.toString() ?? json['duration']?.toString() ?? '',
      subtitle:
          json['subtitle']?.toString() ?? json['description']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      priceDisplay: json['priceDisplay']?.toString(),
      isCustom: json['isCustom'] == true || typeStr.contains('CUSTOM'),
      iconType: iconType,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'badgeText': badgeText,
    'subtitle': subtitle,
    'price': price,
    'priceDisplay': priceDisplay,
    'isCustom': isCustom,
    'iconType': iconType,
  };

  static List<InfluencerPackageModel> defaultPackagesFor(
    InfluencerModel creator,
  ) {
    final double base = creator.pricing ?? 5000;
    final double storyPrice = (base * 0.4).clamp(1500, 10000).roundToDouble();
    final double reelPrice = base;
    final double postPrice = (base * 0.8).clamp(2000, 15000).roundToDouble();

    return [
      InfluencerPackageModel(
        id: 'story',
        name: '1 Story',
        badgeText: '24h',
        subtitle: '1 Instagram Story (with brand tag)',
        price: storyPrice > 0 ? storyPrice : 2000,
        iconType: 'story',
      ),
      InfluencerPackageModel(
        id: 'reel',
        name: '1 Reel',
        badgeText: '3-5 days',
        subtitle: '1 Instagram Reel (15-30 sec)',
        price: reelPrice > 0 ? reelPrice : 5000,
        iconType: 'reel',
      ),
      InfluencerPackageModel(
        id: 'post',
        name: '1 Post',
        badgeText: '2-3 days',
        subtitle: '1 Instagram Post (photo + caption)',
        price: postPrice > 0 ? postPrice : 4000,
        iconType: 'post',
      ),
      const InfluencerPackageModel(
        id: 'custom',
        name: 'Custom Package',
        badgeText: 'As per requirement',
        subtitle: "Let's create a custom package for your brand",
        price: 0,
        priceDisplay: 'Contact for Price',
        isCustom: true,
        iconType: 'custom',
      ),
    ];
  }
}

/// Influencer booking record model matching Screens 4, 5, 6, 7, 8.
class InfluencerBookingModel {
  final String bookingId;
  final int influencerId;
  final String influencerName;
  final String influencerImage;
  final String categoryName;
  final String followersCount;
  final String packageName;
  final double packageCost;
  final double platformFee;
  final double gst;
  final double totalAmount;
  final String campaignDate;
  final String
  status; // 'Upcoming', 'Active', 'Completed', 'Cancelled', 'Pending', 'Confirmed'
  final String brandName;
  final String contactPerson;
  final String mobileNumber;
  final String email;
  final String businessName;
  final String? instagramId;
  final String campaignObjective;
  final String? paymentStatus;
  final String? paymentMethod;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpayKeyId;
  final String? notes;
  final DateTime createdAt;
  final String? customerId;

  const InfluencerBookingModel({
    required this.bookingId,
    required this.influencerId,
    required this.influencerName,
    required this.influencerImage,
    required this.categoryName,
    required this.followersCount,
    required this.packageName,
    required this.packageCost,
    required this.platformFee,
    required this.gst,
    required this.totalAmount,
    required this.campaignDate,
    this.status = 'Upcoming',
    this.paymentStatus = 'PENDING',
    this.paymentMethod = 'RAZORPAY',
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpayKeyId,
    required this.brandName,
    required this.contactPerson,
    required this.mobileNumber,
    required this.email,
    required this.businessName,
    this.instagramId,
    required this.campaignObjective,
    this.notes,
    required this.createdAt,
    this.customerId,
  });

  factory InfluencerBookingModel.fromJson(Map<String, dynamic> json) {
    String infName = json['influencerName']?.toString() ?? '';
    String infImg = json['influencerImage']?.toString() ?? '';
    String catName = json['categoryName']?.toString() ?? '';
    String pkgName = json['packageName']?.toString() ?? '';

    if (json['influencer'] is Map) {
      final infMap = json['influencer'] as Map;
      if (infName.isEmpty) infName = infMap['name']?.toString() ?? '';
      if (infImg.isEmpty) {
        infImg =
            infMap['profileImage']?.toString() ??
            infMap['avatarUrl']?.toString() ??
            '';
      }
      if (catName.isEmpty) catName = infMap['categoryName']?.toString() ?? '';
    }

    if (json['package'] is Map) {
      final pkgMap = json['package'] as Map;
      if (pkgName.isEmpty) pkgName = pkgMap['name']?.toString() ?? '';
    }

    if (infName.isEmpty) infName = 'Creator';
    if (pkgName.isEmpty) pkgName = 'Standard Deliverable';

    final double pkgCost =
        double.tryParse(
          json['packageAmount']?.toString() ??
              json['packageCost']?.toString() ??
              '5000',
        ) ??
        5000;
    final double platFee =
        double.tryParse(json['platformFee']?.toString() ?? '500') ?? 500;
    final double gstVal =
        double.tryParse(json['gst']?.toString() ?? '990') ?? 990;
    final double totAmt =
        double.tryParse(
          json['totalAmount']?.toString() ?? '${pkgCost + platFee + gstVal}',
        ) ??
        (pkgCost + platFee + gstVal);

    final String? rzpKey = (json['paymentGatewayConfig'] is Map)
        ? json['paymentGatewayConfig']['keyId']?.toString()
        : json['razorpayKeyId']?.toString();
    final String? rzpOrd =
        (json['paymentGatewayConfig'] is Map &&
            json['paymentGatewayConfig']['orderId'] != null)
        ? json['paymentGatewayConfig']['orderId']?.toString()
        : json['razorpayOrderId']?.toString();

    return InfluencerBookingModel(
      bookingId:
          json['bookingId']?.toString() ??
          'QBINFLU-${DateTime.now().millisecondsSinceEpoch}',
      influencerId: int.tryParse(json['influencerId']?.toString() ?? '0') ?? 0,
      influencerName: infName,
      influencerImage: infImg,
      categoryName: catName.isNotEmpty ? catName : 'Creator',
      followersCount: json['followersCount']?.toString() ?? '100K',
      packageName: pkgName,
      packageCost: pkgCost,
      platformFee: platFee,
      gst: gstVal,
      totalAmount: totAmt,
      campaignDate: json['campaignDate']?.toString() ?? '12 Sep 2026',
      status:
          json['bookingStatus']?.toString() ??
          json['status']?.toString() ??
          'Upcoming',
      paymentStatus: json['paymentStatus']?.toString() ?? 'PENDING',
      paymentMethod: json['paymentMethod']?.toString() ?? 'RAZORPAY',
      razorpayOrderId: rzpOrd,
      razorpayPaymentId: json['razorpayPaymentId']?.toString(),
      razorpayKeyId: rzpKey,
      brandName: json['brandName']?.toString() ?? '',
      contactPerson: json['contactPerson']?.toString() ?? '',
      mobileNumber: json['mobileNumber']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      businessName: json['businessName']?.toString() ?? '',
      instagramId: json['instagramId']?.toString(),
      campaignObjective:
          json['campaignObjective']?.toString() ?? 'Brand Awareness',
      notes: json['notes']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      customerId: json['customerId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'bookingId': bookingId,
    'influencerId': influencerId,
    'influencerName': influencerName,
    'influencerImage': influencerImage,
    'categoryName': categoryName,
    'followersCount': followersCount,
    'packageName': packageName,
    'packageCost': packageCost,
    'platformFee': platformFee,
    'gst': gst,
    'totalAmount': totalAmount,
    'campaignDate': campaignDate,
    'status': status,
    'brandName': brandName,
    'contactPerson': contactPerson,
    'mobileNumber': mobileNumber,
    'email': email,
    'businessName': businessName,
    'instagramId': instagramId,
    'campaignObjective': campaignObjective,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'customerId': customerId,
  };

  InfluencerBookingModel copyWith({
    String? bookingId,
    int? influencerId,
    String? influencerName,
    String? influencerImage,
    String? categoryName,
    String? followersCount,
    String? packageName,
    double? packageCost,
    double? platformFee,
    double? gst,
    double? totalAmount,
    String? campaignDate,
    String? status,
    String? paymentStatus,
    String? paymentMethod,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpayKeyId,
    String? brandName,
    String? contactPerson,
    String? mobileNumber,
    String? email,
    String? businessName,
    String? instagramId,
    String? campaignObjective,
    String? notes,
    DateTime? createdAt,
    String? customerId,
  }) {
    return InfluencerBookingModel(
      bookingId: bookingId ?? this.bookingId,
      influencerId: influencerId ?? this.influencerId,
      influencerName: influencerName ?? this.influencerName,
      influencerImage: influencerImage ?? this.influencerImage,
      categoryName: categoryName ?? this.categoryName,
      followersCount: followersCount ?? this.followersCount,
      packageName: packageName ?? this.packageName,
      packageCost: packageCost ?? this.packageCost,
      platformFee: platformFee ?? this.platformFee,
      gst: gst ?? this.gst,
      totalAmount: totalAmount ?? this.totalAmount,
      campaignDate: campaignDate ?? this.campaignDate,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      razorpayOrderId: razorpayOrderId ?? this.razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId ?? this.razorpayPaymentId,
      razorpayKeyId: razorpayKeyId ?? this.razorpayKeyId,
      brandName: brandName ?? this.brandName,
      contactPerson: contactPerson ?? this.contactPerson,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      businessName: businessName ?? this.businessName,
      instagramId: instagramId ?? this.instagramId,
      campaignObjective: campaignObjective ?? this.campaignObjective,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      customerId: customerId ?? this.customerId,
    );
  }
}

/// Influencer availability model for slot booking.
class InfluencerAvailabilityModel {
  final int id;
  final int influencerId;
  final DateTime date;
  final bool isAvailable;
  final bool isBooked;
  final String? startTime;
  final String? endTime;

  const InfluencerAvailabilityModel({
    required this.id,
    required this.influencerId,
    required this.date,
    this.isAvailable = true,
    this.isBooked = false,
    this.startTime,
    this.endTime,
  });

  factory InfluencerAvailabilityModel.fromJson(Map<String, dynamic> json) {
    return InfluencerAvailabilityModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      influencerId: int.tryParse(json['influencerId']?.toString() ?? '0') ?? 0,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isAvailable: json['isAvailable'] != false,
      isBooked: json['isBooked'] == true,
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'influencerId': influencerId,
    'date': date.toIso8601String(),
    'isAvailable': isAvailable,
    'isBooked': isBooked,
    'startTime': startTime,
    'endTime': endTime,
  };
}
