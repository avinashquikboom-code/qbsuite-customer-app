import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/work_permission_model.dart';
import '../services/employee_api_service.dart';
import 'package:quickboom_crm_customer/core/services/secure_storage_service.dart';

class WorkPermissionsState {
  final EmployeeWorkPermissions permissions;
  final bool isLoading;
  final String? errorMessage;

  const WorkPermissionsState({
    required this.permissions,
    this.isLoading = false,
    this.errorMessage,
  });

  bool hasWorkPermission(String moduleKey) => permissions.hasPermission(moduleKey);

  WorkPermissionsState copyWith({
    EmployeeWorkPermissions? permissions,
    bool? isLoading,
    String? errorMessage,
  }) => WorkPermissionsState(
    permissions: permissions ?? this.permissions,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: errorMessage,
  );
}

class WorkPermissionsNotifier extends Notifier<WorkPermissionsState> {
  @override
  WorkPermissionsState build() {
    // Attempt to restore from cache to prevent flash, then update from API
    Future.microtask(() => _loadFromCacheThenApi());
    return WorkPermissionsState(
      permissions: EmployeeWorkPermissions.empty(),
      isLoading: true,
    );
  }

  /// Load cached WorkPermissions first (instant), then refresh from API in background.
  Future<void> _loadFromCacheThenApi() async {
    try {
      final cached = await _loadCachedWorkPermissions();
      if (cached != null) {
        state = state.copyWith(permissions: cached, isLoading: false);
        debugPrint(
          '[WORK_PERMISSIONS] Restored ${cached.workPermissions.length} modules from cache.',
        );
      }
    } catch (e) {
      debugPrint('[WORK_PERMISSIONS] Cache restore error: $e');
    }
    // Always fetch fresh from API
    await loadPermissions();
  }

  Future<String?> _getCacheKey() async {
    final t = await SecureStorageService.getCustomerId();
    final e = await SecureStorageService.getEmployeeId();
    if (t == null || t == '0' || e == null || e == '0') return null;
    return 'work_permissions_cache:${t}_$e';
  }

  Future<EmployeeWorkPermissions?> _loadCachedWorkPermissions() async {
    try {
      final key = await _getCacheKey();
      if (key == null) return null;
      final raw = await SecureStorageService.readRaw(key);
      if (raw == null || raw.isEmpty) return null;
      final Map<String, dynamic> json = Map<String, dynamic>.from(
        jsonDecode(raw),
      );
      return EmployeeWorkPermissions.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheWorkPermissions(EmployeeWorkPermissions perms) async {
    // Prevent overwriting valid cache with empty permissions
    if (perms.workPermissions.isEmpty && perms.effectivePermissions.isEmpty) {
      return;
    }
    try {
      final key = await _getCacheKey();
      if (key == null) return;
      final json = {
        'role': perms.role,
        'workPermissions': perms.workPermissions,
        'effectivePermissions': perms.effectivePermissions,
        'commonModules': perms.commonModules,
        'isCrmEligible': perms.isCrmEligible,
        'crmMobileAccess': perms.isCrmEligible,
        if (perms.employeeId != null) 'employeeId': perms.employeeId,
        if (perms.employeeCode != null) 'employeeCode': perms.employeeCode,
        if (perms.firstName != null) 'firstName': perms.firstName,
        if (perms.lastName != null) 'lastName': perms.lastName,
      };
      final encoded = jsonEncode(json);
      await SecureStorageService.writeRaw(key, encoded);
    } catch (e) {
      debugPrint('[WORK_PERMISSIONS] Cache write error: $e');
    }
  }

  /// Clear employee work permissions cache on logout to prevent leakage across sessions
  static Future<void> clearCache() async {
    try {
      final t = await SecureStorageService.getCustomerId();
      final e = await SecureStorageService.getEmployeeId();
      if (t != null && e != null) {
        await SecureStorageService.deleteRaw('work_permissions_cache:${t}_$e');
      }
      await SecureStorageService.deleteRaw('work_permissions_cache');
    } catch (_) {}
  }

  void reset() {
    state = WorkPermissionsState(
      permissions: EmployeeWorkPermissions.empty(),
      isLoading: false,
    );
  }

  EmployeeApiService get _apiService => ref.read(employeeApiServiceProvider);

  Future<void> loadPermissions() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final perms = await _apiService.getMyWorkPermissions();

      await _cacheWorkPermissions(perms);
      state = state.copyWith(
        permissions: perms,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[WORK_PERMISSIONS_NOTIFIER] loadPermissions error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load work permissions.',
      );
    }
  }

  Future<void> refresh() async {
    await loadPermissions();
  }

  bool hasWorkPermission(String moduleKey) {
    return state.hasWorkPermission(moduleKey);
  }


}

final workPermissionsProvider =
    NotifierProvider<WorkPermissionsNotifier, WorkPermissionsState>(
      WorkPermissionsNotifier.new,
    );
