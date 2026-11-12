class CustomPlanOption {
  final int id;
  final String name;
  final String code;
  final String? description;
  final String category;
  final double monthlyPrice;
  final String pricingType;
  final String unitName;
  final int minQuantity;
  final int maxQuantity;
  final int defaultQuantity;
  final bool isIncludedInStandard;
  final bool isActive;

  const CustomPlanOption({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    required this.category,
    required this.monthlyPrice,
    required this.pricingType,
    this.unitName = 'unit',
    this.minQuantity = 1,
    this.maxQuantity = 100,
    this.defaultQuantity = 1,
    this.isIncludedInStandard = false,
    this.isActive = true,
  });

  factory CustomPlanOption.fromJson(Map<String, dynamic> json) {
    return CustomPlanOption(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString(),
      category: json['category']?.toString() ?? 'CONTENT',
      monthlyPrice: (json['monthlyPrice'] as num?)?.toDouble() ?? 0.0,
      pricingType: json['pricingType']?.toString() ?? 'PER_UNIT',
      unitName: json['unitName']?.toString() ?? 'unit',
      minQuantity: (json['minQuantity'] as num?)?.toInt() ?? 1,
      maxQuantity: (json['maxQuantity'] as num?)?.toInt() ?? 100,
      defaultQuantity: (json['defaultQuantity'] as num?)?.toInt() ?? 1,
      isIncludedInStandard: json['isIncludedInStandard'] == true,
      isActive: json['isActive'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'description': description,
    'category': category,
    'monthlyPrice': monthlyPrice,
    'pricingType': pricingType,
    'unitName': unitName,
    'minQuantity': minQuantity,
    'maxQuantity': maxQuantity,
    'defaultQuantity': defaultQuantity,
    'isIncludedInStandard': isIncludedInStandard,
    'isActive': isActive,
  };
}

class CustomPlanPreviewItem {
  final int optionId;
  final String code;
  final String name;
  final String category;
  final String pricingType;
  final String unitName;
  final double unitPrice;
  final int quantity;
  final double monthlyTotal;
  final double totalPrice;

  const CustomPlanPreviewItem({
    required this.optionId,
    required this.code,
    required this.name,
    required this.category,
    required this.pricingType,
    required this.unitName,
    required this.unitPrice,
    required this.quantity,
    required this.monthlyTotal,
    required this.totalPrice,
  });

  factory CustomPlanPreviewItem.fromJson(Map<String, dynamic> json) {
    return CustomPlanPreviewItem(
      optionId: (json['optionId'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'CONTENT',
      pricingType: json['pricingType']?.toString() ?? 'PER_UNIT',
      unitName: json['unitName']?.toString() ?? 'unit',
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      monthlyTotal: (json['monthlyTotal'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CustomPlanPricePreview {
  final List<CustomPlanPreviewItem> items;
  final int duration;
  final String durationUnit;
  final double monthlySubtotal;
  final double subtotal;
  final double discount;
  final double discountPercentage;
  final double taxableAmount;
  final double tax;
  final double totalAmount;
  final String currency;

  const CustomPlanPricePreview({
    required this.items,
    required this.duration,
    required this.durationUnit,
    required this.monthlySubtotal,
    required this.subtotal,
    required this.discount,
    required this.discountPercentage,
    required this.taxableAmount,
    required this.tax,
    required this.totalAmount,
    this.currency = 'INR',
  });

  factory CustomPlanPricePreview.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    return CustomPlanPricePreview(
      items: rawItems.map((it) => CustomPlanPreviewItem.fromJson(it)).toList(),
      duration: (json['duration'] as num?)?.toInt() ?? 1,
      durationUnit: json['durationUnit']?.toString() ?? 'MONTH',
      monthlySubtotal: (json['monthlySubtotal'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      discountPercentage:
          (json['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      taxableAmount: (json['taxableAmount'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      totalAmount:
          (json['totalAmount'] as num?)?.toDouble() ??
          (json['total'] as num?)?.toDouble() ??
          0.0,
      currency: json['currency']?.toString() ?? 'INR',
    );
  }
}

class CustomPlanOrder {
  final int id;
  final String orderNumber;
  final int duration;
  final String durationUnit;
  final double subtotal;
  final double discount;
  final double tax;
  final double totalAmount;
  final String currency;
  final String status;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final List<dynamic> selectedFeatures;

  const CustomPlanOrder({
    required this.id,
    required this.orderNumber,
    required this.duration,
    required this.durationUnit,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.totalAmount,
    required this.currency,
    required this.status,
    this.startDate,
    this.expiryDate,
    required this.createdAt,
    this.selectedFeatures = const [],
  });

  factory CustomPlanOrder.fromJson(Map<String, dynamic> json) {
    return CustomPlanOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderNumber: json['orderNumber']?.toString() ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 1,
      durationUnit: json['durationUnit']?.toString() ?? 'MONTH',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'INR',
      status: json['status']?.toString() ?? 'PENDING_PAYMENT',
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : null,
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      selectedFeatures: json['selectedFeatures'] is List
          ? json['selectedFeatures']
          : [],
    );
  }
}
