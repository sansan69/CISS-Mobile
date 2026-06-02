import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/features/auth/presentation/login_hub_screen.dart';
import 'package:ciss_mobile/features/auth/presentation/guard_pin_setup_screen.dart';
import 'package:ciss_mobile/features/auth/presentation/role_login_screen.dart';

void main() {
  testWidgets('renders mobile role hub', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginHubScreen())),
    );
    // pumpAndSettle can't settle because of infinite animation.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('SELECT YOUR PORTAL'), findsOneWidget);
    expect(find.text('GUARD OPERATIONS'), findsOneWidget);
    expect(find.text('FIELD COMMAND'), findsOneWidget);
  });

  testWidgets('renders guard login entry point', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RoleLoginScreen.guard()),
      ),
    );
    // pumpAndSettle can't settle because SecurityGridBackground runs
    // an infinite AnimationController.repeat(). Use pump to skip forward.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('GUARD ACCESS'), findsOneWidget);
    expect(find.text('Employee ID or phone'), findsOneWidget);
    expect(find.text('Duty PIN'), findsOneWidget);
    expect(find.text('Set up PIN for first-time login'), findsOneWidget);
  });

  testWidgets(
    'renders field officer login entry point',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: RoleLoginScreen.fieldOfficer()),
        ),
      );
    // pumpAndSettle can't settle because SecurityGridBackground runs
    // an infinite AnimationController.repeat(). Use pump to skip forward.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('OFFICER ACCESS'), findsOneWidget);
    expect(find.text('Official email'), findsOneWidget);
    expect(find.text('Account password'), findsOneWidget);
  },
  );

  testWidgets('renders guard PIN setup flow', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GuardPinSetupScreen(
            initialEmployeeId: 'EMP001',
            initialPhoneNumber: '9999999999',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up your PIN'), findsOneWidget);
    expect(find.text('Registered phone number'), findsOneWidget);
    expect(find.text('Date of birth'), findsOneWidget);
    expect(find.text('Create PIN'), findsOneWidget);
  });
}
