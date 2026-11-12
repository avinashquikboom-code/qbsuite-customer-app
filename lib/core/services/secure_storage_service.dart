import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/permission_model.dart';

class SecureStorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userRoleKey = 'user_role';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _userFirstNameKey = 'user_first_name';
  static const String _userLastNameKey = 'user_last_name';
  static const String _customerIdKey = 'customer_id';
  static const String _customerNameKey = 'customer_name';
  static const String _customerBusinessKey = 'customer_business_name';

  static const String _employeeIdKey = 'employee_id';
  static const String _employeeCodeKey = 'employee_code';
  static const String _permissionsKey = 'user_permissions';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const Duration _storageTimeout = Duration(seconds: 5);
  static Map<String, String>? _mockStorage;

  static bool get _isTestEnv {
    if (_mockStorage != null) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        _mockStorage ??= <String, String>{};
        return true;
      }
    } catch (_) {}
    return false;
  }

  @visibleForTesting
  static void setMockInitialValues(Map<String, String> values) {
    _mockStorage = Map.from(values);
  }

  @visibleForTesting
  static void clearMockValues() {
    _mockStorage = null;
  }

  static Future<String?> _safeRead(String key) async {
    if (_isTestEnv && _mockStorage != null) {
      return _mockStorage![key];
    }
    // 1. Try Secure Storage
    try {
      final val = await _storage
          .read(key: key)
          .timeout(_storageTimeout, onTimeout: () => null);
      if (val != null && val.trim().isNotEmpty && val != 'null') {
        return val.trim();
      }
    } catch (e) {
      debugPrint('[SECURE_STORAGE_WARN] Read failed for $key: $e');
    }

    // 2. Multi-tier Fallback: SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefVal = prefs.getString(key);
      if (prefVal != null && prefVal.trim().isNotEmpty && prefVal != 'null') {
        return prefVal.trim();
      }
    } catch (_) {}

    return null;
  }

  static Future<void> _safeWrite(String key, String value) async {
    if (_isTestEnv && _mockStorage != null) {
      _mockStorage![key] = value;
      return;
    }

    // 1. Write to Secure Storage
    try {
      await _storage.write(key: key, value: value).timeout(_storageTimeout);
    } catch (e) {
      debugPrint('[SECURE_STORAGE_WARN] Write failed for $key: $e');
    }

    // 2. Multi-tier Backup: SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
  }

  static Future<void> _safeDelete(String key) async {
    if (_isTestEnv && _mockStorage != null) {
      _mockStorage!.remove(key);
      return;
    }
    try {
      await _storage.delete(key: key).timeout(_storageTimeout);
    } catch (e) {
      debugPrint('[SECURE_STORAGE_WARN] Delete failed for $key: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  static Future<void> _safeDeleteAll() async {
    if (_isTestEnv && _mockStorage != null) {
      _mockStorage!.clear();
      return;
    }
    try {
      await _storage.deleteAll().timeout(_storageTimeout);
    } catch (e) {
      debugPrint('[SECURE_STORAGE_WARN] DeleteAll failed: $e');
    }
  }

  // Save tokens
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await Future.wait([
        _safeWrite(_accessTokenKey, accessToken),
        _safeWrite(_refreshTokenKey, refreshToken),
        _safeWrite('accessToken', accessToken),
        _safeWrite('refreshToken', refreshToken),
      ]);
    } catch (_) {}

    debugPrint('[AUTH_PERSISTENCE]');
    debugPrint('accessTokenStored: ${accessToken.isNotEmpty}');
    debugPrint('refreshTokenStored: ${refreshToken.isNotEmpty}');
  }

  // Save user data
  static Future<void> saveUserData({
    required int userId,
    required String role,
    required String email,
    required String customerId,
    String? customerName,
    String? businessName,
    String? name,
    String? firstName,
    String? lastName,
    String? employeeId,
    String? employeeCode,
  }) async {
    try {
      await Future.wait([
        _safeWrite(_userIdKey, userId.toString()),
        _safeWrite(_userRoleKey, role),
        _safeWrite(_userEmailKey, email),
        _safeWrite(_customerIdKey, customerId),
        if (name != null && name.trim().isNotEmpty)
          _safeWrite(_userNameKey, name.trim())
        else
          _safeDelete(_userNameKey),
        if (firstName != null && firstName.trim().isNotEmpty)
          _safeWrite(_userFirstNameKey, firstName.trim())
        else
          _safeDelete(_userFirstNameKey),
        if (lastName != null && lastName.trim().isNotEmpty)
          _safeWrite(_userLastNameKey, lastName.trim())
        else
          _safeDelete(_userLastNameKey),
        if (customerName != null && customerName.isNotEmpty)
          _safeWrite(_customerNameKey, customerName)
        else
          _safeDelete(_customerNameKey),
        if (businessName != null && businessName.trim().isNotEmpty)
          _safeWrite(_customerBusinessKey, businessName.trim())
        else
          _safeDelete(_customerBusinessKey),
        if (employeeId != null && employeeId.isNotEmpty)
          _safeWrite(_employeeIdKey, employeeId)
        else
          _safeDelete(_employeeIdKey),
        if (employeeCode != null && employeeCode.isNotEmpty)
          _safeWrite(_employeeCodeKey, employeeCode)
        else
          _safeDelete(_employeeCodeKey),
      ]);
    } catch (_) {}

    debugPrint('[AUTH_PERSISTENCE]');
    debugPrint('customerIdStored: ${customerId.isNotEmpty}');
    debugPrint('userRoleStored: ${role.isNotEmpty}');
  }

  // Get user ID
  static Future<int?> getUserId() async {
    final uid = await _safeRead(_userIdKey);
    if (uid != null && uid.isNotEmpty) return int.tryParse(uid);
    return null;
  }

  // Get employee ID
  static Future<String?> getEmployeeId() async {
    return await _safeRead(_employeeIdKey);
  }

  // Get employee code
  static Future<String?> getEmployeeCode() async {
    return await _safeRead(_employeeCodeKey);
  }

  // Get user name
  static Future<String?> getUserName() async {
    return await _safeRead(_userNameKey);
  }

  // Get user first name
  static Future<String?> getFirstName() async {
    return await _safeRead(_userFirstNameKey);
  }

  // Get user last name
  static Future<String?> getLastName() async {
    return await _safeRead(_userLastNameKey);
  }

  // Get access token
  static Future<String?> getAccessToken() async {
    final token = await _safeRead(_accessTokenKey);
    if (token != null && token.isNotEmpty) return token;
    final legacy = await _safeRead('accessToken');
    if (legacy != null && legacy.isNotEmpty) return legacy;
    return await _safeRead('token');
  }

  // Get refresh token
  static Future<String?> getRefreshToken() async {
    final token = await _safeRead(_refreshTokenKey);
    if (token != null && token.isNotEmpty) return token;
    return await _safeRead('refreshToken');
  }

  // Get user role
  static Future<String?> getUserRole() async {
    return await _safeRead(_userRoleKey);
  }

  // Get user email
  static Future<String?> getUserEmail() async {
    return await _safeRead(_userEmailKey);
  }

  // Get customer ID
  static Future<String?> getCustomerId() async {
    return await _safeRead(_customerIdKey);
  }

  // Get customer Name
  static Future<String?> getCustomerName() async {
    return await _safeRead(_customerNameKey);
  }

  static String _resolveScopedPermissionsKey({
    String? tenantId,
    String? employeeId,
    String? userId,
  }) {
    final t =
        (tenantId != null && tenantId.trim().isNotEmpty && tenantId != 'null')
        ? tenantId.trim()
        : 'default';
    final e =
        (employeeId != null &&
            employeeId.trim().isNotEmpty &&
            employeeId != 'null')
        ? employeeId.trim()
        : ((userId != null && userId.trim().isNotEmpty && userId != 'null')
              ? userId.trim()
              : 'current');
    return 'permissions:$t:$e';
  }

  // Save permissions (keyed by tenant/company and employee/user ID to prevent permission leakage)
  static Future<void> savePermissions(
    List<UserPermission> permissions, {
    String? tenantId,
    String? employeeId,
    String? userId,
    bool allowEmpty = false,
  }) async {
    // STEP 7: Prevent persisting empty permissions [] which would overwrite valid cache and be reused forever
    if (permissions.isEmpty && !allowEmpty) {
      debugPrint(
        '[SECURE_STORAGE] savePermissions: Skipping persist of empty permissions list',
      );
      return;
    }

    try {
      final jsonStr = jsonEncode(permissions.map((p) => p.toJson()).toList());
      // 1. Write to active fallback key
      await _safeWrite(_permissionsKey, jsonStr);

      // 2. Write to tenant/employee-scoped key
      final t = tenantId ?? await getCustomerId();
      final e = employeeId ?? await getEmployeeId();
      final u = userId ?? (await getUserId())?.toString();
      final scopedKey = _resolveScopedPermissionsKey(
        tenantId: t,
        employeeId: e,
        userId: u,
      );
      await _safeWrite(scopedKey, jsonStr);

      debugPrint(
        '[SECURE_STORAGE] savePermissions: saved ${permissions.length} perms under key: $scopedKey and $_permissionsKey',
      );
    } catch (e) {
      debugPrint('[SECURE_STORAGE_WARN] savePermissions error: $e');
    }
  }

  // Get permissions (checks scoped key first, falls back to active key)
  static Future<List<UserPermission>> getPermissions({
    String? tenantId,
    String? employeeId,
    String? userId,
  }) async {
    try {
      final t = tenantId ?? await getCustomerId();
      final e = employeeId ?? await getEmployeeId();
      final u = userId ?? (await getUserId())?.toString();
      final scopedKey = _resolveScopedPermissionsKey(
        tenantId: t,
        employeeId: e,
        userId: u,
      );

      // 1. Check scoped key
      var jsonStr = await _safeRead(scopedKey);

      // 2. Fallback to active key if scoped is not yet written
      if (jsonStr == null || jsonStr.isEmpty) {
        jsonStr = await _safeRead(_permissionsKey);
      }

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final list = decoded
              .whereType<Map>()
              .map(
                (item) =>
                    UserPermission.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
          return list;
        }
      }
    } catch (e) {
      debugPrint('[SECURE_STORAGE_WARN] getPermissions error: $e');
    }
    return [];
  }

  // Save CRM Mobile Access eligibility
  static const String _crmMobileAccessKey = 'crm_mobile_access';

  static Future<void> saveCrmMobileAccess(
    bool eligible, {
    String? tenantId,
    String? employeeId,
    String? userId,
  }) async {
    try {
      final val = eligible ? 'true' : 'false';
      await _safeWrite(_crmMobileAccessKey, val);
      final t = tenantId ?? await getCustomerId();
      final targetId =
          employeeId ??
          await getEmployeeId() ??
          userId ??
          (await getUserId())?.toString() ??
          'default';
      final scopedKey = 'crm_access:$t:$targetId';
      await _safeWrite(scopedKey, val);
      debugPrint(
        '[SECURE_STORAGE] saveCrmMobileAccess: saved eligible=$eligible under $scopedKey',
      );
    } catch (e) {
      debugPrint('[SECURE_STORAGE_WARN] saveCrmMobileAccess error: $e');
    }
  }

  // Get CRM Mobile Access eligibility
  static Future<bool> getCrmMobileAccess({
    String? tenantId,
    String? employeeId,
    String? userId,
  }) async {
    try {
      final t = tenantId ?? await getCustomerId();
      final targetId =
          employeeId ??
          await getEmployeeId() ??
          userId ??
          (await getUserId())?.toString() ??
          'default';
      final scopedKey = 'crm_access:$t:$targetId';
      var val = await _safeRead(scopedKey);
      if (val == null || val.isEmpty) {
        val = await _safeRead(_crmMobileAccessKey);
      }
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  static const String _crmCategoryKey = 'crm_employee_category';

  static Future<void> saveCrmCategory(String? category) async {
    try {
      final value = (category ?? '').trim().toUpperCase();
      if (value.isEmpty) {
        await _safeDelete(_crmCategoryKey);
        return;
      }
      await _safeWrite(_crmCategoryKey, value);
    } catch (e) {
      debugPrint('[SECURE_STORAGE_WARN] saveCrmCategory error: $e');
    }
  }

  static Future<String?> getCrmCategory() async {
    try {
      final value = await _safeRead(_crmCategoryKey);
      if (value == null || value.isEmpty) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  // Clear all data (logout / expired session cleanup)
  // Generic raw key-value access for non-standard caching
  static Future<String?> readRaw(String key) async => _safeRead(key);
  static Future<void> writeRaw(String key, String value) async =>
      _safeWrite(key, value);
  static Future<void> deleteRaw(String key) async => _safeDelete(key);

  static Future<void> clearAll() async {
    try {
      await _safeDeleteAll();
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
      await prefs.remove('token');
      await prefs.remove(_userIdKey);
      await prefs.remove(_userRoleKey);
      await prefs.remove(_permissionsKey);
      await prefs.remove(_crmMobileAccessKey);
      await prefs.remove('auth_user_role');
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userNameKey);
      await prefs.remove(_userFirstNameKey);
      await prefs.remove(_userLastNameKey);
      await prefs.remove(_customerIdKey);
      await prefs.remove(_customerNameKey);
      await prefs.remove(_employeeIdKey);
      await prefs.remove(_employeeCodeKey);
      await prefs.remove('tenant_id');
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('customer_id');
      await prefs.remove('customer_name');
      await prefs.remove('customer_business_name');
      await prefs.remove('company_name');
      await prefs.remove('user_full_name');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      await prefs.remove('user_role');
      await prefs.remove('user_permissions');
      await prefs.remove('crm_mobile_access');
      await prefs.remove('is_logged_in');
      await prefs.remove('session_active');
      await prefs.remove('quikboom_customer_cached_subscription');
      await prefs.remove('quikboom_customer_cached_orders');
      await prefs.remove('work_permissions_cache');
      final allKeys = prefs.getKeys();
      for (final k in allKeys) {
        if (k.startsWith('quikboom_customer_cached_subscription') ||
            k.startsWith('quikboom_customer_cached_plans') ||
            k.startsWith('quikboom_customer_cached_orders') ||
            k.startsWith('permissions:') ||
            k.startsWith('crm_access:') ||
            k.startsWith('work_permissions_cache')) {
          await prefs.remove(k);
        }
      }
    } catch (_) {}
  }
}
