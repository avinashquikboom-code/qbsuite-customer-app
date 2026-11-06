import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog_repository.dart';
import '../../domain/feature_entry.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => CatalogRepository(),
);
final dashboardFeaturesProvider = FutureProvider<List<FeatureEntry>>(
  (ref) => ref.watch(dashboardRepositoryProvider).features(),
);

class DashboardQuery extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}

final dashboardQueryProvider =
    NotifierProvider.autoDispose<DashboardQuery, String>(DashboardQuery.new);
