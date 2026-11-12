import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_url.dart';
import '../models/customer_profile_model.dart';

/// AsyncNotifier managing the authenticated Customer Profile state
class CustomerProfileNotifier extends AsyncNotifier<CustomerProfileModel?> {
  @override
  Future<CustomerProfileModel?> build() async {
    return _fetchProfile();
  }

  Future<CustomerProfileModel?> _fetchProfile() async {
    final apiClient = ref.watch(apiClientProvider);

    // Skip network call if user is not authenticated yet
    if (apiClient.token == null || apiClient.token!.trim().isEmpty) {
      debugPrint(
        '[PROFILE_PROVIDER] No active auth token. Skipping GET /customers/me.',
      );
      return null;
    }

    try {
      debugPrint('[PROFILE_REQUEST] GET ${AppUrl.customerProfile}');

      final response = await apiClient.get(AppUrl.customerProfile);

      debugPrint('[PROFILE_RESPONSE] status: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        dynamic payload = response.data;
        if (payload is Map && payload['data'] != null) {
          payload = payload['data'];
        }

        if (payload is Map<String, dynamic>) {
          final profile = CustomerProfileModel.fromJson(payload);

          // Update local SharedPreferences caches if needed for fast startup
          try {
            final prefs = await SharedPreferences.getInstance();
            if (profile.customerId.isNotEmpty) {
              await prefs.setString('customer_id', profile.customerId);
            }
            if (profile.name.isNotEmpty) {
              await prefs.setString('customer_name', profile.name);
            }
            if (profile.email != null && profile.email!.isNotEmpty) {
              await prefs.setString('user_email', profile.email!);
            }
          } catch (_) {}

          debugPrint(
            '[PROFILE_SUCCESS] Customer: ${profile.name} (${profile.customerId})',
          );
          return profile;
        }
      }
    } catch (e, st) {
      debugPrint('[PROFILE_ERROR] Failed fetching customer profile: $e');
      debugPrint('$st');
      rethrow;
    }
    return null;
  }

  /// Explicitly refresh the customer profile from backend
  Future<void> refreshProfile() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchProfile());
  }

  /// Update customer profile details via PATCH /api/v1/customers/me
  Future<bool> updateProfile(Map<String, dynamic> updateData) async {
    final apiClient = ref.read(apiClientProvider);
    if (apiClient.token == null || apiClient.token!.trim().isEmpty) {
      throw Exception('Authentication required');
    }

    try {
      debugPrint(
        '[PROFILE_UPDATE_REQUEST] PATCH ${AppUrl.customerProfileUpdate}',
      );
      final response = await apiClient.patch(
        AppUrl.customerProfileUpdate,
        data: updateData,
      );

      debugPrint('[PROFILE_UPDATE_RESPONSE] status: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        dynamic payload = response.data;
        if (payload is Map && payload['data'] != null) {
          payload = payload['data'];
        }

        if (payload is Map<String, dynamic>) {
          final updatedProfile = CustomerProfileModel.fromJson(payload);
          state = AsyncValue.data(updatedProfile);

          // Update local SharedPreferences
          try {
            final prefs = await SharedPreferences.getInstance();
            if (updatedProfile.name.isNotEmpty) {
              await prefs.setString('customer_name', updatedProfile.name);
            }
          } catch (_) {}

          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[PROFILE_UPDATE_ERROR] Failed updating customer profile: $e');
      rethrow;
    }
  }
}

/// Provider exposing authenticated Customer Profile
final customerProfileProvider =
    AsyncNotifierProvider<CustomerProfileNotifier, CustomerProfileModel?>(
      CustomerProfileNotifier.new,
    );
