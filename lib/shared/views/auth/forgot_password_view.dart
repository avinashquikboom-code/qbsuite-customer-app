import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/constants/app_bar_titles.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:remixicon/remixicon.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // 'email' or 'mobile'
  String _resetMethod = 'email';

  // Stages: 'input' → 'otp' (mobile only) → 'success'
  String _stage = 'input';

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Email reset flow ─────────────────────────────────────────────────
  void _handleEmailReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppToast.warning(context, 'Please enter your corporate email address.');
      return;
    }
    if (!email.contains('@')) {
      AppToast.warning(context, 'Please enter a valid email address.');
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _stage = 'success';
    });
  }

  // ── Mobile reset flow ────────────────────────────────────────────────
  void _handleSendOtp() async {
    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty || mobile.length < 10) {
      AppToast.warning(context, 'Please enter a valid 10-digit mobile number.');
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _stage = 'otp';
    });
    AppToast.success(
      context,
      'OTP sent to +91 ${_mobileController.text.trim()}',
      title: 'OTP Sent',
    );
  }

  void _handleVerifyOtp() async {
    if (_otpController.text.trim().length < 4) {
      AppToast.warning(context, 'Please enter the OTP code received via SMS.');
      return;
    }
    final pwd = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (pwd.length < 6) {
      AppToast.warning(context, 'Password must be at least 6 characters.');
      return;
    }
    if (pwd != confirm) {
      AppToast.error(context, 'Passwords do not match.', title: 'Mismatch');
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _stage = 'success';
    });
  }

  void _resetToInput() {
    setState(() {
      _stage = 'input';
      _otpController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: AppBarTitles.forgotPassword),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icon + heading ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Remix.lock_unlock_line,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Reset Your Password',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _stage == 'otp'
                    ? 'Enter the OTP sent to your mobile and set a new password.'
                    : _stage == 'success'
                    ? 'Your password reset was successful.'
                    : 'Choose how you want to receive the reset link.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // ── Body: AnimatedSwitcher across stages ────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _stage == 'success'
                    ? _buildSuccessCard()
                    : _stage == 'otp'
                    ? _buildOtpStage()
                    : _buildInputStage(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // STAGE 1: INPUT — Method selector + field
  // ════════════════════════════════════════════════════════════════════
  Widget _buildInputStage() {
    return Column(
      key: const ValueKey('input_stage'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Method toggle ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _methodTab(
                label: 'Via Email',
                icon: Remix.mail_line,
                isActive: _resetMethod == 'email',
                onTap: () => setState(() => _resetMethod = 'email'),
              ),
              _methodTab(
                label: 'Via Mobile OTP',
                icon: Remix.smartphone_line,
                isActive: _resetMethod == 'mobile',
                onTap: () => setState(() => _resetMethod = 'mobile'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Input field (switches with AnimatedSwitcher) ──────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: _resetMethod == 'email'
              ? _buildEmailField()
              : _buildMobileField(),
        ),
        const SizedBox(height: 24),

        // ── CTA Button ────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading
                ? null
                : (_resetMethod == 'email'
                      ? _handleEmailReset
                      : _handleSendOtp),
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _resetMethod == 'email'
                        ? Remix.send_plane_line
                        : Remix.message_2_line,
                    size: 18,
                  ),
            label: Text(
              _isLoading
                  ? 'Sending…'
                  : _resetMethod == 'email'
                  ? 'Send Reset Link'
                  : 'Send OTP to Mobile',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),

        // ── Info note ─────────────────────────────────────────────────
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Remix.information_line,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _resetMethod == 'email'
                      ? 'A reset link will be sent to your registered corporate email. Check your inbox and spam folder.'
                      : 'A 6-digit OTP will be sent to your registered mobile number via SMS.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // STAGE 2: OTP + NEW PASSWORD (mobile only)
  // ════════════════════════════════════════════════════════════════════
  Widget _buildOtpStage() {
    return Column(
      key: const ValueKey('otp_stage'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // OTP sent banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Remix.message_2_line,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'OTP sent to +91 ${_mobileController.text.trim()}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _isLoading ? null : _resetToInput,
                child: Text(
                  'Change',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // OTP field
        _fieldLabel('OTP Code'),
        const SizedBox(height: 8),
        _styledTextField(
          controller: _otpController,
          hint: '6-digit OTP',
          icon: Remix.shield_check_line,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),
        const SizedBox(height: 20),

        // New Password
        _fieldLabel('New Password'),
        const SizedBox(height: 8),
        _styledTextField(
          controller: _newPasswordController,
          hint: 'Minimum 6 characters',
          icon: Remix.lock_password_line,
          isPassword: true,
          isPasswordVisible: _isPasswordVisible,
          onToggleVisibility: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
        const SizedBox(height: 16),

        // Confirm Password
        _fieldLabel('Confirm New Password'),
        const SizedBox(height: 8),
        _styledTextField(
          controller: _confirmPasswordController,
          hint: 'Repeat new password',
          icon: Remix.lock_2_line,
          isPassword: true,
          isPasswordVisible: _isConfirmPasswordVisible,
          onToggleVisibility: () => setState(
            () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
          ),
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleVerifyOtp,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Remix.check_double_line, size: 18),
            label: Text(
              _isLoading ? 'Verifying…' : 'Verify OTP & Reset Password',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: _isLoading ? null : _handleSendOtp,
            icon: const Icon(Remix.refresh_line, size: 16),
            label: Text(
              'Resend OTP',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // STAGE 3: SUCCESS CARD
  // ════════════════════════════════════════════════════════════════════
  Widget _buildSuccessCard() {
    final isEmail = _resetMethod == 'email';
    final sentTo = isEmail
        ? _emailController.text.trim()
        : '+91 ${_mobileController.text.trim()}';

    return Column(
      key: const ValueKey('success_stage'),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.08),
                AppColors.primary.withValues(alpha: 0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isEmail ? Remix.mail_check_line : Remix.shield_check_line,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isEmail ? 'Check Your Email' : 'Password Reset!',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isEmail
                    ? 'Reset instructions have been sent to:\n$sentTo'
                    : 'Your password has been successfully reset.\nYou can now sign in.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Remix.arrow_left_line, size: 18),
            label: Text(
              'Back to Sign In',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════

  Widget _methodTab({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      key: const ValueKey('email_field'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Corporate Email Address'),
        const SizedBox(height: 8),
        _styledTextField(
          controller: _emailController,
          hint: 'Enter your registered corporate email',
          icon: Remix.mail_line,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  Widget _buildMobileField() {
    return Column(
      key: const ValueKey('mobile_field'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Registered Mobile Number'),
        const SizedBox(height: 8),
        _styledTextField(
          controller: _mobileController,
          hint: '+91 98765 43210',
          icon: Remix.smartphone_line,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
            LengthLimitingTextInputFormatter(13),
          ],
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _styledTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: isPassword && !isPasswordVisible,
      style: GoogleFonts.outfit(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(
          color: AppColors.textSecondary.withValues(alpha: 0.7),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isPasswordVisible ? Remix.eye_off_line : Remix.eye_line,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        fillColor: AppColors.surface,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
