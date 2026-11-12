import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/utils/app_snack_bar.dart';

export 'package:quickboom_crm_customer/core/utils/app_snack_bar.dart';

enum ToastType { success, error, warning, info }

class AppToast {
  static OverlayEntry? _current;
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Global toggle for toast messages across the mobile app.
  static bool isEnabled = true;

  /// Auth-only filter flag (toasts disabled globally)
  static bool authOnly = false;

  static void show(
    BuildContext? context, {
    required String message,
    ToastType type = ToastType.success,
    String? title,
    Duration duration = const Duration(seconds: 3),
    bool isAuthToast = false,
  }) {
    if (!isEnabled) {
      _current?.remove();
      _current = null;
      return;
    }

    final lowerTitle = (title ?? '').toLowerCase();
    final lowerMsg = message.toLowerCase();

    // Check if this is a login success toast
    final bool isLoginSuccess =
        isAuthToast ||
        ((lowerTitle.contains('login') || lowerTitle.contains('admin access')) &&
            (type == ToastType.success ||
                lowerMsg.contains('successful') ||
                lowerMsg.contains('authenticated') ||
                lowerMsg.contains('granted'))) ||
        lowerMsg.contains('welcome to your customer workspace') ||
        lowerMsg.contains('employee workspace authenticated') ||
        lowerMsg.contains('admin workspace authenticated');

    // Check if this is a logout toast
    final bool isLogout =
        isAuthToast ||
        lowerTitle.contains('logout') ||
        lowerTitle.contains('sign out') ||
        lowerMsg.contains('logged out') ||
        lowerMsg.contains('signed out');

    // When authOnly is enabled, discard everything that isn't login success or logout
    if (authOnly && !isLoginSuccess && !isLogout) {
      return;
    }

    void doInsert() {
      if (_current != null && _current!.mounted) {
        _current!.remove();
      }
      _current = null;

      final targetContext = context ?? navigatorKey?.currentContext;
      final overlay =
          navigatorKey?.currentState?.overlay ??
          (targetContext != null ? Overlay.maybeOf(targetContext) : null);

      if (overlay == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final retryContext = context ?? navigatorKey?.currentContext;
          final retryOverlay =
              navigatorKey?.currentState?.overlay ??
              (retryContext != null ? Overlay.maybeOf(retryContext) : null);
          if (retryOverlay != null) {
            _insertToast(
              retryOverlay,
              message: message,
              title: title,
              type: type,
              duration: duration,
            );
          }
        });
        return;
      }

      _insertToast(
        overlay,
        message: message,
        title: title,
        type: type,
        duration: duration,
      );
    }

    if (isLoginSuccess || isLogout) {
      // Auth screen transitions (pushAndRemoveUntil) replace the route stack.
      // Delay slightly so the destination screen's opaque route is fully mounted
      // and won't obscure the overlay toast.
      Future.delayed(const Duration(milliseconds: 350), doInsert);
    } else {
      doInsert();
    }
  }

  static void _insertToast(
    OverlayState overlay, {
    required String message,
    required ToastType type,
    String? title,
    required Duration duration,
  }) {
    if (_current != null && _current!.mounted) {
      _current!.remove();
    }
    _current = null;

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        title: title,
        type: type,
        onDismiss: () {
          if (entry.mounted) {
            entry.remove();
          }
          if (_current == entry) {
            _current = null;
          }
        },
        duration: duration,
      ),
    );

    _current = entry;
    overlay.insert(entry);
  }

  /// Explicit helper for login success
  static void loginSuccess({
    BuildContext? context,
    String? message,
    String? title,
  }) =>
      show(
        context,
        message: message ?? 'Login successful!',
        title: title ?? 'Login Successful',
        type: ToastType.success,
        isAuthToast: true,
      );

  /// Explicit helper for logout
  static void logoutSuccess({
    BuildContext? context,
    String? message,
    String? title,
  }) =>
      show(
        context,
        message: message ?? 'You have been logged out successfully.',
        title: title ?? 'Logged Out',
        type: ToastType.info,
        isAuthToast: true,
      );

  static void success(BuildContext? context, String message, {String? title, bool isAuthToast = false}) =>
      show(context, message: message, title: title, type: ToastType.success, isAuthToast: isAuthToast);

  static void error(BuildContext? context, String message, {String? title, bool isAuthToast = false}) =>
      show(context, message: message, title: title, type: ToastType.error, isAuthToast: isAuthToast);

  static void warning(BuildContext? context, String message, {String? title, bool isAuthToast = false}) =>
      show(context, message: message, title: title, type: ToastType.warning, isAuthToast: isAuthToast);

  static void info(BuildContext? context, String message, {String? title, bool isAuthToast = false}) =>
      show(context, message: message, title: title, type: ToastType.info, isAuthToast: isAuthToast);

  /// Show a global floating SnackBar with white readable text and matching icon
  static void snackBar(
    BuildContext? context, {
    required String message,
    SnackBarType type = SnackBarType.success,
    Duration duration = const Duration(seconds: 3),
  }) =>
      AppSnackBar.show(context, message: message, type: type, duration: duration);
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final String? title;
  final ToastType type;
  final VoidCallback onDismiss;
  final Duration duration;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
    required this.duration,
    this.title,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnim = Tween<double>(
      begin: -80,
      end: 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();

    Future.delayed(widget.duration, _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  _ToastStyle get _style {
    switch (widget.type) {
      case ToastType.success:
        return _ToastStyle(
          bg: const Color(0xFF0F172A),
          accent: AppColors.primary,
          icon: Remix.checkbox_circle_fill,
        );
      case ToastType.error:
        return _ToastStyle(
          bg: const Color(0xFF0F172A),
          accent: const Color(0xFFDC2626),
          icon: Remix.close_circle_fill,
        );
      case ToastType.warning:
        return _ToastStyle(
          bg: const Color(0xFF0F172A),
          accent: const Color(0xFFF59E0B),
          icon: Remix.alert_fill,
        );
      case ToastType.info:
        return _ToastStyle(
          bg: const Color(0xFF0F172A),
          accent: const Color(0xFF3B82F6),
          icon: Remix.information_fill,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnim.value),
            child: Opacity(opacity: _fadeAnim.value, child: child),
          );
        },
        child: GestureDetector(
          onTap: _dismiss,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: style.bg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Accent left bar
                  Container(
                    width: 3,
                    height: widget.title != null ? 40 : 28,
                    decoration: BoxDecoration(
                      color: style.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Icon
                  Icon(style.icon, color: style.accent, size: 22),
                  const SizedBox(width: 12),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.title != null) ...[
                          Text(
                            widget.title!,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          widget.message,
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Dismiss icon
                  GestureDetector(
                    onTap: _dismiss,
                    child: Icon(
                      Remix.close_line,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastStyle {
  final Color bg;
  final Color accent;
  final IconData icon;
  _ToastStyle({required this.bg, required this.accent, required this.icon});
}
