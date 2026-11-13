import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:dio/dio.dart';
import 'package:quickboom_crm_customer/core/models/user_role.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import 'package:quickboom_crm_customer/core/services/secure_storage_service.dart';
import 'package:quickboom_crm_customer/core/services/notification_service.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/core/services/auth_service.dart';
import 'package:quickboom_crm_customer/core/models/permission_model.dart';
import 'package:quickboom_crm_customer/core/services/crm_access.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/shared/widgets/auth/access_restricted_dialog.dart';
import 'package:quickboom_crm_customer/shared/widgets/auth/auth_header.dart';
import 'package:quickboom_crm_customer/shared/widgets/auth/login_input_field.dart';
import 'package:quickboom_crm_customer/shared/widgets/auth/secure_login_card.dart';
import 'package:quickboom_crm_customer/shared/widgets/auth/secure_verification_card.dart';
import 'package:quickboom_crm_customer/shared/widgets/auth/otp_input_field.dart';
import 'package:quickboom_crm_customer/roles/employee/views/dashboard_view.dart';
import 'package:quickboom_company_admin/roles/company_admin/views/company_admin_main_view.dart';
import 'package:quickboom_crm_customer/roles/customer/views/customer_dashboard_view.dart';



import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_attendance_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_profile_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/work_permissions_viewmodel.dart';
import 'customer_registration_view.dart';
import 'forgot_password_view.dart';

enum MobileUserRole { employee, customer, admin }
enum LoginMethod { email, mobile, employeeId }
enum LoginStage { input, otp, verifying }

class LoginView extends ConsumerStatefulWidget {
  final MobileUserRole initialRole;

  const LoginView({super.key, this.initialRole = MobileUserRole.customer});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  // Controllers
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  // State
  late MobileUserRole _currentRole;
  LoginMethod _loginMethod = LoginMethod.email;
  LoginStage _stage = LoginStage.input;
  bool _isPasswordMode = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  String? _identifierError;

  // Loading & network state
  bool _isLoading = false;
  int _verifyingStep = 0; // 0: Validating OTP, 1: Authenticating, 2: Loading data

  // OTP state
  String _enteredOtp = '';
  String _maskedDestination = '';
  int _resendCountdown = 60;
  Timer? _countdownTimer;
  DateTime? _mobileOtpNextRequestAt;
  String? _requestedMobile;
  int _otpInputVersion = 0;
  bool _mobileOtpSent = false;
  String? _otpError;

  // Authorization error state
  String? _accessRestrictedTitle;
  String? _accessRestrictedMessage;

  bool get _isMobileLogin => _loginMethod == LoginMethod.mobile;

  bool get _usesPassword => _isPasswordMode;

  String? _normalizedMobile() {
    var digits = _identifierController.text.trim().replaceAll(
      RegExp(r'[\s+\-()]'),
      '',
    );
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? '+91$digits' : null;
  }

  void _resetMobileOtp() {
    if (_isLoading) return;
    setState(() {
      _mobileOtpSent = false;
      _enteredOtp = '';
      _otpError = null;
    });
    _countdownTimer?.cancel();
  }

  @override
  void initState() {
    super.initState();
    _currentRole = MobileUserRole.customer;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestAndroidNotificationPermission();
      final denied = ref.read(loginStateProvider).error;
      if (denied != null && denied.isNotEmpty && mounted) {
        _showAccessRestrictedUI(
          title: kCrmAccessRestrictedTitle,
          message: denied,
        );
      }
    });
  }

  void _showAccessRestrictedUI({String? title, String? message}) {
    if (!mounted) return;
    final resolvedTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : kCrmAccessRestrictedTitle;
    final resolvedMessage = (message != null && message.trim().isNotEmpty)
        ? message.trim()
        : kCrmAccessRestrictedMessage;

    setState(() {
      _isLoading = false;
      _stage = LoginStage.input;
      _accessRestrictedTitle = resolvedTitle;
      _accessRestrictedMessage = resolvedMessage;
    });

    showAccessRestrictedDialog(
      context,
      title: resolvedTitle,
      message: resolvedMessage,
      onTryAnotherAccount: _clearFormForAnotherAccount,
    );
  }

  void _onFieldChanged(String val) {
    if (_identifierError != null || _accessRestrictedMessage != null) {
      setState(() {
        _identifierError = null;
        _accessRestrictedTitle = null;
        _accessRestrictedMessage = null;
      });
    }
  }

  void _clearFormForAnotherAccount() {
    setState(() {
      _identifierController.clear();
      _passwordController.clear();
      _enteredOtp = '';
      _otpError = null;
      _identifierError = null;
      _mobileOtpSent = false;
      _isPasswordVisible = false;
      _isLoading = false;
      _accessRestrictedTitle = null;
      _accessRestrictedMessage = null;
      _stage = LoginStage.input;
    });
    _countdownTimer?.cancel();
    unawaited(SecureStorageService.clearAll());
    unawaited(ref.read(apiClientProvider).clearAuth(notifySessionExpired: false));
    PermissionManager.instance.clear();
    ref.read(loginStateProvider.notifier).reset();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer({int seconds = 60}) {
    _countdownTimer?.cancel();
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    setState(() => _resendCountdown = seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = deadline.difference(DateTime.now()).inMilliseconds;
      if (remaining > 0) {
        setState(() => _resendCountdown = (remaining / 1000).ceil());
      } else {
        setState(() => _resendCountdown = 0);
        timer.cancel();
      }
    });
  }

  String _maskDestinationLocally(String raw, LoginMethod method) {
    if (method == LoginMethod.email) {
      final parts = raw.split('@');
      if (parts.length == 2) {
        final name = parts[0];
        final domain = parts[1];
        if (name.length <= 2) {
          return '${name[0]}***@$domain';
        }
        return '${name[0]}***${name[name.length - 1]}@$domain';
      }
      return raw;
    } else if (method == LoginMethod.mobile) {
      final clean = raw.replaceAll(RegExp(r'\s+'), '');
      if (clean.length >= 4) {
        final last4 = clean.substring(clean.length - 4);
        return '+91 ******$last4';
      }
      return raw;
    } else {
      // Employee ID
      if (raw.length > 3) {
        return '${raw.substring(0, 3)}-***';
      }
      return raw;
    }
  }

  // ==========================================
  // SEND OTP
  // ==========================================
  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  bool _acceptsEmployeeCode() => false;

  void _putIdentifier(Map<String, dynamic> body, String rawVal) {
    if (_isMobileLogin) {
      body['mobile'] = _normalizedMobile() ?? (rawVal.startsWith('+') ? rawVal : '+91$rawVal');
      return;
    }
    if (_acceptsEmployeeCode() && !_isValidEmail(rawVal)) {
      body['employeeId'] = rawVal;
      return;
    }
    body['email'] = rawVal.toLowerCase();
  }

  String? _validateIdentifier() {
    final rawVal = _identifierController.text.trim();
    if (_loginMethod == LoginMethod.email || _loginMethod == LoginMethod.employeeId) {
      if (rawVal.isEmpty) {
        return _acceptsEmployeeCode()
            ? 'Please enter your email or Employee ID'
            : 'Please enter your email';
      }
      if (_acceptsEmployeeCode()) {
        if (rawVal.contains('@') && !_isValidEmail(rawVal)) {
          return 'Please enter a valid email address';
        }
        return null;
      }
      if (!_isValidEmail(rawVal)) return 'Please enter a valid email address';
      return null;
    }
    if (_loginMethod == LoginMethod.mobile) {
      if (_normalizedMobile() == null) {
        return 'Please enter a valid 10-digit mobile number';
      }
    }
    return null;
  }

  Future<void> _handleSendOtp({bool isResend = false}) async {
    if (_isLoading) return;
    if (isResend && _resendCountdown > 0) return;

    final validationError = _validateIdentifier();
    if (validationError != null) {
      setState(() => _identifierError = validationError);
      AppToast.warning(context, validationError);
      return;
    }
    setState(() {
      _identifierError = null;
      _otpError = null;
    });

    final rawVal = _identifierController.text.trim();
    final mobile = _isMobileLogin ? _normalizedMobile() : null;
    if (mobile != null && mobile == _requestedMobile &&
        _mobileOtpNextRequestAt != null) {
      final remaining = _mobileOtpNextRequestAt!
          .difference(DateTime.now()).inMilliseconds;
      if (remaining > 0) {
        AppToast.warning(context,
            'Please wait ${(remaining / 1000).ceil()} seconds before requesting a new OTP.');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final Map<String, dynamic> body = {};
      _putIdentifier(body, rawVal);

      final resp = await apiClient.post(AppUrl.sendOtp, data: body);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        dynamic payload = resp.data;
        if (payload is Map && payload['data'] != null) {
          payload = payload['data'];
        }

        final returnedDest = payload is Map ? payload['destination']?.toString() : null;
        final masked = (returnedDest != null && returnedDest.isNotEmpty)
            ? returnedDest
            : _maskDestinationLocally(rawVal, _loginMethod);

        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _maskedDestination = masked;
          _enteredOtp = '';
          _otpInputVersion++;
          if (_isMobileLogin) {
            _mobileOtpSent = true;
            _requestedMobile = mobile;
            _mobileOtpNextRequestAt = DateTime.now().add(const Duration(seconds: 60));
          } else {
            _stage = LoginStage.otp;
          }
        });

        _startResendTimer(seconds: 60);
        AppToast.success(
          context,
          isResend ? 'OTP resent successfully' : 'OTP sent successfully',
        );
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        AppToast.error(context, 'Failed to send OTP. Please try again.');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mobile != null) {
        final data = e.response?.data;
        final message = data is Map ? data['message']?.toString() ?? '' : '';
        final cooldown = RegExp(r'Please wait (\d+) seconds').firstMatch(message);
        final seconds = int.tryParse(cooldown?.group(1) ?? '');
        if (seconds != null && seconds > 0) {
          _requestedMobile = mobile;
          _mobileOtpNextRequestAt = DateTime.now().add(Duration(seconds: seconds));
          _startResendTimer(seconds: seconds);
        }
      }
      _handleDioError(e, defaultMsg: 'Failed to send OTP');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppToast.error(context, 'An unexpected error occurred while sending OTP');
    }
  }

  // ==========================================
  // VERIFY OTP
  // ==========================================
  Future<void> _handleVerifyOtp(String otp) async {
    if (_isLoading || !RegExp(r'^\d{6}$').hasMatch(otp)) return;

    final rawVal = _identifierController.text.trim();
    setState(() {
      _isLoading = true;
      _otpError = null;
      if (!_isMobileLogin) {
        _stage = LoginStage.verifying;
        _verifyingStep = 0; // Validating OTP
      }
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final Map<String, dynamic> body = {'otp': otp};
      _putIdentifier(body, rawVal);

      final resp = await apiClient.post(AppUrl.verifyOtp, data: body);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (!mounted) return;
        if (!_isMobileLogin) {
          setState(() => _verifyingStep = 1); // Authenticating account
        }

        dynamic payload = resp.data;
        if (payload is Map && payload['data'] != null) {
          payload = payload['data'];
        }

        if (!mounted) return;
        if (!_isMobileLogin) {
          setState(() => _verifyingStep = 2); // Loading your data...
        }

        final userObj = payload is Map && payload['user'] is Map ? payload['user'] as Map : null;
        final identifierToUse = userObj?['email']?.toString() ?? rawVal;

        await _processAuthSuccess(payload as Map<String, dynamic>, identifier: identifierToUse);
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _otpError = 'OTP verification failed';
          if (!_isMobileLogin) {
            _stage = LoginStage.otp;
          }
        });
        AppToast.error(context, 'OTP verification failed');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      String? backendMsg;
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        backendMsg = data['message'].toString();
      }
      setState(() {
        _isLoading = false;
        _otpError = backendMsg ?? 'Invalid or expired OTP';
        if (!_isMobileLogin) {
          _stage = LoginStage.otp;
        }
      });
      _handleDioError(e, defaultMsg: 'Invalid or expired OTP');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpError = 'An unexpected error occurred during OTP verification';
        if (!_isMobileLogin) {
          _stage = LoginStage.otp;
        }
      });
      AppToast.error(context, 'An unexpected error occurred during OTP verification');
    }
  }

  // ==========================================
  // PASSWORD LOGIN FLOW (EXISTING REUSED)
  // ==========================================
  Future<void> _handlePasswordLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    final validationError = _validateIdentifier();
    if (validationError != null) {
      setState(() => _identifierError = validationError);
      AppToast.warning(context, validationError);
      return;
    }
    setState(() => _identifierError = null);

    if (password.isEmpty) {
      AppToast.warning(context, 'Please enter your Password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);

      const endpoint = AppUrl.loginCustomer;

      final loginIdentifier = _isMobileLogin
          ? (_normalizedMobile() ?? identifier.trim())
          : identifier.trim().toLowerCase();
      final resp = await apiClient.post(
        endpoint,
        data: {'email': loginIdentifier, 'password': password},
      );

      if (resp.statusCode == 200 && resp.data != null) {
        dynamic payload = resp.data;
        if (payload is Map && payload['data'] != null) {
          payload = payload['data'];
        }

        await _processAuthSuccess(payload as Map<String, dynamic>, identifier: loginIdentifier);
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          AppToast.error(context, 'Login failed with status: ${resp.statusCode}');
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _handleDioError(e, defaultMsg: 'Login failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.error(context, 'An unexpected error occurred during login.');
      }
    }
  }

  // ==========================================
  // SHARED AUTH RESOLUTION & DATA HYDRATION
  // ==========================================
  Future<void> _processAuthSuccess(Map<String, dynamic> payload, {required String identifier}) async {
    final tokens = payload['tokens'] as Map<String, dynamic>?;
    final user = payload['user'] as Map<String, dynamic>?;

    final accessToken =
        tokens?['accessToken']?.toString() ??
        payload['accessToken']?.toString() ??
        '';
    final refreshToken =
        tokens?['refreshToken']?.toString() ??
        payload['refreshToken']?.toString() ??
        '';
    final customerIdVal =
        user?['customerId']?.toString() ??
        (user?['employee'] is Map
            ? user!['employee']['customerId']?.toString()
            : null) ??
        '';
    final uFirst = (user?['firstName']?.toString() ?? '').trim();
    final uMiddle = (user?['middleName']?.toString() ?? '').trim();
    final rawLast = (user?['lastName']?.toString() ?? '').trim();
    final bName =
        (user?['businessName']?.toString() ??
                user?['companyName']?.toString() ??
                (user?['customer'] is Map
                    ? (user?['customer']['companyName']?.toString() ??
                          user?['customer']['name']?.toString() ??
                          '')
                    : ''))
            .trim();
    final compLower = bName.toLowerCase();
    final uLast =
        (rawLast.isNotEmpty &&
            (rawLast.toLowerCase() == compLower ||
                (compLower.length >= 3 &&
                    rawLast.toLowerCase().endsWith(compLower))))
        ? ''
        : rawLast;
    final personFullName = [uFirst, uMiddle, uLast]
        .where(
          (s) =>
              s.isNotEmpty &&
              s.toLowerCase() != 'null' &&
              s.toLowerCase() != compLower,
        )
        .join(' ')
        .trim();

    final customerNameVal = personFullName.isNotEmpty
        ? personFullName
        : (user?['customerName']?.toString() ??
              (uFirst.isNotEmpty ? uFirst : 'Customer'));

    final rawRole = user?['role']?.toString() ?? '';
    final UserRole parsedRole;
    try {
      parsedRole = UserRole.fromString(rawRole);
    } catch (e) {
      if (mounted) {
        _showAccessRestrictedUI(
          title: kCrmAccessRestrictedTitle,
          message: kCrmAccessRestrictedMessage,
        );
      }
      return;
    }

    if (parsedRole != UserRole.customer) {
      await SecureStorageService.clearAll();
      await ref.read(apiClientProvider).clearAuth(notifySessionExpired: false);
      PermissionManager.instance.clear();
      if (mounted) {
        _showAccessRestrictedUI(
          title: 'Customer login only',
          message: kCustomerAppAccessMessage,
        );
      }
      return;
    }

    final isEmp = parsedRole == UserRole.employee;
    final empMap = (user != null && user['employee'] is Map)
        ? user['employee'] as Map
        : null;
    final employeeIdVal = isEmp
        ? (user?['employeeId']?.toString() ?? empMap?['id']?.toString())
        : null;
    final employeeCodeVal = isEmp
        ? (user?['employeeCode']?.toString() ??
              empMap?['employeeCode']?.toString())
        : null;
    final designationIdVal = isEmp
        ? (user?['designationId']?.toString() ??
              empMap?['designationId']?.toString())
        : null;
    final desigObj = empMap?['designation'];
    final designationNameVal = isEmp
        ? (user?['designation']?.toString() ??
              (desigObj is Map
                  ? desigObj['name']?.toString()
                  : desigObj?.toString()))
        : null;

    debugPrint('[AUTH] Resolved user: id=${user?['id']}, role=$rawRole, empId=$employeeIdVal, desig=$designationNameVal (id: $designationIdVal)');

    // Clear previous session completely before storing new user context
    await SecureStorageService.clearAll();

    await SecureStorageService.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    await SecureStorageService.saveUserData(
      userId: user?['id'] is int
          ? user!['id']
          : int.tryParse(user?['id']?.toString() ?? '0') ?? 0,
      role: parsedRole.toDisplayString(),
      email: identifier,
      customerId: customerIdVal,
      customerName: customerNameVal,
      businessName: bName.isNotEmpty ? bName : null,
      name: personFullName.isNotEmpty ? personFullName : customerNameVal,
      firstName: uFirst,
      lastName: uLast,
      employeeId: employeeIdVal,
      employeeCode: employeeCodeVal,
    );

    // Parse and store initial permissions returned directly in login payload
    final rawPerms =
        user?['effectivePermissions'] ??
        user?['permissions'] ??
        user?['permissionKeys'] ??
        payload['effectivePermissions'] ??
        payload['permissions'];
    final initialPerms = UserPermission.parseAny(rawPerms);

    await SecureStorageService.savePermissions(
      initialPerms,
      tenantId: customerIdVal,
      employeeId: employeeIdVal,
      userId: user?['id']?.toString(),
    );

    final employeeMap = user?['employee'] is Map
        ? Map<String, dynamic>.from(user?['employee'] as Map)
        : null;
    final crmCategory = parseCrmCategory(
      (user?['crmCategory'] ?? employeeMap?['crmCategory'])?.toString(),
    );
    final bool legacyCrmEligible =
        user?['isCrmEligible'] == true ||
        user?['crmMobileAccess'] == true ||
        (employeeMap != null &&
            ((employeeMap['isCrmEligible'] == true) ||
                (employeeMap['crmMobileAccess'] == true) ||
                (employeeMap['designation'] is Map &&
                    employeeMap['designation']['crmMobileAccess'] == true)));
    final bool isCrmEligible = crmCategory == null
        ? legacyCrmEligible
        : crmCategory == CrmEmployeeCategory.bpo ||
              crmCategory == CrmEmployeeCategory.sales;
    final String? crmCategoryValue = switch (crmCategory) {
      CrmEmployeeCategory.bpo => 'BPO',
      CrmEmployeeCategory.visitor => 'VISITOR',
      CrmEmployeeCategory.sales => 'SALES',
      CrmEmployeeCategory.none => 'NONE',
      null => null,
    };
    await SecureStorageService.saveCrmCategory(crmCategoryValue);

    if (initialPerms.isNotEmpty) {
      PermissionManager.instance.setPermissions(
        initialPerms,
        role: rawRole,
        employeeId: employeeIdVal,
        tenantId: customerIdVal,
        isCrmEligible: isCrmEligible,
        crmCategory: crmCategoryValue,
      );
      ref
          .read(permissionManagerProvider.notifier)
          .setPermissions(
            initialPerms,
            role: rawRole,
            employeeId: employeeIdVal,
            tenantId: customerIdVal,
            isCrmEligible: isCrmEligible,
        crmCategory: crmCategoryValue,
          );
    } else if (isEmp) {
      ref.read(permissionManagerProvider.notifier).setLoading(true);
    }

    final apiClient = ref.read(apiClientProvider);
    apiClient.setAuth(
      accessToken,
      customerIdVal,
      refreshToken: refreshToken,
    );

    // Proactively fetch canonical effective permissions
    if (isEmp) {
      try {
        final freshPerms = await ref
            .read(authServiceProvider)
            .fetchMyPermissions();
        final freshIsCrm =
            PermissionManager.instance.currentState.isCrmEligible;
        if (freshPerms.isNotEmpty) {
          PermissionManager.instance.setPermissions(
            freshPerms,
            role: rawRole,
            employeeId: employeeIdVal,
            tenantId: customerIdVal,
            isCrmEligible: freshIsCrm,
          );
          ref
              .read(permissionManagerProvider.notifier)
              .setPermissions(
                freshPerms,
                role: rawRole,
                employeeId: employeeIdVal,
                tenantId: customerIdVal,
                isCrmEligible: freshIsCrm,
              );
        }
      } catch (e) {
        debugPrint('[AUTH] Employee permission pre-fetch error: $e');
        if (ref.read(permissionManagerProvider).isLoading) {
          final defaults = AuthService.defaultEmployeeCapabilities(
            isCrm: isCrmEligible,
          );
          PermissionManager.instance.setPermissions(
            defaults,
            role: rawRole,
            employeeId: employeeIdVal,
            tenantId: customerIdVal,
            isCrmEligible: isCrmEligible,
        crmCategory: crmCategoryValue,
          );
          ref
              .read(permissionManagerProvider.notifier)
              .setPermissions(
                defaults,
                role: rawRole,
                employeeId: employeeIdVal,
                tenantId: customerIdVal,
                isCrmEligible: isCrmEligible,
        crmCategory: crmCategoryValue,
              );
        }
      }
    } else {
      try {
        await ref
            .read(loginStateProvider.notifier)
            .refreshCustomerPermissions();
      } catch (e) {
        debugPrint('[AUTH] Customer permission pre-fetch error: $e');
      }
    }

    // Register FCM device token
    NotificationService.instance.registerTokenForAuthenticatedUser();
    NotificationService.instance.requestAndroidNotificationPermission();

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Sync Riverpod loginStateProvider
    await ref.read(loginStateProvider.notifier).checkLoginStatus();

    // Invalidate customer & employee providers
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    ref.invalidate(employeeProfileProvider);
    ref.invalidate(employeeAttendanceProvider);
    ref.invalidate(workPermissionsProvider);

    if (!mounted) return;

    switch (parsedRole) {
      case UserRole.customer:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const CustomerDashboardView()),
          (route) => false,
        );
        break;

      case UserRole.employee:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DashboardView()),
          (route) => false,
        );
        break;

      case UserRole.companyAdmin:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const CompanyAdminMainView()),
          (route) => false,
        );
        break;
    }
  }

  void _handleDioError(DioException e, {required String defaultMsg}) {
    final statusCode = e.response?.statusCode;
    String msg = '';
    String? title;

    dynamic responseData = e.response?.data;
    if (responseData is String && responseData.isNotEmpty) {
      try {
        responseData = jsonDecode(responseData);
      } catch (_) {}
    }

    if (responseData is Map) {
      if (responseData['message'] != null &&
          responseData['message'].toString().trim().isNotEmpty) {
        msg = responseData['message'].toString().trim();
      } else if (responseData['errors'] is List &&
          (responseData['errors'] as List).isNotEmpty) {
        msg = responseData['errors'][0].toString();
      }

      final errField = responseData['error']?.toString().trim();
      if (errField != null &&
          errField.isNotEmpty &&
          errField.toLowerCase() != 'forbidden') {
        title = errField;
      }

      final code = responseData['code']?.toString();
      if (code == 'WORKSPACE_SUSPENDED') {
        title = 'Workspace Suspended';
      } else if (code == 'SUBSCRIPTION_EXPIRED') {
        title = 'Subscription Expired';
      }
    }

    // 1. 403 Forbidden: UNAUTHORIZED ACCOUNT / DEPARTMENT
    // Clearly distinguished from invalid credentials / incorrect passwords.
    if (statusCode == 403) {
      unawaited(SecureStorageService.clearAll());
      unawaited(ref.read(apiClientProvider).clearAuth(notifySessionExpired: false));
      PermissionManager.instance.clear();

      final authMsg = msg.isNotEmpty ? msg : kCrmAccessRestrictedMessage;
      final authTitle = title ?? kCrmAccessRestrictedTitle;
      _showAccessRestrictedUI(title: authTitle, message: authMsg);
      return;
    }

    // 2. 401 Unauthorized: INCORRECT PASSWORD / INVALID CREDENTIALS
    // DO NOT show Access Restricted error for incorrect passwords!
    if (statusCode == 401) {
      final invalidCredMsg = msg.isNotEmpty
          ? msg
          : (_usesPassword
              ? 'Invalid email/ID or password. Please try again.'
              : 'Invalid credentials or OTP. Please try again.');
      AppToast.error(context, invalidCredMsg, title: 'Login Failed');
      return;
    }

    if (msg.isEmpty) {
      if (statusCode == 400) {
        msg = 'Invalid request. Please check the details entered.';
      } else if (statusCode == 404) {
        msg = 'Account not found. Please verify your details.';
      } else if (statusCode == 429) {
        msg = 'Too many requests. Please wait a moment and try again.';
      } else if (statusCode == 500) {
        msg = 'Server error. Please try again later.';
      } else if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        msg = 'Please check your internet connection and try again.';
      } else {
        msg = defaultMsg;
      }
    }

    AppToast.error(context, msg, title: title);
  }

  String _getPortalSubtitle() {
    switch (_currentRole) {
      case MobileUserRole.customer:
        return 'CUSTOMER WORKFORCE PORTAL';
      case MobileUserRole.admin:
        return 'ADMIN CONTROL PORTAL';
      case MobileUserRole.employee:
        return 'EMPLOYEE WORKFORCE PORTAL';
    }
  }

  void _changeIdentifier() {
    if (_isLoading) return;
    setState(() {
      _stage = LoginStage.input;
      _enteredOtp = '';
      _isLoading = false;
    });
    _countdownTimer?.cancel();
  }

  double _loginCardMaxWidth(double width) {
    if (width < 768) return 480;
    if (width < 1024) return 520;
    if (width < 1440) return 560;
    return 600;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final compact = width < 360;
    final horizontal = compact ? 12.0 : (width < 768 ? 20.0 : 32.0);
    final maxWidth = _loginCardMaxWidth(width);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontal,
                compact ? 8 : 20,
                horizontal,
                16 + media.viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - (compact ? 24 : 36)),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _buildStageContent(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStageContent() {
    switch (_stage) {
      case LoginStage.input:
        return _buildInputStage();
      case LoginStage.otp:
        return _buildOtpStage();
      case LoginStage.verifying:
        return _buildVerifyingStage();
    }
  }

  // ==========================================
  // 1. INPUT STAGE (LOGIN SCREEN)
  // ==========================================
  Widget _buildInputStage() {
    return Column(
      key: const ValueKey('stage_input'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),

        // Logo, Portal Subtitle & Titles
        AuthHeader(portalSubtitle: _getPortalSubtitle()),
        const SizedBox(height: 22),

        // Main Login Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE8EEF4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_accessRestrictedMessage != null) ...[
                AccessRestrictedCard(
                  title: _accessRestrictedTitle ?? kCrmAccessRestrictedTitle,
                  message: _accessRestrictedMessage!,
                  onTryAnotherAccount: _clearFormForAnotherAccount,
                  onDismiss: () {
                    setState(() {
                      _accessRestrictedTitle = null;
                      _accessRestrictedMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 18),
              ],

              // "Login with" Label & Method Pills
              Text(
                'Login with',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
              const SizedBox(height: 10),

              _buildLoginMethodSelector(),
              const SizedBox(height: 18),

              // Dynamic Input Field
              _buildDynamicInputField(),
              if (_identifierError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _identifierError!,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // If Password Mode (Email / EMP-ID only): Password field & forgot password
              if (_usesPassword) ...[
                LoginInputField(
                  controller: _passwordController,
                  hint: 'Enter your password',
                  prefixIcon: Remix.lock_2_line,
                  isPassword: true,
                  isPasswordVisible: _isPasswordVisible,
                  onChanged: _onFieldChanged,
                  onTogglePassword: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Remember Me & Forgot Password Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _rememberMe = !_rememberMe;
                        });
                      },
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: const Color(0xFF23C45E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              side: const BorderSide(
                                color: Color(0xFFCBD5E1),
                                width: 1.5,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _rememberMe = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Remember Me',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: const Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordView(),
                          ),
                        );
                      },
                      child: Text(
                        'Forgot Password?',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF23C45E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],

              // Mobile OTP Input Field (shown after OTP is successfully requested)
              if (_isMobileLogin && _mobileOtpSent) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Enter 6-digit OTP',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    GestureDetector(
                      onTap: _resetMobileOtp,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.edit_line,
                            size: 13,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Change Number',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OtpInputField(
                  key: ValueKey(_otpInputVersion),
                  length: 6,
                  hasError: _otpError != null,
                  onChanged: (code) {
                    setState(() {
                      _enteredOtp = code;
                      _otpError = null;
                    });
                  },
                  onCompleted: (code) {
                    setState(() {
                      _enteredOtp = code;
                      _otpError = null;
                    });
                    _handleVerifyOtp(code);
                  },
                ),
                if (_otpError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _otpError!,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
              ],

              // Primary CTA Button
              SizedBox(
                width: double.infinity,
                height: MediaQuery.sizeOf(context).width < 360 ? 46 : 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF34D36A), Color(0xFF16A34A)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_usesPassword
                            ? _handlePasswordLogin
                            : (_isMobileLogin
                                ? (_mobileOtpSent
                                    ? (_enteredOtp.length == 6 ? () => _handleVerifyOtp(_enteredOtp) : null)
                                    : _handleSendOtp)
                                : _handleSendOtp)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _usesPassword
                                    ? 'Sign In'
                                    : (_isMobileLogin
                                        ? (_mobileOtpSent ? 'Verify OTP & Sign In' : 'Send OTP')
                                        : 'Send OTP'),
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Remix.arrow_right_line,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              // Resend OTP Countdown (for Mobile Login after OTP sent)
              if (_isMobileLogin && _mobileOtpSent) ...[
                const SizedBox(height: 14),
                if (_resendCountdown > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Remix.time_line,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Resend OTP in 00:${_resendCountdown.toString().padLeft(2, '0')}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  GestureDetector(
                    onTap: _isLoading ? null : () => _handleSendOtp(isResend: true),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Remix.refresh_line,
                          size: 14,
                          color: Color(0xFF23C45E),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Resend OTP',
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF23C45E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 18),

              // OR Divider
                Row(
                  children: [
                    const Expanded(
                      child: Divider(
                        color: Color(0xFFE2E8F0),
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF98A2B3),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(
                        color: Color(0xFFE2E8F0),
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (!_isPasswordMode)
                  _buildSecondaryAction(
                    icon: Remix.lock_2_line,
                    label: 'Login with Password',
                    onTap: () {
                      setState(() {
                        _isPasswordMode = true;
                        _mobileOtpSent = false;
                        _enteredOtp = '';
                      });
                      _countdownTimer?.cancel();
                    },
                  )
                else
                  _buildSecondaryAction(
                    icon: Remix.message_2_line,
                    label: 'Login with OTP',
                    onTap: () {
                      setState(() {
                        _isPasswordMode = false;
                        _mobileOtpSent = false;
                        _enteredOtp = '';
                      });
                      _countdownTimer?.cancel();
                    },
                  ),
              const SizedBox(height: 16),

              // Security Card at bottom of login form
              const SecureLoginCard(),
              if (_currentRole != MobileUserRole.admin) ...[
                const SizedBox(height: 16),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      GestureDetector(
                        onTap: _openRegistration,
                        child: Text(
                          'Register',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _openRegistration() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CustomerRegistrationView(),
      ),
    );
  }

  Widget _buildSecondaryAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: _isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE8EEF4), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: const Color(0xFFF8FAFC),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Login Method Selector Pills
  Widget _buildLoginMethodSelector() {
    final stackMethods = MediaQuery.sizeOf(context).width < 360;
    final pills = <Widget>[
      _buildMethodPill(
        method: LoginMethod.email,
        label: 'Email',
        icon: Remix.mail_line,
      ),
      _buildMethodPill(
        method: LoginMethod.mobile,
        label: 'Mobile',
        icon: Remix.phone_line,
      ),
    ];

    if (stackMethods) {
      return Column(
        children: [
          for (var i = 0; i < pills.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            pills[i],
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < pills.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: pills[i]),
        ],
      ],
    );
  }

  Widget _buildMethodPill({
    required LoginMethod method,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _loginMethod == method;

    return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : () {
            setState(() {
              if (_loginMethod != method) {
                _loginMethod = method;
                _identifierError = null;
                _otpError = null;
                _mobileOtpSent = false;
                _enteredOtp = '';
                if (method == LoginMethod.mobile) {
                  _isPasswordMode = true;
                  if (_identifierController.text.contains('@')) {
                    _identifierController.clear();
                  }
                }
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF22C55E) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  // Dynamic Input Field based on selected method
  Widget _buildDynamicInputField() {
    switch (_loginMethod) {
      case LoginMethod.email:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LoginInputField(
              controller: _identifierController,
              hint: _acceptsEmployeeCode()
                  ? 'Enter email or Employee ID'
                  : 'Enter your email address',
              prefixIcon: Remix.mail_line,
              keyboardType: _acceptsEmployeeCode()
                  ? TextInputType.text
                  : TextInputType.emailAddress,
              onChanged: _onFieldChanged,
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'e.g. customer@example.com',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        );

      case LoginMethod.mobile:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Country Code Selector
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Remix.smartphone_line,
                          size: 16,
                          color: Color(0xFF23C45E),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+91',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Mobile Input Field
                Expanded(
                  child: LoginInputField(
                    controller: _identifierController,
                    hint: 'Enter mobile number',
                    prefixIcon: Remix.phone_line,
                    keyboardType: TextInputType.phone,
                    readOnly: _mobileOtpSent,
                    onChanged: (val) {
                      _onFieldChanged(val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                _mobileOtpSent
                    ? 'OTP sent to +91 ${_identifierController.text.trim()}'
                    : 'e.g. 9876543210',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  color: _mobileOtpSent ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                  fontWeight: _mobileOtpSent ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ],
        );

      case LoginMethod.employeeId:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LoginInputField(
              controller: _identifierController,
              hint: 'Enter your Employee ID',
              prefixIcon: Remix.id_card_line,
              keyboardType: TextInputType.text,
              onChanged: _onFieldChanged,
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'e.g. EMP-004',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        );
    }
  }

  // ==========================================
  // 2. OTP VERIFICATION STAGE
  // ==========================================
  Widget _buildOtpStage() {
    final changeText = _loginMethod == LoginMethod.mobile
        ? 'Change Mobile Number'
        : (_acceptsEmployeeCode() ? 'Change Email or Employee ID' : 'Change Email');

    return Column(
      key: const ValueKey('stage_otp'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back Button & Header Row
        Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _changeIdentifier,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Remix.arrow_left_line,
                      size: 16,
                      color: Color(0xFF475569),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Back',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Lock / Shield Icon Badge
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFDCFCE7), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF23C45E).withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Remix.shield_check_line,
              color: Color(0xFF23C45E),
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Headings
        Text(
          'Verify OTP',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "We've sent a 6-digit OTP to",
          style: GoogleFonts.outfit(
            fontSize: 13.5,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _maskedDestination,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // OTP Input Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 6 Separate OTP Boxes
              OtpInputField(
                key: ValueKey(_otpInputVersion),
                length: 6,
                onChanged: (code) {
                  setState(() => _enteredOtp = code);
                },
                onCompleted: (code) {
                  setState(() => _enteredOtp = code);
                  _handleVerifyOtp(code);
                },
              ),
              const SizedBox(height: 24),

              // Verify & Continue CTA Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (_enteredOtp.length == 6 && !_isLoading)
                      ? () => _handleVerifyOtp(_enteredOtp)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF23C45E),
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Verify OTP & Sign In',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Remix.arrow_right_line,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Resend OTP Countdown
              if (_isLoading) ...[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF23C45E),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Sending OTP...', style: GoogleFonts.outfit(fontSize: 13)),
                const SizedBox(height: 8),
              ],
              if (_resendCountdown > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Remix.time_line,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Resend OTP in 00:${_resendCountdown.toString().padLeft(2, '0')}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                GestureDetector(
                  onTap: _isLoading ? null : () => _handleSendOtp(isResend: true),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Remix.refresh_line,
                        size: 14,
                        color: Color(0xFF23C45E),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Resend OTP',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF23C45E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Change Login Identifier CTA
              GestureDetector(
                onTap: _changeIdentifier,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Remix.edit_line,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '✎ $changeText',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Secure Verification Card
              const SecureVerificationCard(),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ==========================================
  // 3. OTP VERIFYING / LOADING STAGE
  // ==========================================
  Widget _buildVerifyingStage() {
    return Column(
      key: const ValueKey('stage_verifying'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Circular Progress Indicator
              const SizedBox(
                width: 52,
                height: 52,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF23C45E)),
                ),
              ),
              const SizedBox(height: 20),

              // Heading & Subtitle
              Text(
                'Verifying OTP',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please wait while we verify your code',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 28),

              // Step Indicators
              _buildVerifyingStepItem(
                stepIndex: 0,
                label: 'Validating OTP',
              ),
              const SizedBox(height: 12),
              _buildVerifyingStepItem(
                stepIndex: 1,
                label: 'Authenticating account',
              ),
              const SizedBox(height: 12),
              _buildVerifyingStepItem(
                stepIndex: 2,
                label: 'Loading your data...',
              ),
              const SizedBox(height: 24),

              const SecureVerificationCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyingStepItem({
    required int stepIndex,
    required String label,
  }) {
    final isDone = _verifyingStep > stepIndex;
    final isCurrent = _verifyingStep == stepIndex;

    Color iconColor;
    IconData icon;

    if (isDone) {
      iconColor = const Color(0xFF23C45E);
      icon = Remix.checkbox_circle_fill;
    } else if (isCurrent) {
      iconColor = const Color(0xFF23C45E);
      icon = Remix.loader_4_line;
    } else {
      iconColor = const Color(0xFFCBD5E1);
      icon = Remix.checkbox_blank_circle_line;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDone || isCurrent ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDone || isCurrent ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isDone || isCurrent ? FontWeight.w600 : FontWeight.w400,
                color: isDone || isCurrent ? const Color(0xFF166534) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
