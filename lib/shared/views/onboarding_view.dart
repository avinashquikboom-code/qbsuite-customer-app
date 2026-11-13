import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_theme.dart';
import 'package:quickboom_crm_customer/shared/services/onboarding_service.dart';
import 'auth/login_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  final OnboardingService _onboardingService = OnboardingService();
  int _currentPage = 0;
  bool _isNavigating = false;

  final List<OnboardingContent> _contents = [
    OnboardingContent(
      title: 'Welcome to QB Suite Customer',
      description: 'Manage your work easily from one place.',
      icon: Remix.rocket_2_line,
      color: AppTheme.primaryColor,
    ),
    OnboardingContent(
      title: 'Smart Attendance',
      description: 'Punch in, punch out and manage your breaks.',
      icon: Remix.fingerprint_line,
      color: AppTheme.primaryColor,
    ),
    OnboardingContent(
      title: 'Easy Work Management',
      description: 'Manage leave, remote work and visits from your mobile.',
      icon: Remix.checkbox_circle_line,
      color: AppTheme.primaryColor,
    ),
    OnboardingContent(
      title: 'Data Capture',
      description: 'Capture business information and create useful leads.',
      icon: Remix.compass_3_line,
      color: AppTheme.primaryColor,
    ),
    OnboardingContent(
      title: 'Payroll',
      description: 'Access your payroll and salary slips easily.',
      icon: Remix.receipt_line,
      color: AppTheme.primaryColor,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeAndNavigate() async {
    if (_isNavigating) return;
    _isNavigating = true;

    await _onboardingService.complete();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginView(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLastPage = _currentPage == _contents.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.topRight,
                child: isLastPage
                    ? const SizedBox(height: 48)
                    : TextButton(
                        onPressed: _completeAndNavigate,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ),

            // Onboarding Pages View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _contents.length,
                itemBuilder: (context, index) {
                  return _buildPage(_contents[index]);
                },
              ),
            ),

            // Bottom Navigation Area: Page Indicators + Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicators
                  Row(
                    children: List.generate(
                      _contents.length,
                      (index) => _buildIndicator(index),
                    ),
                  ),

                  // Next / Get Started Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isLastPage) {
                          _completeAndNavigate();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutCubic,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLastPage ? 'Get Started' : 'Next',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isLastPage
                                ? Remix.check_line
                                : Remix.arrow_right_line,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingContent content) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
                width: 140,
                height: 140,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: content.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: content.color.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Icon(content.icon, size: 72, color: content.color),
              )
              .animate()
              .scale(duration: 500.ms, curve: Curves.easeOutBack)
              .fadeIn(),
          const SizedBox(height: 48),
          Text(
            content.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.15),
          const SizedBox(height: 16),
          Text(
            content.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.15),
        ],
      ),
    );
  }

  Widget _buildIndicator(int index) {
    final bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingContent {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingContent({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
