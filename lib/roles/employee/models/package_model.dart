/// A Package defines a product offering with multiple items/features.
class PackageModel {
  final String id;
  final String name;
  final String description;
  final int duration;
  final String durationType; // Months, Years, Days
  final double basePrice;
  final double gstPercent;
  final String status; // ACTIVE, INACTIVE
  final String createdAt;
  final List<PackageItemModel> items;

  const PackageModel({
    required this.id,
    required this.name,
    required this.description,
    required this.duration,
    required this.durationType,
    required this.basePrice,
    required this.gstPercent,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  double get gstAmount => basePrice * (gstPercent / 100);
  double get totalPrice => basePrice + gstAmount;

  String get durationLabel => '$duration $durationType';

  /// Helper for searching packages
  bool matchesQuery(String query) {
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q);
  }

  PackageModel copyWith({
    String? id,
    String? name,
    String? description,
    int? duration,
    String? durationType,
    double? basePrice,
    double? gstPercent,
    String? status,
    String? createdAt,
    List<PackageItemModel>? items,
  }) {
    return PackageModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      durationType: durationType ?? this.durationType,
      basePrice: basePrice ?? this.basePrice,
      gstPercent: gstPercent ?? this.gstPercent,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}

class PackageItemModel {
  final String id;
  final String packageId;
  final String name;
  final int quantity;
  final String planType; // Monthly, Yearly, One-time
  final double unitPrice;

  const PackageItemModel({
    required this.id,
    required this.packageId,
    required this.name,
    required this.quantity,
    required this.planType,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;
}
