import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../models/ai_studio_model.dart';
import '../services/customer_ai_studio_service.dart';
import '../viewmodels/customer_ai_studio_viewmodel.dart';

/// Modal bottom sheet for connecting a social media account.
///
/// For INSTAGRAM: launches the backend OAuth URL in the system browser and
/// polls the accounts list until the new account appears (or times out).
///
/// For other platforms: shows the existing manual-entry form.
class CustomerSocialConnectModal extends ConsumerStatefulWidget {
  final String? initialPlatform;

  const CustomerSocialConnectModal({super.key, this.initialPlatform});

  @override
  ConsumerState<CustomerSocialConnectModal> createState() =>
      _CustomerSocialConnectModalState();
}

class _CustomerSocialConnectModalState
    extends ConsumerState<CustomerSocialConnectModal> {
  late String _platform;

  // ── OAuth (Instagram) state ────────────────────────────────────────────────
  bool _isLaunchingOAuth = false;
  bool _isPolling = false;
  String? _oauthError;
  Timer? _pollTimer;
  int _pollCount = 0;
  static const int _maxPolls = 10; // 10 × 3 s = 30 s timeout
  /// Snapshot of account IDs before OAuth starts — used to detect new arrivals.
  Set<int> _accountIdsBeforeOAuth = {};

  // ── Manual-form state (for non-Instagram platforms) ────────────────────────
  final _nameController = TextEditingController(text: 'Business Account');
  final _usernameController = TextEditingController(text: 'brand_account');
  bool _isSaving = false;

  // ── Supported OAuth platforms ──────────────────────────────────────────────
  static const _oauthPlatforms = {
    'INSTAGRAM',
    'FACEBOOK',
    'YOUTUBE',
    'LINKEDIN',
    'TIKTOK',
  };

  @override
  void initState() {
    super.initState();
    final p = widget.initialPlatform?.toUpperCase() ?? 'INSTAGRAM';
    if ([
      'INSTAGRAM',
      'FACEBOOK',
      'YOUTUBE',
      'LINKEDIN',
      'TIKTOK',
    ].contains(p)) {
      _platform = p;
    } else {
      _platform = 'INSTAGRAM';
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // ── OAuth flow ─────────────────────────────────────────────────────────────

  Future<void> _startOAuth() async {
    setState(() {
      _isLaunchingOAuth = true;
      _oauthError = null;
    });

    final service = ref.read(customerAiStudioServiceProvider);

    // Snapshot current account IDs so we can detect newly-added accounts
    final current = ref.read(customerSocialAccountsProvider).value ?? [];
    _accountIdsBeforeOAuth = current.map((a) => a.id).toSet();

    // Get the OAuth URL from the backend
    final authUrl = await service.fetchOAuthStartUrl(_platform);
    if (authUrl == null || authUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isLaunchingOAuth = false;
          _oauthError =
              'Could not get authorization URL. Please check your connection and try again.';
        });
      }
      return;
    }

    // Launch in external browser
    final uri = Uri.parse(authUrl);
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[OAUTH_LAUNCH_ERROR] $e');
    }

    if (!launched) {
      if (mounted) {
        setState(() {
          _isLaunchingOAuth = false;
          _oauthError =
              'Could not open the browser. Please try again or connect manually.';
        });
      }
      return;
    }

    // Browser opened — start polling for the new account
    if (mounted) {
      setState(() {
        _isLaunchingOAuth = false;
        _isPolling = true;
        _pollCount = 0;
      });
    }
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) {
        _pollTimer?.cancel();
        return;
      }

      _pollCount++;
      debugPrint('[OAUTH_POLL] Poll #$_pollCount for new $_platform account');

      // Refresh the provider
      await ref.read(customerSocialAccountsProvider.notifier).refresh();
      final latest = ref.read(customerSocialAccountsProvider).value ?? [];

      // Check if a new account appeared
      final newAcc = latest.cast<SocialAccountModel?>().firstWhere(
        (a) =>
            a != null &&
            !_accountIdsBeforeOAuth.contains(a.id) &&
            a.platform.toUpperCase() == _platform,
        orElse: () => null,
      );

      if (newAcc != null) {
        _pollTimer?.cancel();
        ref.read(selectedSocialAccountProvider.notifier).selectAccount(newAcc);
        if (mounted) {
          Navigator.pop(context, newAcc);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$_platform account connected!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
        return;
      }

      // Timeout after maxPolls
      if (_pollCount >= _maxPolls) {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() {
            _isPolling = false;
            _oauthError =
                'Connection timed out. If you completed authorization in the browser, '
                'please close this dialog and reopen it — your account should appear.';
          });
        }
      }
    });
  }

  void _cancelPolling() {
    _pollTimer?.cancel();
    if (mounted) setState(() => _isPolling = false);
  }

  // ── Manual-form connect (for LINKEDIN, TIKTOK, others) ────────────────────

  Future<void> _handleManualConnect() async {
    final accountName = _nameController.text.trim();
    if (accountName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an account or page name.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final service = ref.read(customerAiStudioServiceProvider);
    try {
      final acc = await service.connectSocialAccount(
        platform: _platform,
        accountName: accountName,
        username: _usernameController.text.trim().isNotEmpty
            ? _usernameController.text.trim()
            : null,
        accessToken: 'manual_${DateTime.now().millisecondsSinceEpoch}',
        externalAccountId: 'ext_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (acc != null) {
        await ref.read(customerSocialAccountsProvider.notifier).refresh();
        ref.read(selectedSocialAccountProvider.notifier).selectAccount(acc);

        if (mounted) {
          Navigator.pop(context, acc);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected $_platform account!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Connect Social Channel',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    _pollTimer?.cancel();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Platform selector
            DropdownButtonFormField<String>(
              initialValue: _platform,
              decoration: InputDecoration(
                labelText: 'Platform',
                labelStyle: GoogleFonts.outfit(fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'INSTAGRAM',
                  child: Text('Instagram Business'),
                ),
                DropdownMenuItem(
                  value: 'FACEBOOK',
                  child: Text('Facebook Page'),
                ),
                DropdownMenuItem(
                  value: 'YOUTUBE',
                  child: Text('YouTube Shorts / Channel'),
                ),
                DropdownMenuItem(
                  value: 'LINKEDIN',
                  child: Text('LinkedIn Company'),
                ),
                DropdownMenuItem(value: 'TIKTOK', child: Text('TikTok')),
              ],
              onChanged: _isPolling || _isLaunchingOAuth
                  ? null
                  : (v) {
                      if (v != null) {
                        setState(() {
                          _platform = v;
                          _oauthError = null;
                        });
                      }
                    },
            ),
            const SizedBox(height: 16),

            // Error banner
            if (_oauthError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _oauthError!,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // OAuth platforms — show OAuth button
            if (_oauthPlatforms.contains(_platform)) ...[
              if (_isPolling) _buildPollingState() else _buildOAuthButton(),
            ] else ...[
              // Manual-entry form for LINKEDIN / TIKTOK / others
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Account / Page Name',
                  labelStyle: GoogleFonts.outfit(fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Handle / Username (@)',
                  labelStyle: GoogleFonts.outfit(fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isSaving ? null : _handleManualConnect,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Connect Account',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOAuthButton() {
    final platformLabel =
        {
          'INSTAGRAM': 'Instagram',
          'FACEBOOK': 'Facebook',
          'YOUTUBE': 'YouTube',
          'LINKEDIN': 'LinkedIn',
          'TIKTOK': 'TikTok',
        }[_platform] ??
        _platform;

    final buttonColor =
        {
          'INSTAGRAM': const Color(0xFFE1306C),
          'FACEBOOK': const Color(0xFF1877F2),
          'YOUTUBE': const Color(0xFFFF0000),
          'LINKEDIN': const Color(0xFF0A66C2),
          'TIKTOK': const Color(0xFF010101),
        }[_platform] ??
        AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.security_rounded,
                    size: 16,
                    color: Color(0xFF1D4ED8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Secure OAuth Connection',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'You will be redirected to $platformLabel to authorize QuikBoom. '
                'No passwords are stored — only a secure access token.',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: const Color(0xFF1E3A8A),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Connect button
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isLaunchingOAuth
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.open_in_browser_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
            label: Text(
              _isLaunchingOAuth
                  ? 'Opening $platformLabel…'
                  : 'Connect with $platformLabel',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            onPressed: _isLaunchingOAuth ? null : _startOAuth,
          ),
        ),
      ],
    );
  }

  Widget _buildPollingState() {
    final platformLabel =
        {
          'INSTAGRAM': 'Instagram',
          'FACEBOOK': 'Facebook',
          'YOUTUBE': 'YouTube',
          'LINKEDIN': 'LinkedIn',
          'TIKTOK': 'TikTok',
        }[_platform] ??
        _platform;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Waiting for $platformLabel authorization…',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF065F46),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Complete authorization in the browser,\nthen return to this app.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: const Color(0xFF047857),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Checking… ($_pollCount/$_maxPolls)',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _cancelPolling,
          child: Text(
            'Cancel',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }
}
