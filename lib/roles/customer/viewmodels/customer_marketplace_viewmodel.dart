import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/marketplace_tool_model.dart';
import '../services/customer_marketplace_service.dart';

class CustomerMarketplaceNotifier
    extends AsyncNotifier<List<MarketplaceToolModel>> {
  @override
  Future<List<MarketplaceToolModel>> build() async {
    final service = ref.watch(customerMarketplaceServiceProvider);
    return service.fetchMarketplaceTools();
  }

  Future<void> refreshTools() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(customerMarketplaceServiceProvider);
      return service.fetchMarketplaceTools();
    });
  }
}

final customerMarketplaceToolsProvider =
    AsyncNotifierProvider<
      CustomerMarketplaceNotifier,
      List<MarketplaceToolModel>
    >(CustomerMarketplaceNotifier.new);
