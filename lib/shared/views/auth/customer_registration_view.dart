import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/shared/services/customer_auth_service.dart';
import 'package:quickboom_crm_customer/core/services/secure_storage_service.dart';
import 'package:quickboom_crm_customer/roles/customer/views/customer_dashboard_view.dart';

class CustomerRegistrationView extends ConsumerStatefulWidget {
  const CustomerRegistrationView({super.key});

  @override
  ConsumerState<CustomerRegistrationView> createState() =>
      _CustomerRegistrationViewState();
}

class _CustomerRegistrationViewState
    extends ConsumerState<CustomerRegistrationView> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // Inline Validation Error State
  String? _fullNameError;
  String? _businessNameError;
  String? _mobileError;
  String? _emailError;
  String? _cityError;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _businessNameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _validateForm() {
    bool isValid = true;
    final fullName = _fullNameCtrl.text.trim();
    final business = _businessNameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final city = _cityCtrl.text.trim();

    setState(() {
      // 1. Full Name
      if (fullName.isEmpty || fullName.length < 2) {
        _fullNameError = 'Please enter your full name.';
        isValid = false;
      } else {
        _fullNameError = null;
      }

      // 2. Business / Company Name
      if (business.isEmpty) {
        _businessNameError = 'Please enter your business/company name.';
        isValid = false;
      } else {
        _businessNameError = null;
      }

      // 3. Mobile Number
      final digitsOnly = mobile.replaceAll(RegExp(r'[^0-9]'), '');
      if (mobile.isEmpty || digitsOnly.length < 10) {
        _mobileError = 'Please enter a valid mobile number.';
        isValid = false;
      } else {
        _mobileError = null;
      }

      // 4. Email Address
      final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
      if (email.isEmpty || !emailRegex.hasMatch(email)) {
        _emailError = 'Please enter a valid email address.';
        isValid = false;
      } else {
        _emailError = null;
      }

      // 5. City / Location
      if (city.isEmpty) {
        _cityError = 'Please enter your city/location.';
        isValid = false;
      } else {
        _cityError = null;
      }
    });

    return isValid;
  }

  Future<void> _handleSubmit() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (!_validateForm()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(customerAuthServiceProvider);
      await authService.registerCustomer(
        fullName: _fullNameCtrl.text.trim(),
        companyName: _businessNameCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        password: _passwordCtrl.text.trim().isNotEmpty
            ? _passwordCtrl.text.trim()
            : '123456',
      );

      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.success(
          context,
          'Account created successfully! Welcome to QB Suite Customer.',
          title: 'Registration Successful',
          isAuthToast: true,
        );

        final token = await SecureStorageService.getAccessToken();
        if (mounted) {
          if (token != null && token.isNotEmpty) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const CustomerDashboardView()),
              (route) => false,
            );
          } else {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.error(
          context,
          e.toString().replaceAll('Exception:', '').trim(),
          title: 'Registration Failed',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.building_2_fill,
                            color: AppColors.primaryDark,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'CUSTOMER REGISTRATION',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      'Create Your Account',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Subtitle
                    Text(
                      'Personal / Business Details',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Field 1: Full Name *
                    _buildInputField(
                      controller: _fullNameCtrl,
                      label: 'Full Name *',
                      hint: 'e.g. Rahul Sharma',
                      icon: Remix.user_3_line,
                      errorText: _fullNameError,
                      onChanged: (_) {
                        if (_fullNameError != null) {
                          setState(() => _fullNameError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Field 2: Business / Company Name *
                    _buildInputField(
                      controller: _businessNameCtrl,
                      label: 'Business / Company Name *',
                      hint: 'e.g. Apex Enterprises Pvt Ltd',
                      icon: Remix.building_line,
                      errorText: _businessNameError,
                      onChanged: (_) {
                        if (_businessNameError != null) {
                          setState(() => _businessNameError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Field 3: Mobile Number *
                    _buildInputField(
                      controller: _mobileCtrl,
                      label: 'Mobile Number *',
                      hint: '+91 98765 43210',
                      icon: Remix.smartphone_line,
                      keyboardType: TextInputType.phone,
                      errorText: _mobileError,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\-\s]'),
                        ),
                      ],
                      onChanged: (_) {
                        if (_mobileError != null) {
                          setState(() => _mobileError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Field 4: Email Address *
                    _buildInputField(
                      controller: _emailCtrl,
                      label: 'Email Address *',
                      hint: 'contact@company.com',
                      icon: Remix.mail_line,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError,
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Field 5: City / Location *
                    _buildInputField(
                      controller: _cityCtrl,
                      label: 'City / Location *',
                      hint: 'e.g. Mumbai, Maharashtra',
                      icon: Remix.map_pin_2_line,
                      errorText: _cityError,
                      onChanged: (_) {
                        if (_cityError != null) {
                          setState(() => _cityError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Optional Password Setup
                    _buildInputField(
                      controller: _passwordCtrl,
                      label: 'Set Password (Optional)',
                      hint: '•••••••• (Defaults to 123456)',
                      icon: Remix.lock_2_line,
                      isPassword: true,
                      isPasswordVisible: _isPasswordVisible,
                      onTogglePassword: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),

                    const SizedBox(height: 28),

                    // CTA: [ Create Account ]
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
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
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Create Account',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Remix.arrow_right_line,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Already have an account link
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Already registered? ',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              'Sign In',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? errorText,
    bool isPassword = false,
    bool isPasswordVisible = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    VoidCallback? onTogglePassword,
    ValueChanged<String>? onChanged,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword && !isPasswordVisible,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              icon,
              size: 20,
              color: hasError ? AppColors.error : AppColors.textSecondary,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isPasswordVisible ? Remix.eye_off_line : Remix.eye_line,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: onTogglePassword,
                  )
                : null,
            fillColor: AppColors.surface,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                const Icon(
                  Remix.error_warning_fill,
                  size: 13,
                  color: AppColors.error,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    errorText,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
