import 'dart:async';
import 'dart:convert';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/views/auth/login_view.dart';
import '../../roles/employee/viewmodels/employee_profile_viewmodel.dart';
import '../../roles/employee/viewmodels/employee_attendance_viewmodel.dart';
import '../../roles/employee/viewmodels/work_permissions_viewmodel.dart';
import '../../roles/employee/viewmodels/employee_my_work_viewmodel.dart';
import '../../roles/employee/viewmodels/employee_ssm_viewmodel.dart';
import '../../roles/employee/viewmodels/employee_notification_viewmodel.dart';
import '../../roles/employee/viewmodels/employee_remote_work_viewmodel.dart';
import '../../roles/employee/viewmodels/employee_leave_viewmodel.dart';
import '../../roles/employee/viewmodels/employee_payroll_viewmodel.dart';
import '../../roles/employee/viewmodels/employee_loan_viewmodel.dart';
import '../../roles/employee/viewmodels/employee_claim_viewmodel.dart';
import '../../roles/employee/viewmodels/team_calendar_viewmodel.dart';
import '../../roles/employee/viewmodels/employee_calendar_viewmodel.dart';
import '../../shared/viewmodels/leads_viewmodel.dart';
import '../../shared/viewmodels/lead_stages_viewmodel.dart';
import '../models/user_role.dart';
import '../network/api_client.dart';
import '../services/auth_service.dart';
import '../services/crm_access.dart';
import '../services/employee_live_tracking_service.dart';
import '../services/notification_service.dart';
import '../services/permission_manager.dart';
import '../services/secure_storage_service.dart';





import '../../shared/services/data_capture_service.dart';


// Auth service provider
final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(apiClient: ref.read(apiClientProvider)),
);

// Login state provider
final loginStateProvider = NotifierProvider<LoginStateNotifier, LoginState>(
  LoginStateNotifier.new,
);

// Login state class
class LoginState {
  final bool isInitializing;
  final bool isLoading;
  final bool isLoggedIn;
  final String? error;
  final String? startupError;
  final UserRole? role;
  final String? userRole;
  final String? userEmail;
  final String? userName;
  final String? employeeCode;
  final String? employeeId;
  final String? customerId;
  final String? customerName;

  bool get hasStartupError => startupError != null && startupError!.isNotEmpty;

  LoginState({
    this.isInitializing = true,
    this.isLoading = false,
    this.isLoggedIn = false,
    this.error,
    this.startupError,
    this.role,
    this.userRole,
    this.userEmail,
    this.userName,
    this.employeeCode,
    this.employeeId,
    this.customerId,
    this.customerName,
  });

  LoginState copyWith({
    bool? isInitializing,
    bool? isLoading,
    bool? isLoggedIn,
    String? error,
    String? startupError,
    bool clearStartupError = false,
    UserRole? role,
    String? userRole,
    String? userEmail,
    String? userName,
    String? employeeCode,
    String? employeeId,
    String? customerId,
    String? customerName,
  }) {
    return LoginState(
      isInitializing: isInitializing ?? this.isInitializing,
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      error: error,
      startupError: clearStartupError
          ? null
          : (startupError ?? this.startupError),
      role: role ?? this.role,
      userRole: userRole ?? this.userRole,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      employeeCode: employeeCode ?? this.employeeCode,
      employeeId: employeeId ?? this.employeeId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
    );
  }
}

bool _isTokenExpired(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return false;
    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final map = jsonDecode(decoded);
    if (map is Map && map.containsKey('exp')) {
      final exp = map['exp'];
      if (exp is num) {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(
          exp.toInt() * 1000,
        );
        return DateTime.now().isAfter(
          expiryDate.subtract(const Duration(seconds: 15)),
        );
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}

// Login state notifier
class LoginStateNotifier extends Notifier<LoginState> {
  bool _isLoggingOut = false;

  @override
  LoginState build() {
    ref.onDispose(() {
      if (ApiClient.onSessionExpired == handleSessionExpired) {
        ApiClient.onSessionExpired = null;
      }
    });
    _checkLoginStatus();
    return LoginState(isInitializing: true);
  }

  // Check if user is already logged in
  Future<void> _checkLoginStatus() async {
    try {
      debugPrint('[AUTH] initialization started');
      debugPrint('[STARTUP] Auth restoration started');
      debugPrint('[AUTH_RESTORE]');
      debugPrint('starting: true');

      // Hook up session expired callback
      ApiClient.onSessionExpired = handleSessionExpired;

      final storageResults = await Future.wait([
        SecureStorageService.getAccessToken(),
        SecureStorageService.getRefreshToken(),
        SecureStorageService.getUserRole(),
        SecureStorageService.getUserEmail(),
        SecureStorageService.getUserName(),
        SecureStorageService.getEmployeeCode(),
        SecureStorageService.getEmployeeId(),
        SecureStorageService.getCustomerId(),
        SecureStorageService.getCustomerName(),
      ]).timeout(
        const Duration(seconds: 4),
        onTimeout: () => List.filled(9, null),
      );

      final accessToken = storageResults[0];
      final refreshToken = storageResults[1];
      final roleStr = storageResults[2];
      final email = storageResults[3];
      final userName = storageResults[4];
      final employeeCode = storageResults[5];
      final employeeId = storageResults[6];
      final customerId = storageResults[7];
      final customerName = storageResults[8];

      if (!ref.mounted) return;

      final parsedRole = UserRole.tryParse(roleStr);

      debugPrint('[AUTH_STARTUP]');
      debugPrint(
        'storedAccessToken: ${accessToken != null && accessToken.isNotEmpty}',
      );
      debugPrint(
        'storedRefreshToken: ${refreshToken != null && refreshToken.isNotEmpty}',
      );
      debugPrint('[STARTUP] token loaded');
      debugPrint('SESSION RESTORE');
      debugPrint('Stored Role: $roleStr');
      debugPrint(
        'accessTokenFound: ${accessToken != null && accessToken.isNotEmpty}',
      );
      debugPrint(
        'refreshTokenFound: ${refreshToken != null && refreshToken.isNotEmpty}',
      );
      debugPrint(
        'customerIdFound: ${customerId != null && customerId.isNotEmpty}',
      );
      debugPrint('userRole: $roleStr -> $parsedRole');

      final apiClient = ref.read(apiClientProvider);
      final hasStoredSession =
          (accessToken != null && accessToken.isNotEmpty) ||
          (refreshToken != null && refreshToken.isNotEmpty);
      if (hasStoredSession && parsedRole != UserRole.customer) {
        await SecureStorageService.clearAll();
        await apiClient.clearAuth(notifySessionExpired: false);
        PermissionManager.instance.clear();
        if (!ref.mounted) return;
        state = state.copyWith(
          isInitializing: false,
          isLoading: false,
          isLoggedIn: false,
          error: kCustomerAppAccessMessage,
        );
        return;
      }

      // Case 1: Active, non-expired access token
      if (accessToken != null &&
          accessToken.isNotEmpty &&
          !_isTokenExpired(accessToken)) {
        debugPrint('[AUTH] token validation result: valid');
        debugPrint('[STARTUP] token validation completed');
        apiClient.setAuth(
          accessToken,
          customerId ?? '',
          refreshToken: refreshToken,
        );

        final storedPerms = await SecureStorageService.getPermissions(
          tenantId: customerId,
          employeeId: employeeId,
        ).timeout(const Duration(seconds: 2), onTimeout: () => []);
        final storedCrmAccess = await SecureStorageService.getCrmMobileAccess(
          tenantId: customerId,
          employeeId: employeeId,
        ).timeout(const Duration(seconds: 2), onTimeout: () => false);
        if (!ref.mounted) return;
        if (storedPerms.isNotEmpty) {
          PermissionManager.instance.setPermissions(
            storedPerms,
            role: roleStr,
            employeeId: employeeId,
            tenantId: customerId,
            isCrmEligible: storedCrmAccess,
          );
          ref
              .read(permissionManagerProvider.notifier)
              .setPermissions(
                storedPerms,
                role: roleStr,
                employeeId: employeeId,
                tenantId: customerId,
                isCrmEligible: storedCrmAccess,
              );
        } else if (parsedRole == UserRole.employee) {
          ref.read(permissionManagerProvider.notifier).setLoading(true);
        }

        // For employees, proactively load/refresh effective permissions
        if (parsedRole == UserRole.employee) {
          if (storedPerms.isEmpty) {
            try {
              await refreshPermissions().timeout(
                const Duration(milliseconds: 2500),
              );
            } catch (_) {
              unawaited(refreshPermissions());
            }
          } else {
            unawaited(refreshPermissions());
          }
        }

        // For customers, proactively refresh effective permissions before UI render
        if (parsedRole == UserRole.customer) {
          try {
            await refreshCustomerPermissions().timeout(
              const Duration(milliseconds: 2000),
            );
          } catch (_) {
            unawaited(refreshCustomerPermissions());
          }
        }

        state = state.copyWith(
          isInitializing: false,
          isLoading: false,
          isLoggedIn: true,
          role: parsedRole ?? UserRole.customer,
          userRole: roleStr ?? 'CUSTOMER',
          userEmail: email,
          userName: userName,
          employeeCode: employeeCode,
          employeeId: employeeId,
          customerId: customerId,
          customerName: customerName,
          error: null,
        );

        debugPrint('[AUTH] navigating to DASHBOARD');
        debugPrint('[STARTUP] navigating to Login/Home');
        debugPrint('[STARTUP] Authenticated → Home');
        debugPrint('[AUTH_RESTORE]');
        debugPrint('status: authenticated');
        return;
      }

      // Case 2: Access token expired or missing, but refresh token is present
      if (refreshToken != null && refreshToken.isNotEmpty) {
        debugPrint(
          '[STARTUP] Attempting session restoration via refresh token',
        );
        debugPrint('[AUTH] refresh started');
        debugPrint('[STARTUP] Refresh started');

        final newAccessToken = await apiClient
            .refreshAuthDirectly(
              refreshToken: refreshToken,
              customerId: customerId ?? '',
            )
            .timeout(
              const Duration(seconds: 4),
              onTimeout: () => null,
            );

        if (!ref.mounted) return;

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          debugPrint('[AUTH] refresh success');
          debugPrint('[STARTUP] token validation completed');

          final storedPerms = await SecureStorageService.getPermissions(
            tenantId: customerId,
            employeeId: employeeId,
          ).timeout(const Duration(seconds: 2), onTimeout: () => []);
          final storedCrmAccess = await SecureStorageService.getCrmMobileAccess(
            tenantId: customerId,
            employeeId: employeeId,
          ).timeout(const Duration(seconds: 2), onTimeout: () => false);
          if (storedPerms.isNotEmpty) {
            PermissionManager.instance.setPermissions(
              storedPerms,
              role: roleStr,
              employeeId: employeeId,
              tenantId: customerId,
              isCrmEligible: storedCrmAccess,
            );
            ref
                .read(permissionManagerProvider.notifier)
                .setPermissions(
                  storedPerms,
                  role: roleStr,
                  employeeId: employeeId,
                  tenantId: customerId,
                  isCrmEligible: storedCrmAccess,
                );
          } else if (parsedRole == UserRole.employee) {
            ref.read(permissionManagerProvider.notifier).setLoading(true);
          }

          if (parsedRole == UserRole.employee) {
            if (storedPerms.isEmpty) {
              try {
                await refreshPermissions().timeout(
                  const Duration(milliseconds: 2500),
                );
              } catch (_) {
                unawaited(refreshPermissions());
              }
            } else {
              unawaited(refreshPermissions());
            }
          }

          // For customers, proactively refresh effective permissions before UI render
          if (parsedRole == UserRole.customer) {
            try {
              await refreshCustomerPermissions().timeout(
                const Duration(milliseconds: 2000),
              );
            } catch (_) {
              unawaited(refreshCustomerPermissions());
            }
          }

          state = state.copyWith(
            isInitializing: false,
            isLoading: false,
            isLoggedIn: true,
            role: parsedRole ?? UserRole.customer,
            userRole: roleStr ?? 'CUSTOMER',
            userEmail: email,
            userName: userName,
            employeeCode: employeeCode,
            employeeId: employeeId,
            customerId: customerId,
            customerName: customerName,
            error: null,
          );

          debugPrint('[AUTH] navigating to DASHBOARD');
          debugPrint('[STARTUP] navigating to Login/Home');
          debugPrint('[STARTUP] Authenticated → Home');
          debugPrint('[AUTH_RESTORE]');
          debugPrint('status: authenticated');
          return;
        } else {
          // If refresh failed (e.g. offline/network), check whether accessToken is genuinely still valid
          bool isAccessExpired = false;
          if (accessToken != null && accessToken.isNotEmpty) {
            try {
              final parts = accessToken.split('.');
              if (parts.length == 3) {
                final norm = base64Url.normalize(parts[1]);
                final dec = utf8.decode(base64Url.decode(norm));
                final map = jsonDecode(dec);
                if (map is Map && map['exp'] is int) {
                  final expSec = map['exp'] as int;
                  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                  isAccessExpired = expSec <= nowSec;
                }
              }
            } catch (_) {}
          }

          if (!isAccessExpired &&
              accessToken != null &&
              accessToken.isNotEmpty) {
            debugPrint(
              '[AUTH] Network offline during startup refresh; maintaining cached authenticated session with valid token',
            );
            apiClient.setAuth(
              accessToken,
              customerId ?? '',
              refreshToken: refreshToken,
            );

            final storedPerms = await SecureStorageService.getPermissions(
              tenantId: customerId,
              employeeId: employeeId,
            );
            final storedCrmAccess =
                await SecureStorageService.getCrmMobileAccess(
                  tenantId: customerId,
                  employeeId: employeeId,
                );
            PermissionManager.instance.setPermissions(
              storedPerms,
              role: roleStr,
              employeeId: employeeId,
              tenantId: customerId,
              isCrmEligible: storedCrmAccess,
            );
            ref
                .read(permissionManagerProvider.notifier)
                .setPermissions(
                  storedPerms,
                  role: roleStr,
                  employeeId: employeeId,
                  tenantId: customerId,
                  isCrmEligible: storedCrmAccess,
                );

            state = state.copyWith(
              isInitializing: false,
              isLoading: false,
              isLoggedIn: true,
              role: parsedRole ?? UserRole.customer,
              userRole: roleStr ?? 'CUSTOMER',
              userEmail: email,
              userName: userName,
              employeeCode: employeeCode,
              employeeId: employeeId,
              customerId: customerId,
              customerName: customerName,
              error: null,
            );

            debugPrint('[AUTH_RESTORE]');
            debugPrint('status: authenticated');
            return;
          } else {
            debugPrint(
              '[AUTH] Refresh failed and stored access token is expired; clearing session',
            );
            await apiClient.clearAuth(notifySessionExpired: false);
          }
        }
      }

      // Case 3: Genuinely unauthenticated (no tokens)
      debugPrint('[AUTH] No valid session tokens found');
      PermissionManager.instance.clear();
      ref.read(permissionManagerProvider.notifier).clear();
      state = state.copyWith(
        isInitializing: false,
        isLoading: false,
        isLoggedIn: false,
        role: null,
        userRole: null,
        userEmail: null,
        userName: null,
        employeeCode: null,
        customerId: null,
        customerName: null,
        error: null,
      );
      debugPrint('[AUTH] navigating to LOGIN');
      debugPrint('[STARTUP] navigating to Login/Home');
      debugPrint('[STARTUP] Unauthenticated → Login');
      debugPrint('[AUTH_RESTORE]');
      debugPrint('status: unauthenticated');
    } catch (e) {
      debugPrint('[STARTUP_ERROR] Exception in _checkLoginStatus: $e');
      if (!ref.mounted) return;
      PermissionManager.instance.clear();
      ref.read(permissionManagerProvider.notifier).clear();
      state = state.copyWith(
        isInitializing: false,
        isLoading: false,
        isLoggedIn: false,
        startupError: 'Unable to restore session: $e',
        role: null,
        userRole: null,
        userEmail: null,
        userName: null,
        employeeCode: null,
        customerId: null,
        customerName: null,
      );
      debugPrint('[AUTH_RESTORE]');
      debugPrint('status: unauthenticated (startup error)');
    }
  }

  Future<void> retryInitialization() async {
    state = state.copyWith(
      isInitializing: true,
      isLoading: false,
      clearStartupError: true,
    );
    await _checkLoginStatus();
  }

  void forceCompleteInitialization() {
    if (state.isInitializing || state.hasStartupError) {
      debugPrint('[STARTUP_WATCHDOG] Completing initialization check');
      state = state.copyWith(
        isInitializing: false,
        clearStartupError: true,
      );
    }
  }

  void handleSessionExpired() {
    if (_isLoggingOut) return;
    try {
      if (state.isLoggedIn) {
        debugPrint(
          '[SESSION_EXPIRED] Transitioning to unauthenticated login state',
        );
        unawaited(logout());
      }
    } catch (_) {}
  }

  // Public method to check login status
  Future<void> checkLoginStatus() async {
    await _checkLoginStatus();
  }

  // Login user
  Future<bool> login(String email, String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final authService = ref.read(authServiceProvider);
      final response = await authService.login(
        email: email,
        password: password,
      );

      final parsedRole = UserRoleExtension.fromString(response.user.role);

      debugPrint('[ROLE_PARSE]');
      debugPrint('API role: ${response.user.role}');
      debugPrint('Parsed role: ${parsedRole.name}');

      final activePerms = response.user.effectivePermissions.isNotEmpty
          ? response.user.effectivePermissions
          : response.user.permissions;
      ref
          .read(permissionManagerProvider.notifier)
          .setPermissions(
            activePerms,
            role: response.user.role,
            employeeId: response.user.employeeId,
            tenantId: response.user.customerId,
            isCrmEligible: response.user.isCrmEligible,
            crmCategory: response.user.crmCategory,
          );

      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        role: parsedRole,
        userRole: parsedRole.apiValue,
        userEmail: response.user.email,
        userName: response.user.name,
        employeeCode: response.user.employeeCode,
        employeeId: response.user.employeeId,
        customerId: response.user.customerId,
        customerName: response.user.customerName,
        error: null,
      );

      // Invalidate and refresh leadLimitProvider so new employee's quota is immediately loaded
      
      

      return true;
    } catch (e) {
      final cleanError = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isLoading: false, error: cleanError);
      return false;
    }
  }

  // Complete logout: API logout + token clearing + RBAC reset + provider invalidation + navigation reset
  Future<void> logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    try {
      await _completeLogout();
    } finally {
      _isLoggingOut = false;
    }
  }

  Future<void> _completeLogout() async {
    final currentEmpId =
        state.employeeId ?? await SecureStorageService.getEmployeeId();
    debugPrint('[LOGOUT DEBUG]');
    debugPrint('Logout started');
    debugPrint('[LOGOUT DEBUG]');
    debugPrint('Current employeeId: ${currentEmpId ?? "none"}');

    // 1. Terminate FCM & Live Tracking
    try {
      EmployeeLiveTrackingService().stopTracking();
      await NotificationService.instance.unregisterToken();
    } catch (e) {
      debugPrint('[LOGOUT DEBUG] FCM/Tracking stop error: $e');
    }

    // 2. Call backend logout API
    final authService = ref.read(authServiceProvider);
    int? apiStatus;
    try {
      apiStatus = await authService.callBackendLogout();
    } catch (_) {}
    debugPrint('[LOGOUT DEBUG]');
    debugPrint(
      'Logout API status: ${apiStatus != null ? "$apiStatus OK" : "completed"}',
    );

    // 3. Clear auth tokens & local storage
    try {
      await ref
          .read(apiClientProvider)
          .clearAuth(notifySessionExpired: false);
    } catch (e) {
      debugPrint('[LOGOUT DEBUG] Storage clear error: $e');
    }
    debugPrint('[LOGOUT DEBUG]');
    debugPrint('Access token cleared: true');
    debugPrint('[LOGOUT DEBUG]');
    debugPrint('Refresh token cleared: true');
    debugPrint('[LOGOUT DEBUG]');
    debugPrint('Employee session cleared: true');

    // 4. Reset PermissionManager & PermissionNotifier
    PermissionManager.instance.clear();
    ref.read(permissionManagerProvider.notifier).clear();
    debugPrint('[LOGOUT DEBUG]');
    debugPrint('PermissionManager reset: count=0, initialized=false');

    // 5. Invalidate all employee Riverpod providers & clear cached leads
    try {
      
      DataCaptureService.clearCache();
      ref.invalidate(leadsProvider);
      ref.invalidate(leadStagesProvider);
      ref.invalidate(employeeProfileProvider);
      ref.invalidate(employeeAttendanceProvider);
      WorkPermissionsNotifier.clearCache();
      ref.invalidate(workPermissionsProvider);
      ref.invalidate(employeeMyWorkProvider);
      ref.invalidate(employeeSSMProvider);
      ref.invalidate(employeeNotificationProvider);
      ref.invalidate(employeeRemoteWorkProvider);
      ref.invalidate(employeeLeaveProvider);
      ref.invalidate(employeePayrollProvider);
      ref.invalidate(employeeLoanProvider);
      ref.invalidate(employeeClaimProvider);
      ref.invalidate(teamCalendarProvider);
      ref.invalidate(employeeCalendarSelectedDateProvider);
      ref.invalidate(employeeCalendarFilterProvider);
      
      
      
      
      
    } catch (e) {
      debugPrint('[LOGOUT DEBUG] Invalidate providers error: $e');
    }

    // 6. Reset Auth State
    state = LoginState(isInitializing: false, isLoggedIn: false);
    debugPrint('[LOGOUT DEBUG]');
    debugPrint('Auth state reset: isLoggedIn=false');

    // 7. Clear navigation stack to LoginView
    final navKey = NotificationService.instance.navigatorKey;
    if (navKey.currentState != null) {
      navKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginView()),
        (route) => false,
      );
      debugPrint('[LOGOUT DEBUG]');
      debugPrint('Navigation stack cleared: true');
      AppToast.logoutSuccess();
    }
  }

  /// Resets the auth state back to clean unauthenticated state.
  void reset() {
    state = LoginState(isInitializing: false, isLoggedIn: false);
  }

  // Refresh permissions from backend
  Future<void> refreshPermissions() async {
    try {
      ref.read(permissionManagerProvider.notifier).setLoading(true);
      final authService = ref.read(authServiceProvider);
      final perms = await authService.fetchMyPermissions();
      final roleStr = await SecureStorageService.getUserRole();
      final isCrm = PermissionManager.instance.currentState.isCrmEligible;
      PermissionManager.instance.setPermissions(
        perms,
        role: roleStr,
        isCrmEligible: isCrm,
      );
      ref
          .read(permissionManagerProvider.notifier)
          .setPermissions(perms, role: roleStr, isCrmEligible: isCrm);
      debugPrint(
        '[AUTH_PROVIDER] refreshPermissions completed: ${perms.length} perms, isCrmEligible: $isCrm',
      );
    } catch (e) {
      debugPrint('[AUTH_PROVIDER] refreshPermissions error: $e');
      final current = ref.read(permissionManagerProvider);
      if (current.permissions.isEmpty) {
        final cached = await SecureStorageService.getPermissions();
        if (cached.isNotEmpty) {
          final roleStr = await SecureStorageService.getUserRole();
          final isCrm = await SecureStorageService.getCrmMobileAccess();
          PermissionManager.instance.setPermissions(
            cached,
            role: roleStr,
            isCrmEligible: isCrm,
          );
          ref
              .read(permissionManagerProvider.notifier)
              .setPermissions(cached, role: roleStr, isCrmEligible: isCrm);
          return;
        }

        final authState = state;
        if (authState.isLoggedIn &&
            (authState.role == UserRole.employee ||
                authState.userRole == 'EMPLOYEE')) {
          final roleStr = authState.userRole ?? 'EMPLOYEE';
          final defaults = AuthService.defaultEmployeeCapabilities();
          PermissionManager.instance.setPermissions(
            defaults,
            role: roleStr,
            employeeId: authState.employeeId,
            isCrmEligible: false,
          );
          ref
              .read(permissionManagerProvider.notifier)
              .setPermissions(
                defaults,
                role: roleStr,
                employeeId: authState.employeeId,
                isCrmEligible: false,
              );
          return;
        }

        ref
            .read(permissionManagerProvider.notifier)
            .setError('Failed to fetch workspace permissions. Tap to retry.');
      } else {
        ref.read(permissionManagerProvider.notifier).setLoading(false);
      }
    }
  }

  /// Refresh effective permissions for a customer from /auth/profile.
  /// Updates PermissionManager and SecureStorage so CUSTOMER_MARKETING and
  /// other module overrides are immediately reflected in the UI.
  Future<void> refreshCustomerPermissions() async {
    final permissionNotifier = ref.read(permissionManagerProvider.notifier);
    if (ref.read(permissionManagerProvider).permissions.isEmpty) {
      permissionNotifier.setLoading(true);
    }

    try {
      final authService = ref.read(authServiceProvider);
      await authService.refreshCustomerPermissions();
      // Sync the Riverpod state from the updated PermissionManager singleton
      if (ref.mounted) {
        ref
            .read(permissionManagerProvider.notifier)
            .setPermissions(
              PermissionManager.instance.currentState.permissions,
              role: PermissionManager.instance.currentState.role,
              tenantId: PermissionManager.instance.currentState.tenantId,
            );
      }
      debugPrint(
        '[AUTH_PROVIDER] refreshCustomerPermissions completed: ${PermissionManager.instance.currentState.permissions.length} perms',
      );
    } catch (e) {
      debugPrint('[AUTH_PROVIDER] refreshCustomerPermissions error: $e');
      if (ref.mounted &&
          ref.read(permissionManagerProvider).permissions.isEmpty) {
        permissionNotifier.setError(
          'Unable to load account modules. Tap to retry.',
        );
      }
      // Keep already loaded permissions available if a refresh fails.
    }
  }
}
