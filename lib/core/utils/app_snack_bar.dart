import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/services/notification_service.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

enum SnackBarType { success, error, warning, info }

/// Global, centralized SnackBar utility ensuring high visibility, responsive design,
/// consistent typography, and clean navigation transitions across the application.
class AppSnackBar {
  AppSnackBar._();

  static ScaffoldMessengerState? _resolveMessenger([BuildContext? context]) {
    // 1. Prefer global messengerKey from MaterialApp so messages survive screen navigation and popups
    final globalMessenger =
        NotificationService.instance.messengerKey.currentState;
    if (globalMessenger != null) return globalMessenger;

    // 2. Fallback to context's ScaffoldMessenger if available and mounted
    if (context != null && context.mounted) {
      try {
        return ScaffoldMessenger.maybeOf(context);
      } catch (_) {}
    }
    return null;
  }

  /// Show a global floating snackbar with responsive dimensions, white readable text,
  /// matching icon, and automatic duplicate prevention.
  static void show(
    BuildContext? context, {
    required String message,
    SnackBarType type = SnackBarType.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = _resolveMessenger(context);
    if (messenger == null) return;

    // Prevent duplicate or queued snackbars from piling up
    messenger.hideCurrentSnackBar();

    final Color bgColor;
    final IconData iconData;
    final Color iconColor;

    switch (type) {
      case SnackBarType.success:
        bgColor = AppColors.primary; // Green (#10B981)
        iconData = Remix.checkbox_circle_fill;
        iconColor = Colors.white;
        break;
      case SnackBarType.error:
        bgColor = AppColors.error; // Red (#EF4444)
        iconData = Remix.error_warning_fill;
        iconColor = Colors.white;
        break;
      case SnackBarType.warning:
        bgColor = const Color(0xFFF59E0B); // Amber
        iconData = Remix.alert_fill;
        iconColor = Colors.white;
        break;
      case SnackBarType.info:
        bgColor = const Color(0xFF1E293B); // Slate
        iconData = Remix.information_fill;
        iconColor = AppColors.primary;
        break;
    }

    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: bgColor,
      elevation: 6,
      duration: duration,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      content: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            iconData,
            color: iconColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    messenger.showSnackBar(snackBar);
  }

  /// Display a success message with green background, white check icon, and readable white text.
  static void showSuccess(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) =>
      show(
        context,
        message: message,
        type: SnackBarType.success,
        duration: duration,
      );

  /// Display an error message with error background, white warning icon, and readable white text.
  static void showError(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) =>
      show(
        context,
        message: message,
        type: SnackBarType.error,
        duration: duration,
      );

  /// Display a warning message with amber background, white icon, and readable white text.
  static void showWarning(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) =>
      show(
        context,
        message: message,
        type: SnackBarType.warning,
        duration: duration,
      );

  /// Display an info message with dark slate background, accent icon, and readable white text.
  static void showInfo(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) =>
      show(
        context,
        message: message,
        type: SnackBarType.info,
        duration: duration,
      );
}

