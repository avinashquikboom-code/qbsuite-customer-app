import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/user_role.dart';
import '../models/permission_model.dart';
import '../network/api_client.dart';
import '../network/app_url.dart';
import 'notification_service.dart';
import 'crm_access.dart';
import 'permission_manager.dart';
import 'secure_storage_service.dart';
import '../../shared/services/data_capture_service.dart';

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class UserData {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String name;
  final String role;
  final String rawRole;
  final String customerId;
  final String customerName;
  final String? employeeCode;
  final String? employeeId;
  final bool isCrmEligible;
  final String? crmCategory;
  final List<UserPermission> permissions;
  final List<UserPermission> effectivePermissions;

  UserData({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.name = '',
    required this.role,
    this.rawRole = '',
    required this.customerId,
    this.customerName = '',
    this.employeeCode,
    this.employeeId,
    this.isCrmEligible = false,
    this.crmCategory,
    this.permissions = const [],
    this.effectivePermissions = const [],
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role']?.toString() ?? '';
    final fName = (json['firstName'] ?? json['first_name'] ?? '')
        .toString()
        .trim();
    final lName = (json['lastName'] ?? json['last_name'] ?? '')
        .toString()
        .trim();
    final directName =
        (json['name'] ?? json['fullName'] ?? json['employeeName'] ?? '')
            .toString()
            .trim();
    final combinedName = directName.isNotEmpty
        ? directName
        : [fName, lName].where((s) => s.isNotEmpty).join(' ');

    String? empCode;
    String? empId = json['employeeId']?.toString();
    String empName = combinedName;
    if (json['employee'] is Map<String, dynamic>) {
      final empJson = json['employee'] as Map<String, dynamic>;
      empCode = (empJson['employeeCode'] ?? empJson['code'] ?? empJson['id'])
          ?.toString();
      empId ??= (empJson['id'] ?? empJson['employeeId'])?.toString();
      final empDirect = (empJson['name'] ?? empJson['fullName'] ?? '')
          .toString()
          .trim();
      final empF = (empJson['firstName'] ?? empJson['first_name'] ?? '')
          .toString()
          .trim();
      final empL = (empJson['lastName'] ?? empJson['last_name'] ?? '')
          .toString()
          .trim();
      final empComb = empDirect.isNotEmpty
          ? empDirect
          : [empF, empL].where((s) => s.isNotEmpty).join(' ');
      if (empComb.isNotEmpty) {
        empName = empComb;
      }
    }

    final List<UserPermission> parsedPerms = UserPermission.parseAny(
      json['permissions'],
    );
    final List<UserPermission> parsedEffectivePerms = UserPermission.parseAny(
      json['effectivePermissions'],
    );

    final employeeJson = json['employee'] is Map
        ? Map<String, dynamic>.from(json['employee'] as Map)
        : null;
    final categoryRaw = (json['crmCategory'] ?? employeeJson?['crmCategory'])
        ?.toString();
    final parsedCategory = parseCrmCategory(categoryRaw);
    final bool legacyCrmFlag =
        json['isCrmEligible'] == true ||
        json['crmMobileAccess'] == true ||
        (employeeJson != null &&
            ((employeeJson['isCrmEligible'] == true) ||
                (employeeJson['crmMobileAccess'] == true) ||
                (employeeJson['designation'] is Map &&
                    employeeJson['designation']['crmMobileAccess'] == true)));
    final bool crmAccess = parsedCategory == null
        ? legacyCrmFlag
        : parsedCategory == CrmEmployeeCategory.bpo ||
              parsedCategory == CrmEmployeeCategory.sales;

    return UserData(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      email: json['email']?.toString() ?? '',
      firstName: fName,
      lastName: lName,
      name: empName.isNotEmpty ? empName : combinedName,
      role: roleStr,
      rawRole: roleStr,
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      employeeCode: empCode ?? json['employeeCode']?.toString(),
      employeeId: empId,
      isCrmEligible: crmAccess,
      crmCategory: switch (parsedCategory) {
        CrmEmployeeCategory.bpo => 'BPO',
        CrmEmployeeCategory.visitor => 'VISITOR',
        CrmEmployeeCategory.sales => 'SALES',
        CrmEmployeeCategory.none => 'NONE',
        null => null,
      },
      permissions: parsedPerms,
      effectivePermissions: parsedEffectivePerms,
    );
  }
}

class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final UserData user;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final rootData = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    String aToken = '';
    String rToken = '';

    if (rootData['tokens'] is Map<String, dynamic>) {
      aToken = rootData['tokens']['accessToken']?.toString() ?? '';
      rToken = rootData['tokens']['refreshToken']?.toString() ?? '';
    } else {
      aToken = rootData['accessToken']?.toString() ?? '';
      rToken = rootData['refreshToken']?.toString() ?? '';
    }

    final userJson = rootData['user'] is Map<String, dynamic>
        ? rootData['user'] as Map<String, dynamic>
        : <String, dynamic>{};

    return LoginResponse(
      accessToken: aToken,
      refreshToken: rToken,
      user: UserData.fromJson(userJson),
    );
  }
}

class AuthService {
  final ApiClient _apiClient;

  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // Login user
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final cleanEmail = email.trim();
      final response = await _apiClient.post(
        AppUrl.login,
        data: LoginRequest(email: cleanEmail, password: password).toJson(),
      );

      if (response.statusCode == 200 && response.data != null) {
        final loginResponse = LoginResponse.fromJson(
          response.data as Map<String, dynamic>,
        );

        // Clear previous user cached data to prevent cross-account leak
        await SecureStorageService.clearAll();

        // Save tokens
        await SecureStorageService.saveTokens(
          accessToken: loginResponse.accessToken,
          refreshToken: loginResponse.refreshToken,
        );

        final parsedRole = UserRoleExtension.fromString(
          loginResponse.user.role,
        );

        // Save user data including user/employee name
        await SecureStorageService.saveUserData(
          userId: loginResponse.user.id,
          role: parsedRole.apiValue,
          email: loginResponse.user.email,
          customerId: loginResponse.user.customerId,
          customerName: loginResponse.user.customerName,
          name: loginResponse.user.name,
          firstName: loginResponse.user.firstName,
          lastName: loginResponse.user.lastName,
          employeeId: loginResponse.user.employeeId,
          employeeCode: loginResponse.user.employeeCode,
        );

        // Save and initialize user permissions in PermissionManager
        final activePerms = loginResponse.user.effectivePermissions.isNotEmpty
            ? loginResponse.user.effectivePermissions
            : loginResponse.user.permissions;

        await SecureStorageService.savePermissions(
          activePerms,
          tenantId: loginResponse.user.customerId,
          employeeId: loginResponse.user.employeeId,
          userId: loginResponse.user.id.toString(),
        );
        await SecureStorageService.saveCrmMobileAccess(
          loginResponse.user.isCrmEligible,
          tenantId: loginResponse.user.customerId,
          employeeId: loginResponse.user.employeeId,
          userId: loginResponse.user.id.toString(),
        );
        await SecureStorageService.saveCrmCategory(loginResponse.user.crmCategory);
        PermissionManager.instance.setPermissions(
          activePerms,
          role: loginResponse.user.role,
          employeeId: loginResponse.user.employeeId,
          tenantId: loginResponse.user.customerId,
          isCrmEligible: loginResponse.user.isCrmEligible,
          crmCategory: loginResponse.user.crmCategory,
        );

        // Configure ApiClient in-memory state
        _apiClient.setAuth(
          loginResponse.accessToken,
          loginResponse.user.customerId,
          refreshToken: loginResponse.refreshToken,
        );
        // Register the FCM token only after the authenticated API client is
        // ready; this keeps the token tied to the actual logged-in user.
        NotificationService.instance.registerTokenForAuthenticatedUser();

        return loginResponse;
      } else {
        throw Exception('Login failed: Invalid response from server');
      }
    } on DioException catch (e) {
      final msg =
          e.response?.data is Map &&
              (e.response?.data as Map).containsKey('message')
          ? (e.response?.data as Map)['message'].toString()
          : (e.message ?? 'Login failed');
      throw Exception(msg);
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Call backend logout endpoint (safe against network failures or offline mode)
  Future<int?> callBackendLogout() async {
    try {
      final response = await _apiClient.post(AppUrl.logout);
      return response.statusCode;
    } catch (e) {
      debugPrint('[LOGOUT] Backend logout API call error: $e');
      return null;
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      await callBackendLogout();
    } catch (_) {}
    try {
      PermissionManager.instance.clear();
      DataCaptureService.clearCache();
      await _apiClient.clearAuth(notifySessionExpired: false);
    } catch (e) {
      rethrow;
    }
  }

  /// Standard baseline permissions for an authenticated employee
  static List<UserPermission> defaultEmployeeCapabilities({bool isCrm = false}) {
    return <UserPermission>[
      for (final module in [
        'DASHBOARD',
        'CALENDAR',
        'MY_WORK',
        'CREATIVE_WORK',
        'WORK_EXECUTION',
        'ATTENDANCE',
        'LEAVE',
        'REMOTE_WORK',
        'TASKS',
        'SALARY',
        'NOTIFICATIONS',
        'PROFILE',
        'SETTINGS',
        'DATA_CAPTURE',
        if (isCrm) ...['LEADS', 'CUSTOMERS'],
        'VISITS',
        'EXPENSES',
        'LOAN',
      ])
        UserPermission(module: module, action: 'VIEW'),
      for (final module in ['CALENDAR', 'LEAVE', 'REMOTE_WORK', 'DATA_CAPTURE'])
        UserPermission(module: module, action: 'CREATE'),
      // Match the existing employee Data Capture actions allowed by the API.
      const UserPermission(module: 'DATA_CAPTURE', action: 'EDIT'),
      for (final action in [
        'PUNCH_IN',
        'PUNCH_OUT',
        'START_BREAK',
        'END_BREAK',
      ])
        UserPermission(module: 'ATTENDANCE', action: action),
    ];
  }

  // Compatibility adapter for existing widgets. These are UI capabilities only;
  // the API authenticates the account and enforces employee/team record assignments.
  Future<List<UserPermission>> fetchMyPermissions() async {
    final response = await _apiClient.get('/auth/me');
    if (response.statusCode != 200 || response.data is! Map) {
      throw Exception('Unable to load authenticated profile');
    }
    final envelope = Map<String, dynamic>.from(response.data as Map);
    final profile = envelope['data'] is Map
        ? Map<String, dynamic>.from(envelope['data'] as Map)
        : envelope;
    final employee = profile['employee'] is Map
        ? Map<String, dynamic>.from(profile['employee'] as Map)
        : null;
    final empStatus = employee?['status']?.toString().toUpperCase().trim();
    final isEmployeeAccount =
        profile['accountType']?.toString().toUpperCase() == 'EMPLOYEE' ||
        profile['role']?.toString().toUpperCase() == 'EMPLOYEE' ||
        profile['employeeId'] != null;

    if (employee == null && !isEmployeeAccount) {
      throw Exception('Active employee profile required');
    }
    if (empStatus != null &&
        empStatus != 'ACTIVE' &&
        empStatus != 'PROBATION') {
      throw Exception('Active employee profile required');
    }

    final crmCategory = parseCrmCategory(
      (profile['crmCategory'] ?? employee?['crmCategory'])?.toString(),
    );
    final isCrm = crmCategory == null
        ? profile['crmMobileAccess'] == true
        : crmCategory == CrmEmployeeCategory.bpo ||
              crmCategory == CrmEmployeeCategory.sales;
    final crmCategoryValue = switch (crmCategory) {
      CrmEmployeeCategory.bpo => 'BPO',
      CrmEmployeeCategory.visitor => 'VISITOR',
      CrmEmployeeCategory.sales => 'SALES',
      CrmEmployeeCategory.none => 'NONE',
      null => null,
    };
    final capabilities = defaultEmployeeCapabilities(isCrm: isCrm);

    final employeeIdStr =
        employee?['id']?.toString() ?? profile['employeeId']?.toString();
    final userIdStr = profile['id']?.toString();

    await SecureStorageService.savePermissions(
      capabilities,
      employeeId: employeeIdStr,
      userId: userIdStr,
    );
    await SecureStorageService.saveCrmCategory(crmCategoryValue);
    PermissionManager.instance.setPermissions(
      capabilities,
      role: profile['accountType']?.toString() ?? 'EMPLOYEE',
      employeeId: employeeIdStr,
      designationId: employee?['designationId']?.toString(),
      isCrmEligible: isCrm,
      crmCategory: crmCategoryValue,
    );
    return capabilities;
  }

  Future<void> refreshCustomerPermissions() async {
    final response = await _apiClient.get(AppUrl.profile);
    if (response.statusCode != 200 || response.data == null) {
      throw StateError(
        'Customer permissions API returned HTTP ${response.statusCode}',
      );
    }

    var raw = response.data;
    if (raw is Map && raw['data'] is Map) {
      raw = raw['data'];
    }
    if (raw is! Map) {
      throw const FormatException(
        'Customer permissions API returned an invalid response',
      );
    }
    if (!raw.containsKey('permissions') &&
        !raw.containsKey('effectivePermissions') &&
        !raw.containsKey('permissionKeys')) {
      throw const FormatException(
        'Customer permissions API response did not include permission data',
      );
    }

    final perms = <UserPermission>{
      ...UserPermission.parseAny(raw['permissions']),
      ...UserPermission.parseAny(raw['effectivePermissions']),
      ...UserPermission.parseAny(raw['permissionKeys']),
    }.toList();

    final role = await SecureStorageService.getUserRole();
    final tenantId = await SecureStorageService.getCustomerId();
    final userId = await SecureStorageService.getUserId();
    await SecureStorageService.savePermissions(
      perms,
      tenantId: tenantId,
      userId: userId?.toString(),
      allowEmpty: true,
    );
    PermissionManager.instance.setPermissions(
      perms,
      role: role,
      tenantId: tenantId,
    );
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final token = await SecureStorageService.getAccessToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get current user role
  Future<String?> getCurrentUserRole() async {
    try {
      return await SecureStorageService.getUserRole();
    } catch (e) {
      return null;
    }
  }
}
