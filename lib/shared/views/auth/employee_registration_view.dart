import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/shared/services/employee_auth_service.dart';

class EmployeeRegistrationView extends ConsumerStatefulWidget {
  const EmployeeRegistrationView({super.key});

  @override
  ConsumerState<EmployeeRegistrationView> createState() =>
      _EmployeeRegistrationViewState();
}

class _EmployeeRegistrationViewState
    extends ConsumerState<EmployeeRegistrationView> {
  final _formKey = GlobalKey<FormState>();

  // Step 1 Controllers
  final _fullNameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _referralCodeCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();

  // Employee Type Selection: 'COMPANY' or 'FREELANCER'
  String? _selectedEmployeeType;

  // State
  int _currentStep = 1; // 1: Details, 2: Plan, 3: Payment
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _acceptedTerms = false;
  bool _isLoading = false;

  // Selected Plan in Step 2: 1: Starter, 2: Professional, 3: Elite
  int _selectedPlanId = 1;
  String _selectedPaymentMethod = 'OFFLINE'; // 'ONLINE' or 'OFFLINE'

  // Inline Validation Error State
  String? _fullNameError;
  String? _cityError;
  String? _mobileError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _employeeTypeError;
  String? _termsError;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _cityCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _referralCodeCtrl.dispose();
    _companyNameCtrl.dispose();
    super.dispose();
  }

  bool _validateStep1() {
    bool isValid = true;
    final fullName = _fullNameCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final confirmPassword = _confirmPasswordCtrl.text.trim();

    setState(() {
      // 1. Full Name
      if (fullName.isEmpty || fullName.length < 2) {
        _fullNameError = 'Please enter your full name.';
        isValid = false;
      } else {
        _fullNameError = null;
      }

      // 2. City / Location
      if (city.isEmpty) {
        _cityError = 'Please enter your city/location.';
        isValid = false;
      } else {
        _cityError = null;
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

      // 5. Password
      if (password.isEmpty || password.length < 6) {
        _passwordError = 'Password must be at least 6 characters.';
        isValid = false;
      } else {
        _passwordError = null;
      }

      // 6. Confirm Password
      if (confirmPassword.isEmpty) {
        _confirmPasswordError = 'Please confirm your password.';
        isValid = false;
      } else if (password != confirmPassword) {
        _confirmPasswordError = 'Passwords do not match.';
        isValid = false;
      } else {
        _confirmPasswordError = null;
      }

      // 7. Employee Type (MANDATORY)
      if (_selectedEmployeeType == null ||
          !['COMPANY', 'FREELANCER'].contains(_selectedEmployeeType)) {
        _employeeTypeError = 'Please select employee type.';
        isValid = false;
      } else {
        _employeeTypeError = null;
      }

      // 8. Terms & Conditions
      if (!_acceptedTerms) {
        _termsError = 'Please accept the Terms and Conditions to proceed.';
        isValid = false;
      } else {
        _termsError = null;
      }
    });

    return isValid;
  }

  void _goToStep2() {
    FocusScope.of(context).unfocus();
    if (!_validateStep1()) {
      AppToast.warning(
        context,
        _employeeTypeError ?? 'Please fix form errors before continuing.',
      );
      return;
    }
    setState(() => _currentStep = 2);
  }

  void _goToStep3() {
    setState(() => _currentStep = 3);
  }

  Future<void> _handleCompleteRegistration() async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(employeeAuthServiceProvider);
      await authService.registerEmployee(
        fullName: _fullNameCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        confirmPassword: _confirmPasswordCtrl.text.trim(),
        employeeType: _selectedEmployeeType!,
        referralCode: _referralCodeCtrl.text.trim().isNotEmpty
            ? _referralCodeCtrl.text.trim()
            : null,
        companyName:
            _selectedEmployeeType == 'COMPANY' &&
                _companyNameCtrl.text.trim().isNotEmpty
            ? _companyNameCtrl.text.trim()
            : null,
        planId: _selectedPlanId,
        paymentMethod: _selectedPaymentMethod,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.success(
          context,
          'Registration submitted successfully! You can login with your Email & Password once verified.',
          title: 'Registration Successful',
          isAuthToast: true,
        );

        // Show dialog and return to LoginView
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(
                  Remix.checkbox_circle_fill,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Account Created',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'Your employee account (${_selectedEmployeeType == 'FREELANCER' ? 'Freelancer' : 'Company Employee'}) has been registered.\n\nUse your Email (${_emailCtrl.text.trim()}) and Password to log in.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  Navigator.pop(context); // Go back to login screen
                },
                child: Text(
                  'Proceed to Login',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
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
        leading: BackButton(
          color: AppColors.textPrimary,
          onPressed: () {
            if (_currentStep > 1) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _currentStep == 1
              ? 'Step 1 of 3: Details'
              : _currentStep == 2
              ? 'Step 2 of 3: Choose Plan'
              : 'Step 3 of 3: Payment',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _currentStep == 1
                  ? _buildStep1()
                  : _currentStep == 2
                  ? _buildStep2()
                  : _buildStep3(),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // STEP 1: EMPLOYEE DETAILS & EMPLOYEE TYPE SELECTION
  // ══════════════════════════════════════════════════════════
  Widget _buildStep1() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Remix.user_star_fill,
                  color: AppColors.primaryDark,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'EMPLOYEE REGISTRATION',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    letterSpacing: 0.5,
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
            'Personal & Professional Details',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Field 1: Full Name *
          _buildInputField(
            controller: _fullNameCtrl,
            label: 'Full Name *',
            hint: 'e.g. Rahul Sharma',
            icon: Remix.user_3_line,
            errorText: _fullNameError,
            onChanged: (_) {
              if (_fullNameError != null) setState(() => _fullNameError = null);
            },
          ),
          const SizedBox(height: 14),

          // Field 2: City / Location *
          _buildInputField(
            controller: _cityCtrl,
            label: 'City / Location *',
            hint: 'e.g. Mumbai',
            icon: Remix.map_pin_2_line,
            errorText: _cityError,
            onChanged: (_) {
              if (_cityError != null) setState(() => _cityError = null);
            },
          ),
          const SizedBox(height: 14),

          // Field 3: Mobile Number *
          _buildInputField(
            controller: _mobileCtrl,
            label: 'Mobile Number *',
            hint: '+91 98765 43210',
            icon: Remix.smartphone_line,
            keyboardType: TextInputType.phone,
            errorText: _mobileError,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
            ],
            onChanged: (_) {
              if (_mobileError != null) setState(() => _mobileError = null);
            },
          ),
          const SizedBox(height: 14),

          // Field 4: Email Address *
          _buildInputField(
            controller: _emailCtrl,
            label: 'Email Address *',
            hint: 'employee@company.com',
            icon: Remix.mail_line,
            keyboardType: TextInputType.emailAddress,
            errorText: _emailError,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          const SizedBox(height: 14),

          // Field 5: Password *
          _buildInputField(
            controller: _passwordCtrl,
            label: 'Password *',
            hint: '•••••••• (min. 6 characters)',
            icon: Remix.lock_2_line,
            isPassword: true,
            isPasswordVisible: _isPasswordVisible,
            errorText: _passwordError,
            onTogglePassword: () {
              setState(() => _isPasswordVisible = !_isPasswordVisible);
            },
            onChanged: (_) {
              if (_passwordError != null) setState(() => _passwordError = null);
            },
          ),
          const SizedBox(height: 14),

          // Field 6: Confirm Password *
          _buildInputField(
            controller: _confirmPasswordCtrl,
            label: 'Confirm Password *',
            hint: '••••••••',
            icon: Remix.lock_password_line,
            isPassword: true,
            isPasswordVisible: _isConfirmPasswordVisible,
            errorText: _confirmPasswordError,
            onTogglePassword: () {
              setState(
                () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
              );
            },
            onChanged: (_) {
              if (_confirmPasswordError != null) {
                setState(() => _confirmPasswordError = null);
              }
            },
          ),
          const SizedBox(height: 18),

          // ══════════════════════════════════════════════════
          // EMPLOYEE TYPE: [ Company ] [ Freelancer ]
          // ══════════════════════════════════════════════════
          Text(
            'Employee Type *',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              // Option 1: Company
              Expanded(
                child: _buildTypeCard(
                  type: 'COMPANY',
                  title: 'Company',
                  subtitle: 'Corporate Employee',
                  icon: Remix.building_2_line,
                ),
              ),
              const SizedBox(width: 12),

              // Option 2: Freelancer
              Expanded(
                child: _buildTypeCard(
                  type: 'FREELANCER',
                  title: 'Freelancer',
                  subtitle: 'Independent Pro',
                  icon: Remix.user_smile_line,
                ),
              ),
            ],
          ),

          // Inline validation for Employee Type
          if (_employeeTypeError != null) ...[
            const SizedBox(height: 6),
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
                  Text(
                    _employeeTypeError!,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Optional Company Name if Company selected
          if (_selectedEmployeeType == 'COMPANY') ...[
            const SizedBox(height: 14),
            _buildInputField(
              controller: _companyNameCtrl,
              label: 'Company / Organization Name (Optional)',
              hint: 'e.g. Apex Media House',
              icon: Remix.building_line,
            ),
          ],

          const SizedBox(height: 14),

          // Referral Code (Optional)
          _buildInputField(
            controller: _referralCodeCtrl,
            label: 'Referral Code (Optional)',
            hint: 'e.g. REF-2026',
            icon: Remix.gift_line,
          ),

          const SizedBox(height: 16),

          // Terms & Conditions Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _acceptedTerms,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _acceptedTerms = val ?? false;
                      if (_acceptedTerms) _termsError = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'I agree to the Terms & Conditions and Privacy Policy of QB Suite.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          if (_termsError != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                _termsError!,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // CTA: [ Aage Jao — Plan Choose Karo ]
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _goToStep2,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Aage Jao — Plan Choose Karo',
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

          // Already registered? Sign In
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
    );
  }

  // ══════════════════════════════════════════════════════════
  // STEP 2: PLAN SELECTION
  // ══════════════════════════════════════════════════════════
  Widget _buildStep2() {
    final plans = [
      {
        'id': 1,
        'name': 'Starter Plan',
        'price': '₹2,499 / mo',
        'desc': 'For growing professionals and freelancers starting out.',
        'features': ['CRM & Calendar', 'Up to 500 Leads', 'Standard Support'],
      },
      {
        'id': 2,
        'name': 'Professional Plan',
        'price': '₹4,999 / mo',
        'desc': 'For teams and seasoned freelancers with high volumes.',
        'features': [
          'All Starter Features',
          'Unlimited Leads',
          'Priority Support',
          'Live Geofence Tracking',
        ],
      },
      {
        'id': 3,
        'name': 'Elite Plan',
        'price': '₹9,999 / mo',
        'desc': 'Enterprise features for high-performance production.',
        'features': [
          'All Pro Features',
          'Dedicated Manager',
          'Custom Workflows',
          'Audit Logs & Analytics',
        ],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 2: Choose Your Plan',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select the plan that fits your work requirements.',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),

        ...plans.map((p) {
          final isSelected = _selectedPlanId == p['id'];
          return GestureDetector(
            onTap: () => setState(() => _selectedPlanId = p['id'] as int),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF0FDF4) : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        p['name'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        p['price'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p['desc'] as String,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (p['features'] as List<String>).map((f) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.checkbox_circle_line,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            f,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 20),

        // CTA: [ Proceed to Payment ]
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _goToStep3,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Proceed to Payment',
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
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // STEP 3: PAYMENT
  // ══════════════════════════════════════════════════════════
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 3: Payment Verification',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose your preferred payment mode to activate account.',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),

        // Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registration Summary',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 20),
              _summaryRow('Name', _fullNameCtrl.text.trim()),
              _summaryRow('Email', _emailCtrl.text.trim()),
              _summaryRow('City', _cityCtrl.text.trim()),
              _summaryRow(
                'Employee Type',
                _selectedEmployeeType == 'FREELANCER'
                    ? 'Freelancer'
                    : 'Company',
              ),
              _summaryRow(
                'Selected Plan',
                _selectedPlanId == 1
                    ? 'Starter Plan'
                    : _selectedPlanId == 2
                    ? 'Professional Plan'
                    : 'Elite Plan',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Select Payment Method',
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // Option 1: Online (Razorpay)
        _buildPaymentOption(
          method: 'ONLINE',
          title: 'Online Payment (Instant)',
          subtitle: 'UPI, Credit/Debit Card, Netbanking via Razorpay',
          icon: Remix.secure_payment_line,
        ),
        const SizedBox(height: 10),

        // Option 2: Offline Request
        _buildPaymentOption(
          method: 'OFFLINE',
          title: 'Offline Payment Request',
          subtitle:
              'Bank Transfer / Cash. Account activated after Admin review.',
          icon: Remix.bank_card_line,
        ),

        const SizedBox(height: 24),

        // CTA: [ Complete Registration & Pay ]
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleCompleteRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
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
                : Text(
                    _selectedPaymentMethod == 'ONLINE'
                        ? 'Pay & Activate Account'
                        : 'Submit Registration Request',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String method,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedPaymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Remix.checkbox_circle_fill,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // EMPLOYEE TYPE TOGGLE CARD [ Company ] [ Freelancer ]
  // ══════════════════════════════════════════════════════════
  Widget _buildTypeCard({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedEmployeeType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedEmployeeType = type;
          _employeeTypeError = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? AppColors.primaryDark
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
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
