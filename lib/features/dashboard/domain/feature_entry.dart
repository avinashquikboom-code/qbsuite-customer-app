class FeatureEntry {
  const FeatureEntry(this.id, this.title);
  final String id;
  final String title;
}

abstract interface class DashboardRepository {
  Future<List<FeatureEntry>> features();
}
