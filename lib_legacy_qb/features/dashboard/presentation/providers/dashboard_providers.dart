import '../viewmodels/dashboard_viewmodel.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog_repository.dart';
import '../../domain/feature_entry.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => CatalogRepository(),
);
final dashboardFeaturesProvider = FutureProvider<List<FeatureEntry>>(
  (ref) => ref.watch(dashboardRepositoryProvider).features(),
);

final dashboardQueryProvider =
    NotifierProvider.autoDispose<DashboardQuery, String>(DashboardQuery.new);
