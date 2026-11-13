import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickboom_crm_customer/core/theme/app_theme.dart';
import 'package:quickboom_crm_customer/shared/views/auth/login_view.dart';
import 'package:quickboom_crm_customer/shared/views/auth/customer_registration_view.dart';

void main() {
  group('Customer Registration Form UI & Fields', () {
    testWidgets('Renders all required Customer Registration fields and CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CustomerRegistrationView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Your Account'), findsOneWidget);
      expect(find.text('Personal / Business Details'), findsOneWidget);
      expect(find.text('Full Name *'), findsOneWidget);
      expect(find.text('Business / Company Name *'), findsOneWidget);
      expect(find.text('Mobile Number *'), findsOneWidget);
      expect(find.text('Email Address *'), findsOneWidget);
      expect(find.text('City / Location *'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });
  });

  group('Customer Registration Validation Logic', () {
    testWidgets('Shows inline errors when submitting empty form', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CustomerRegistrationView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Create Account button without entering any text
      final createAccountBtn = find.text('Create Account');
      await tester.ensureVisible(createAccountBtn);
      await tester.tap(createAccountBtn);
      await tester.pumpAndSettle();

      // Verify inline error messages appear
      expect(find.text('Please enter your full name.'), findsOneWidget);
      expect(
        find.text('Please enter your business/company name.'),
        findsOneWidget,
      );
      expect(find.text('Please enter a valid mobile number.'), findsOneWidget);
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(find.text('Please enter your city/location.'), findsOneWidget);
    });

    testWidgets('Validates invalid mobile number and invalid email format', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CustomerRegistrationView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter valid name and company, but invalid phone and email
      await tester.enterText(find.byType(TextField).at(0), 'Rahul Sharma');
      await tester.enterText(find.byType(TextField).at(1), 'Apex Enterprises');
      await tester.enterText(
        find.byType(TextField).at(2),
        '123',
      ); // Invalid phone
      await tester.enterText(
        find.byType(TextField).at(3),
        'notanemail',
      ); // Invalid email
      await tester.enterText(find.byType(TextField).at(4), 'Mumbai');

      final createAccountBtn = find.text('Create Account');
      await tester.ensureVisible(createAccountBtn);
      await tester.tap(createAccountBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your full name.'), findsNothing);
      expect(
        find.text('Please enter your business/company name.'),
        findsNothing,
      );
      expect(find.text('Please enter your city/location.'), findsNothing);
      expect(find.text('Please enter a valid mobile number.'), findsOneWidget);
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });
  });

  group('Customer & Employee Role Card Selection on Login Screen', () {
    testWidgets(
      'Renders the customer login form matching the reference design',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: LoginView(initialRole: MobileUserRole.customer),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Login to Your Account'), findsOneWidget);
        expect(find.text('Choose your login type to continue'), findsOneWidget);
        expect(find.text('CUSTOMER WORKFORCE PORTAL'), findsOneWidget);
        expect(find.text('Employee'), findsNothing);
        expect(find.text('Enter your email address'), findsOneWidget);
        expect(find.text('Send OTP'), findsOneWidget);
        expect(find.text('Login with Password'), findsOneWidget);
        expect(find.text('Secure Login'), findsOneWidget);
        expect(find.text('Register'), findsOneWidget);
      },
    );

    testWidgets('Register opens the customer registration screen', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginView(initialRole: MobileUserRole.customer),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final register = find.text('Register');
      await tester.ensureVisible(register);
      await tester.pumpAndSettle();
      await tester.tap(register);
      await tester.pumpAndSettle();

      expect(find.text('Create Your Account'), findsOneWidget);
      expect(find.text('Business / Company Name *'), findsOneWidget);
    });

    testWidgets('Login stays on the customer portal', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginView(initialRole: MobileUserRole.customer),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CUSTOMER WORKFORCE PORTAL'), findsOneWidget);
      expect(find.text('Employee'), findsNothing);
      expect(find.text('EMPLOYEE WORKFORCE PORTAL'), findsNothing);
    });

    testWidgets('Password login stays on the customer portal', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginView(initialRole: MobileUserRole.customer),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Login with Password'));
      await tester.pumpAndSettle();

      expect(find.text('CUSTOMER WORKFORCE PORTAL'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
    });
  });

  group('Responsive Layout & Keyboard Tests across screen widths', () {
    final screenWidths = [320.0, 360.0, 375.0, 390.0, 414.0, 430.0];

    for (final width in screenWidths) {
      testWidgets(
        'Renders CustomerRegistrationView cleanly at ${width}px without overflow',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const CustomerRegistrationView(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Create Your Account'), findsOneWidget);
          expect(find.text('Create Account'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Simulates open keyboard (height 400px) at ${width}px without overflow',
        (tester) async {
          tester.view.physicalSize = Size(
            width,
            400,
          ); // Keyboard takes remaining space
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const CustomerRegistrationView(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Create Your Account'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
