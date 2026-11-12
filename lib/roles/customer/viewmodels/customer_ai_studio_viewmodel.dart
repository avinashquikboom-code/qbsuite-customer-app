import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_studio_model.dart';
import '../services/customer_ai_studio_service.dart';

/// Notifier for AI service configurations and credit costs
class CustomerAiServicesNotifier
    extends AsyncNotifier<List<AiServiceConfigModel>> {
  @override
  Future<List<AiServiceConfigModel>> build() async {
    final service = ref.watch(customerAiStudioServiceProvider);
    return service.fetchServices();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(customerAiStudioServiceProvider);
      final list = await service.fetchServices();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final customerAiServicesProvider =
    AsyncNotifierProvider<
      CustomerAiServicesNotifier,
      List<AiServiceConfigModel>
    >(CustomerAiServicesNotifier.new);

/// Notifier for customer AI Wallet balance and transactions
class CustomerAiWalletNotifier extends AsyncNotifier<AiWalletModel?> {
  @override
  Future<AiWalletModel?> build() async {
    final service = ref.watch(customerAiStudioServiceProvider);
    return service.fetchWallet();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(customerAiStudioServiceProvider);
      final wallet = await service.fetchWallet();
      state = AsyncValue.data(wallet);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final customerAiWalletProvider =
    AsyncNotifierProvider<CustomerAiWalletNotifier, AiWalletModel?>(
      CustomerAiWalletNotifier.new,
    );

/// Notifier for past AI generations
class CustomerAiGenerationsNotifier
    extends AsyncNotifier<List<AiGenerationModel>> {
  @override
  Future<List<AiGenerationModel>> build() async {
    final service = ref.watch(customerAiStudioServiceProvider);
    return service.fetchGenerations();
  }

  Future<void> refresh({String? type}) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(customerAiStudioServiceProvider);
      final list = await service.fetchGenerations(type: type);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void addGeneration(AiGenerationModel gen) {
    final current = state.value ?? [];
    state = AsyncValue.data([gen, ...current]);
  }
}

final customerAiGenerationsProvider =
    AsyncNotifierProvider<
      CustomerAiGenerationsNotifier,
      List<AiGenerationModel>
    >(CustomerAiGenerationsNotifier.new);

/// Notifier for connected social accounts
class CustomerSocialAccountsNotifier
    extends AsyncNotifier<List<SocialAccountModel>> {
  @override
  Future<List<SocialAccountModel>> build() async {
    final service = ref.watch(customerAiStudioServiceProvider);
    return service.fetchConnectedSocialAccounts();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(customerAiStudioServiceProvider);
      final list = await service.fetchConnectedSocialAccounts();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> disconnect(int id) async {
    final service = ref.read(customerAiStudioServiceProvider);
    final success = await service.disconnectSocialAccount(id);
    if (success) {
      final current = state.value ?? [];
      state = AsyncValue.data(current.where((a) => a.id != id).toList());
    }
    return success;
  }
}

final customerSocialAccountsProvider =
    AsyncNotifierProvider<
      CustomerSocialAccountsNotifier,
      List<SocialAccountModel>
    >(CustomerSocialAccountsNotifier.new);

/// Notifier for customer social publishes
class CustomerSocialPublishesNotifier
    extends AsyncNotifier<List<SocialPublishModel>> {
  @override
  Future<List<SocialPublishModel>> build() async {
    final service = ref.watch(customerAiStudioServiceProvider);
    return service.fetchPublishes();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(customerAiStudioServiceProvider);
      final list = await service.fetchPublishes();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void addPublish(SocialPublishModel pub) {
    final current = state.value ?? [];
    state = AsyncValue.data([pub, ...current]);
  }
}

final customerSocialPublishesProvider =
    AsyncNotifierProvider<
      CustomerSocialPublishesNotifier,
      List<SocialPublishModel>
    >(CustomerSocialPublishesNotifier.new);

/// Notifier for currently selected social account destination
class SelectedSocialAccountNotifier extends Notifier<SocialAccountModel?> {
  @override
  SocialAccountModel? build() => null;

  void selectAccount(SocialAccountModel? account) {
    state = account;
  }
}

final selectedSocialAccountProvider =
    NotifierProvider<SelectedSocialAccountNotifier, SocialAccountModel?>(
      SelectedSocialAccountNotifier.new,
    );
