import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/auth/login_role_card.dart';
import 'login_view.dart';

/// Pre-login Role Selection screen.
/// Presents supported roles (Customer, Employee).
class RoleSelectionView extends StatefulWidget {
  const RoleSelectionView({super.key});

  @override
  State<RoleSelectionView> createState() => _RoleSelectionViewState();
}

class _RoleSelectionViewState extends State<RoleSelectionView> {
  MobileUserRole? _selectedRole;

  void _navigateToLogin(MobileUserRole role) {
    setState(() => _selectedRole = role);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginView(initialRole: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 360;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 16 : 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  // App Logo
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Remix.apps_2_fill,
                        color: AppColors.primary,
                        size: 36,
                      ),
                    ),
                  ).animate().scale(
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: 18),

                  Text(
                    'QB SUITE',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select your account type to continue',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Customer Role Card
                  LoginRoleCard(
                    title: 'Customer',
                    subtitle: 'Orders, invoices, subscription plans & leads',
                    icon: Remix.user_3_line,
                    themeColor: AppColors.primary,
                    isSelected: _selectedRole == MobileUserRole.customer,
                    onTap: () => _navigateToLogin(MobileUserRole.customer),
                  ),
                  const SizedBox(height: 14),

                  // Employee Role Card
                  LoginRoleCard(
                    title: 'Employee',
                    subtitle: 'CRM workspace, attendance, field visits & tasks',
                    icon: Remix.briefcase_line,
                    themeColor: const Color(0xFF0F172A),
                    isSelected: _selectedRole == MobileUserRole.employee,
                    onTap: () => _navigateToLogin(MobileUserRole.employee),
                  ),
                  const SizedBox(height: 36),

                  Text(
                    'Need assistance? Contact your organization administrator.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
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
