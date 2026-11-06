import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qb_customer/features/auth/presentation/views/login_view.dart';

void main() {
  const viewports = <String, Size>{
    '320x568 compact': Size(320, 568),
    '360x800 compact': Size(360, 800),
    '375x812 standard': Size(375, 812),
    '390x844 standard': Size(390, 844),
    '412x915 large': Size(412, 915),
    '430x932 large': Size(430, 932),
    '600x960 tablet': Size(600, 960),
    '768x1024 tablet': Size(768, 1024),
  };

  for (final entry in viewports.entries) {
    testWidgets('login renders without overflow at ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginView())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('login stays keyboard-safe at ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginView())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      tester.view.viewInsets = FakeViewPadding(
        bottom: entry.value.height * 0.4,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    });
  }

  testWidgets('login supports landscape without overflow', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginView())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('login supports large text scaling', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: LoginView(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
