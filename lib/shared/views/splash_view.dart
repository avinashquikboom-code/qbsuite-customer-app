import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/core/theme/app_theme.dart';

class SplashView extends ConsumerStatefulWidget {
  final String? error;
  const SplashView({super.key, this.error});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  Timer? _watchdogTimer;
  Timer? _fallbackTimer;
  bool _showFallback = false;

  @override
  void initState() {
    super.initState();
    // Display fallback action if startup takes more than 5 seconds
    _fallbackTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showFallback = true;
        });
      }
    });

    // Safety watchdog: automatically force completion if initialization takes more than 7 seconds
    _watchdogTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) {
        ref.read(loginStateProvider.notifier).forceCompleteInitialization();
      }
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _watchdogTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginStateProvider);
    final effectiveError = widget.error ?? (loginState.hasStartupError ? loginState.startupError : null);

    return Scaffold(
      backgroundColor: AppTheme.mainBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                  .animate()
                  .scale(duration: 800.ms, curve: Curves.easeOutBack)
                  .shimmer(delay: 1000.ms, duration: 1500.ms),
              const SizedBox(height: 24),
              Text(
                'QB Suite Customer',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0),
              const SizedBox(height: 8),
              Text(
                'Your Business Suite',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(delay: 600.ms),

              // Error and Retry State
              if (effectiveError != null) ...[
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.error_warning_fill,
                            color: Color(0xFFDC2626),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Startup Connection Issue',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        effectiveError,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF7F1D1D),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              ref
                                  .read(loginStateProvider.notifier)
                                  .retryInitialization();
                            },
                            icon: const Icon(Remix.refresh_line, size: 16),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(loginStateProvider.notifier)
                                  .forceCompleteInitialization();
                            },
                            child: Text(
                              'Continue to Login',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: const Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms),
              ] else if (_showFallback) ...[
                const SizedBox(height: 28),
                TextButton(
                  onPressed: () {
                    ref
                        .read(loginStateProvider.notifier)
                        .forceCompleteInitialization();
                  },
                  child: Text(
                    'Continue to Login',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
