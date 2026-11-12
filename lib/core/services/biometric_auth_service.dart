import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

enum BiometricAuthStatus { success, failed, cancelled, unavailable, error }

class BiometricAuthResult {
  final BiometricAuthStatus status;
  final String message;

  const BiometricAuthResult({required this.status, required this.message});

  bool get isSuccess => status == BiometricAuthStatus.success;

  factory BiometricAuthResult.success() => const BiometricAuthResult(
    status: BiometricAuthStatus.success,
    message: 'Biometric verification successful.',
  );

  factory BiometricAuthResult.unavailable([String? msg]) => BiometricAuthResult(
    status: BiometricAuthStatus.unavailable,
    message: msg ?? 'Biometric authentication is not available on this device.',
  );

  factory BiometricAuthResult.cancelled() => const BiometricAuthResult(
    status: BiometricAuthStatus.cancelled,
    message: 'Authentication cancelled.',
  );

  factory BiometricAuthResult.failed([String? msg]) => BiometricAuthResult(
    status: BiometricAuthStatus.failed,
    message: msg ?? 'Biometric verification failed.',
  );

  factory BiometricAuthResult.error(String msg) =>
      BiometricAuthResult(status: BiometricAuthStatus.error, message: msg);
}

class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if biometric hardware and enrollment are available on the device
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canAuthenticateWithBiometrics || isDeviceSupported;
    } catch (e) {
      debugPrint('[BIOMETRIC] isBiometricAvailable error: $e');
      return false;
    }
  }

  /// Authenticate the employee using Device Biometrics (Fingerprint / Face / Device PIN fallback)
  static Future<BiometricAuthResult> authenticate({
    String localizedReason =
        'Please authenticate with your fingerprint or face to record attendance',
  }) async {
    try {
      final bool canAuth = await isBiometricAvailable();
      if (!canAuth) {
        debugPrint('[BIOMETRIC] Hardware not available or not enrolled.');
        return BiometricAuthResult.unavailable();
      }

      final List<BiometricType> availableBiometrics = await _auth
          .getAvailableBiometrics();
      debugPrint('[BIOMETRIC] Available biometrics: $availableBiometrics');

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly:
              false, // Allows device PIN/pattern as system-level backup if needed
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      if (didAuthenticate) {
        debugPrint('[BIOMETRIC] Authentication SUCCESS');
        return BiometricAuthResult.success();
      } else {
        debugPrint('[BIOMETRIC] Authentication FAILED or dismissed');
        return BiometricAuthResult.failed();
      }
    } on PlatformException catch (e) {
      debugPrint(
        '[BIOMETRIC] PlatformException code: ${e.code}, message: ${e.message}',
      );
      final code = e.code.toLowerCase();
      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.notEnrolled ||
          code.contains('notavailable') ||
          code.contains('notenrolled')) {
        return BiometricAuthResult.unavailable(
          'Biometric authentication is not enrolled or available on this device.',
        );
      } else if (e.code == auth_error.passcodeNotSet ||
          code.contains('passcodenotset')) {
        return BiometricAuthResult.unavailable(
          'Please set up a device lock / biometric in your device settings.',
        );
      } else if (e.code == auth_error.lockedOut ||
          e.code == auth_error.permanentlyLockedOut ||
          code.contains('lockedout')) {
        return BiometricAuthResult.failed(
          'Biometrics locked due to too many attempts. Please unlock device.',
        );
      } else if (code.contains('cancel') ||
          code.contains('usercanceled') ||
          code.contains('usercancel')) {
        return BiometricAuthResult.cancelled();
      } else if (code.contains('inprogress') ||
          code.contains('auth_in_progress')) {
        return BiometricAuthResult.error(
          'Biometric authentication is already in progress.',
        );
      }
      return BiometricAuthResult.failed('Biometric verification failed.');
    } catch (e) {
      debugPrint('[BIOMETRIC] Unexpected error during authentication: $e');
      return BiometricAuthResult.error(
        'Biometric verification encountered an error: $e',
      );
    }
  }
}
