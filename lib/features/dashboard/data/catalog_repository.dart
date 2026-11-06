import '../domain/feature_entry.dart';

/// Local navigation metadata, not mock business records.
class CatalogRepository implements DashboardRepository {
  @override
  Future<List<FeatureEntry>> features() async => const [
    FeatureEntry('products-and-services', 'Products and Services'),
    FeatureEntry('orders', 'Orders'),
    FeatureEntry('order-history', 'Order History'),
    FeatureEntry('payments', 'Payments'),
    FeatureEntry('support', 'Support'),
    FeatureEntry('settings', 'Settings'),
  ];
}
