import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized service to manage the app's first-launch onboarding state.
///
/// KEY RULES:
/// - This is a DEVICE-level setting, not a USER-level setting.
/// - It must NOT be cleared during logout.
/// - It must survive app restarts, account switches, and re-logins.
/// - Only cleared on full app uninstall (Android) or app delete (iOS).
class OnboardingService {
  static const String onboardingCompletedKey = 'onboarding_completed';

  /// Checks whether the one-time onboarding has been completed or skipped.
  /// Uses a fresh SharedPreferences instance each time (safe & correct).
  Future<bool> isCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = prefs.getBool(onboardingCompletedKey) ?? false;
      debugPrint('[OnboardingService] isCompleted → $result');
      return result;
    } catch (e) {
      debugPrint('[OnboardingService] isCompleted error: $e');
      // On error, assume NOT completed so user always has a chance to onboard.
      return false;
    }
  }

  /// Synchronous check — only valid if SharedPreferences was pre-initialized
  /// (e.g. via main.dart pre-init). Pass in the cached prefs instance.
  static bool isCompletedSync(SharedPreferences prefs) {
    return prefs.getBool(onboardingCompletedKey) ?? false;
  }

  /// Marks the onboarding flow as completed.
  /// Uses await to guarantee the write completes before navigation.
  Future<void> complete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(onboardingCompletedKey, true);
      debugPrint('[OnboardingService] Onboarding marked COMPLETE');
    } catch (e) {
      debugPrint('[OnboardingService] complete() error: $e');
      // Retry once
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(onboardingCompletedKey, true);
      } catch (_) {}
    }
  }

  /// Resets onboarding state for testing only.
  /// Never expose this to production employee flows.
  Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(onboardingCompletedKey);
      debugPrint('[OnboardingService] Onboarding RESET');
    } catch (e) {
      debugPrint('[OnboardingService] reset() error: $e');
    }
  }
}
