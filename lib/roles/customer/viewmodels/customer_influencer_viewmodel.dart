import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/influencer_model.dart';
import '../services/customer_influencer_service.dart';

class SelectedInfluencerCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void selectCategory(String? category) {
    state = category;
  }
}

/// Currently selected influencer category filter (null means All)
final selectedInfluencerCategoryProvider =
    NotifierProvider<SelectedInfluencerCategoryNotifier, String?>(
      SelectedInfluencerCategoryNotifier.new,
    );

/// Categories fetched from backend API with robust AsyncNotifier lifecycle
class CustomerInfluencerCategoriesNotifier
    extends AsyncNotifier<List<InfluencerCategoryModel>> {
  @override
  Future<List<InfluencerCategoryModel>> build() async {
    final service = ref.watch(customerInfluencerServiceProvider);
    return service.fetchCategories();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(customerInfluencerServiceProvider);
      final categories = await service.fetchCategories();
      state = AsyncValue.data(categories);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final customerInfluencerCategoriesProvider =
    AsyncNotifierProvider<
      CustomerInfluencerCategoriesNotifier,
      List<InfluencerCategoryModel>
    >(CustomerInfluencerCategoriesNotifier.new);

/// Featured influencers for Customer Home Carousel with robust AsyncNotifier lifecycle
class CustomerFeaturedInfluencersNotifier
    extends AsyncNotifier<List<InfluencerModel>> {
  @override
  Future<List<InfluencerModel>> build() async {
    final service = ref.watch(customerInfluencerServiceProvider);
    final selectedCategory = ref.watch(selectedInfluencerCategoryProvider);

    return service.fetchInfluencers(category: selectedCategory, featured: true);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(customerInfluencerServiceProvider);
      final selectedCategory = ref.read(selectedInfluencerCategoryProvider);
      final influencers = await service.fetchInfluencers(
        category: selectedCategory,
        featured: true,
      );
      state = AsyncValue.data(influencers);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final customerFeaturedInfluencersProvider =
    AsyncNotifierProvider<
      CustomerFeaturedInfluencersNotifier,
      List<InfluencerModel>
    >(CustomerFeaturedInfluencersNotifier.new);

/// All active influencers (used by the "View All" screen with category/search parameters)
final customerAllInfluencersProvider =
    FutureProvider.family<List<InfluencerModel>, String?>((
      ref,
      categorySlug,
    ) async {
      final service = ref.watch(customerInfluencerServiceProvider);
      return service.fetchInfluencers(category: categorySlug);
    });

/// Manages favorited influencer IDs with reactive UI updates and backend sync
class InfluencerFavoritesNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => {};

  void toggleFavorite(int influencerId) {
    final isFav = state.contains(influencerId);
    if (isFav) {
      state = Set<int>.from(state)..remove(influencerId);
    } else {
      state = Set<int>.from(state)..add(influencerId);
    }
    // Sync with backend API
    ref.read(customerInfluencerServiceProvider).toggleFavorite(influencerId);
  }

  bool isFavorited(int influencerId) => state.contains(influencerId);
}

final influencerFavoritesNotifierProvider =
    NotifierProvider<InfluencerFavoritesNotifier, Set<int>>(
      InfluencerFavoritesNotifier.new,
    );

/// Packages fetched from backend for a specific creator
final customerInfluencerPackagesProvider =
    FutureProvider.family<List<InfluencerPackageModel>, int>((
      ref,
      influencerId,
    ) async {
      final service = ref.watch(customerInfluencerServiceProvider);
      return service.fetchPackages(influencerId);
    });

/// Availability dates fetched from backend for a specific creator
final customerInfluencerAvailabilityProvider =
    FutureProvider.family<List<InfluencerAvailabilityModel>, int>((
      ref,
      influencerId,
    ) async {
      final service = ref.watch(customerInfluencerServiceProvider);
      return service.fetchAvailability(influencerId);
    });

/// Customer Influencer Bookings Notifier with strict customer data isolation from backend API.
class CustomerInfluencerBookingsNotifier
    extends AsyncNotifier<List<InfluencerBookingModel>> {
  @override
  Future<List<InfluencerBookingModel>> build() async {
    final service = ref.watch(customerInfluencerServiceProvider);
    return service.fetchMyBookings();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(customerInfluencerServiceProvider);
      final bookings = await service.fetchMyBookings();
      state = AsyncValue.data(bookings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void addBooking(InfluencerBookingModel newBooking) {
    final current = state.value ?? [];
    state = AsyncValue.data([newBooking, ...current]);
  }
}

final customerInfluencerBookingsProvider =
    AsyncNotifierProvider<
      CustomerInfluencerBookingsNotifier,
      List<InfluencerBookingModel>
    >(CustomerInfluencerBookingsNotifier.new);

/// Admin influencer booking management notifier with live backend API sync
class AdminInfluencerBookingsNotifier
    extends Notifier<List<InfluencerBookingModel>> {
  @override
  List<InfluencerBookingModel> build() {
    _fetchFromBackend();
    return const [];
  }

  Future<void> _fetchFromBackend() async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.ensureAuthLoaded();
    try {
      final response = await apiClient.get('/admin/influencer-bookings');
      if (response.statusCode == 200 && response.data != null) {
        dynamic list = response.data;
        if (list is Map && list.containsKey('data')) {
          list = list['data'];
        }
        if (list is Map && list.containsKey('items')) {
          list = list['items'];
        }
        if (list is List) {
          state = list
              .whereType<Map>()
              .map(
                (m) => InfluencerBookingModel.fromJson(
                  Map<String, dynamic>.from(m),
                ),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[ADMIN_INFLUENCER_BOOKINGS_ERROR] $e');
    }
  }

  Future<void> refresh() async => _fetchFromBackend();

  Future<void> approveBooking(dynamic bookingId) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.ensureAuthLoaded();
    try {
      await apiClient.post('/admin/influencer-bookings/$bookingId/approve');
      await _fetchFromBackend();
    } catch (e) {
      debugPrint('[ADMIN_APPROVE_ERROR] $e');
      state = state
          .map(
            (b) => b.bookingId == bookingId.toString()
                ? b.copyWith(status: 'Confirmed')
                : b,
          )
          .toList();
    }
  }

  Future<void> rejectBooking(dynamic bookingId) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.ensureAuthLoaded();
    try {
      await apiClient.post('/admin/influencer-bookings/$bookingId/reject');
      await _fetchFromBackend();
    } catch (e) {
      debugPrint('[ADMIN_REJECT_ERROR] $e');
      state = state
          .map(
            (b) => b.bookingId == bookingId.toString()
                ? b.copyWith(status: 'Cancelled')
                : b,
          )
          .toList();
    }
  }
}

final adminInfluencerBookingsProvider =
    NotifierProvider<
      AdminInfluencerBookingsNotifier,
      List<InfluencerBookingModel>
    >(AdminInfluencerBookingsNotifier.new);
