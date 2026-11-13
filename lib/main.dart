import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickboom_crm_customer/core/models/user_role.dart';
import 'package:quickboom_crm_customer/core/theme/app_theme.dart';
import 'package:quickboom_crm_customer/shared/services/onboarding_service.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/shared/views/splash_view.dart';
import 'package:quickboom_crm_customer/shared/views/auth/login_view.dart';
import 'package:quickboom_crm_customer/shared/views/onboarding_view.dart';

import 'package:quickboom_crm_customer/roles/employee/views/dashboard_view.dart';
import 'package:quickboom_company_admin/roles/company_admin/views/company_admin_main_view.dart';
import 'package:quickboom_crm_customer/roles/customer/views/customer_dashboard_view.dart';
import 'package:quickboom_crm_customer/roles/employee/routes/employee_routes.dart';
import 'package:quickboom_crm_customer/core/services/notification_service.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/firebase_options.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) =>
    NotificationService.backgroundHandler(message);

SharedPreferences? _prefs;

Future<void> _startFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 3));
    }
    debugPrint('🔥 [FCM] Firebase Initialized');
  } catch (e, st) {
    debugPrint('🚨🔥 [FCM] Firebase Initialization FAILED: $e');
    debugPrintStack(stackTrace: st);
    return;
  }

  if (Firebase.apps.isEmpty || NotificationService.isBackgroundHandlerRegistered) {
    return;
  }
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    NotificationService.isBackgroundHandlerRegistered = true;
    debugPrint('[FCM] Background handler registered');
  } catch (e) {
    debugPrint('[FCM] Background handler registration warning: $e');
  }
}

void main() async {
  final buildMode = kReleaseMode
      ? 'RELEASE'
      : kProfileMode
      ? 'PROFILE'
      : 'DEBUG';
  final environment = kReleaseMode ? 'production' : 'development';
  const appVersion = '1.0.2+6';

  debugPrint('==================================================');
  debugPrint('[DEVICE DEBUG]');
  debugPrint('Build Mode: $buildMode');
  debugPrint('API Base URL: ${AppUrl.baseUrl}');
  debugPrint('Environment: $environment');
  debugPrint('App Version: $appVersion');
  debugPrint('==================================================');

  debugPrint('[STARTUP] app initialization started');
  debugPrint('[STARTUP] main started');
  WidgetsFlutterBinding.ensureInitialized();

  // Configure ImagePicker to explicitly use Android Photo Picker (Google Play Policy Compliance)
  final ImagePickerPlatform imagePickerImplementation =
      ImagePickerPlatform.instance;
  if (imagePickerImplementation is ImagePickerAndroid) {
    imagePickerImplementation.useAndroidPhotoPicker = true;
  }

  unawaited(_startFirebase());

  // Launch notification service non-blockingly so main() never hangs
  try {
    unawaited(
      NotificationService.instance.initialize().catchError((e) {
        debugPrint('[STARTUP_ERROR] NotificationService.initialize error: $e');
      }),
    );
  } catch (e) {
    debugPrint('[STARTUP_ERROR] NotificationService launch error: $e');
  }
  debugPrint('[STARTUP] Flutter binding initialized');

  debugPrint('[STARTUP] Storage initialization started');
  try {
    _prefs = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        debugPrint('[STARTUP_WARN] SharedPreferences timeout after 2s');
        return null as dynamic;
      },
    );
    debugPrint('[STARTUP] local storage initialized');
    if (_prefs != null) {
      
    }
    debugPrint('[STARTUP] Storage initialization completed');
  } catch (e, st) {
    debugPrint('[STARTUP_ERROR] Storage error: $e');
    debugPrint('[STARTUP_ERROR] $st');
  }

  // Location service startup check (non-blocking, never blocks UI)
  debugPrint('[STARTUP] location initialization started');
  try {
    debugPrint('[STARTUP] location initialization completed');
  } catch (e) {
    debugPrint('[STARTUP_ERROR] Location initialization error: $e');
    debugPrint('[STARTUP] location initialization completed');
  }

  try {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  } catch (e) {
    debugPrint('[STARTUP_ERROR] SystemUI error: $e');
  }

  debugPrint('[STARTUP] initialization completed');
  runApp(const ProviderScope(child: MyApp()));
  debugPrint('[STARTUP] runApp completed');
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppToast.navigatorKey = NotificationService.instance.navigatorKey;

    // Listen for authentication transitions to register/unregister FCM token safely
    ref.listen<LoginState>(loginStateProvider, (previous, next) {
      if (next.isLoggedIn && !(previous?.isLoggedIn ?? false)) {
        NotificationService.instance.registerTokenForAuthenticatedUser();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationService.instance.requestAndroidNotificationPermission();
        });
      } else if (!next.isLoggedIn && (previous?.isLoggedIn ?? false)) {
        NotificationService.instance.unregisterToken();
        NotificationService.instance.navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginView()),
          (route) => false,
        );
      }
    });

    final loginState = ref.watch(loginStateProvider);
    if (loginState.isLoggedIn &&
        NotificationService.instance.cachedFcmToken != null) {
      // Idempotent: registers only if not yet registered for this session
      NotificationService.instance.registerTokenForAuthenticatedUser();
    }

    // Ensure system notification permission prompt is presented on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestAndroidNotificationPermission();
    });
    final bool onboardingDone =
        _prefs?.getBool(OnboardingService.onboardingCompletedKey) ?? true;

    final Widget targetHome;
    if (loginState.isInitializing) {
      targetHome = const SplashView();
    } else if (loginState.hasStartupError && !loginState.isLoggedIn) {
      targetHome = SplashView(error: loginState.startupError);
    } else if (loginState.isLoggedIn && loginState.role != null) {
      final userRole = loginState.role!;

      debugPrint('SESSION RESTORE');
      debugPrint('Stored Role: ${loginState.userRole}');
      debugPrint('[NAVIGATION]');
      debugPrint('Resolved role: ${userRole.name}');

      switch (userRole) {
        case UserRole.customer:
          targetHome = const CustomerDashboardView();
          break;
        case UserRole.employee:
          debugPrint('Destination: EmployeeHome');
          targetHome = const DashboardView();
          break;
        case UserRole.companyAdmin:
          debugPrint('Destination: CompanyAdminHome');
          targetHome = const CompanyAdminMainView();
          break;
      }
      debugPrint('[STARTUP] Router initialization completed');
      debugPrint('[STARTUP] navigating to Login/Home');
      debugPrint('[STARTUP] Navigating to Home');
    } else {
      targetHome = !onboardingDone ? const OnboardingView() : const LoginView();
      debugPrint('[STARTUP] Router initialization completed');
      debugPrint('[STARTUP] navigating to Login');
      debugPrint('[STARTUP] Navigating to Login');
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MaterialApp(
        navigatorKey: NotificationService.instance.navigatorKey,
        scaffoldMessengerKey: NotificationService.instance.messengerKey,
        title: 'QB Suite Customer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: targetHome,
        routes: {
          ...EmployeeRoutes.getRoutes(),
          
          
          
          
          '/role-selection': (_) => const LoginView(),
          '/login': (_) => const LoginView(),
        },
      ),
    );
  }
}
