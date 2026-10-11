import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:ciss_mobile/core/auth/biometric_service.dart';
import 'package:ciss_mobile/core/auth/saved_accounts_service.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';
import 'package:ciss_mobile/features/auth/presentation/login_hub_screen.dart';
import 'package:ciss_mobile/features/auth/presentation/guard_pin_setup_screen.dart';
import 'package:ciss_mobile/features/auth/presentation/role_login_screen.dart';
import 'package:ciss_mobile/shared/widgets/brand_banner.dart';

Future<void> pumpFieldOfficerLogin(
  WidgetTester tester, {
  required FieldOfficerPasswordResetSender resetSender,
  List<Override> overrides = const <Override>[],
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        fieldOfficerPasswordResetSenderProvider.overrideWithValue(resetSender),
        ...overrides,
      ],
      child: const MaterialApp(home: RoleLoginScreen.fieldOfficer()),
    ),
  );
}

class FakeSavedAccountsService extends SavedAccountsService {
  FakeSavedAccountsService(this.accounts);

  final List<SavedAccount> accounts;
  var removeCallCount = 0;

  @override
  Future<List<SavedAccount>> loadForRole(String role) async {
    return accounts
        .where((SavedAccount account) => account.role == role)
        .toList();
  }

  @override
  Future<void> removeAccount(String role, String loginId) async {
    removeCallCount += 1;
  }
}

class FakeBiometricService extends BiometricService {
  FakeBiometricService({this.fingerprintOutcome});

  final Future<BiometricAuthOutcome>? fingerprintOutcome;
  var fingerprintCallCount = 0;

  @override
  Future<FingerprintSupport> checkFingerprintSupport() async {
    return const FingerprintSupport(
      availability: FingerprintAvailability.supported,
      enrolledBiometrics: [],
    );
  }

  @override
  Future<BiometricAuthOutcome> authenticateFingerprint({
    required String localizedReason,
  }) async {
    fingerprintCallCount += 1;
    return fingerprintOutcome ?? BiometricAuthOutcome.success;
  }
}

Future<void> selectGuardDateOfBirth(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.calendar_month_rounded));
  await tester.pumpAndSettle();
  await tester.tap(find.text('15').last);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> pumpGuardLogin(WidgetTester tester) {
  return tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: RoleLoginScreen.guard())),
  );
}

Future<void> pumpGuardPinSetup(
  WidgetTester tester, {
  required GuardPinSetupSender setupSender,
  required GuardPinSetupScreen screen,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        guardPinSetupSenderProvider.overrideWithValue(setupSender),
      ],
      child: MaterialApp(home: screen),
    ),
  );
}

void main() {
  testWidgets('renders mobile role hub', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginHubScreen())),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sign in as'), findsOneWidget);
    expect(find.text('Guard'), findsOneWidget);
    expect(find.text('Field Officer'), findsOneWidget);
  });

  testWidgets('renders guard login entry point', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RoleLoginScreen.guard())),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Guard login'), findsOneWidget);
    expect(find.text('Employee ID or phone'), findsOneWidget);
    expect(find.text('Duty PIN'), findsOneWidget);
    expect(find.text('Set up PIN for first-time login'), findsOneWidget);
  });

  testWidgets('renders field officer login entry point', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RoleLoginScreen.fieldOfficer()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Field Officer login'), findsOneWidget);
    expect(find.text('Official email'), findsOneWidget);
    expect(find.text('Account password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('invalid guard login input is rejected locally', (
    WidgetTester tester,
  ) async {
    await pumpGuardLogin(tester);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(
      find.text('Enter your employee ID or phone number.'),
      findsOneWidget,
    );
  });

  testWidgets('invalid password reset input makes zero calls', (
    WidgetTester tester,
  ) async {
    var resetCallCount = 0;
    await pumpFieldOfficerLogin(
      tester,
      resetSender: (String _) async => resetCallCount += 1,
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(find.byType(TextField).first, 'not-an-email');
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();

    expect(
      find.text('Enter a valid email address to reset your password.'),
      findsOneWidget,
    );
    expect(resetCallCount, 0);
  });

  testWidgets('validates field officer login before making a sign-in request', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RoleLoginScreen.fieldOfficer()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(find.byType(TextField).first, 'invalid-email');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'officer@cissindia.co.in',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('sends a valid Field Officer password reset and shows success', (
    WidgetTester tester,
  ) async {
    var resetCallCount = 0;
    String? requestedEmail;
    await pumpFieldOfficerLogin(
      tester,
      resetSender: (String email) async {
        resetCallCount += 1;
        requestedEmail = email;
      },
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(
      find.byType(TextField).first,
      ' officer@cissindia.co.in ',
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();

    expect(requestedEmail, 'officer@cissindia.co.in');
    expect(resetCallCount, 1);
    expect(
      find.text('If an account exists, reset instructions have been sent.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(1), 'new-password');
    await tester.pump();
    expect(
      find.text('If an account exists, reset instructions have been sent.'),
      findsNothing,
    );
  });

  testWidgets('shows a password reset error returned by the reset sender', (
    WidgetTester tester,
  ) async {
    await pumpFieldOfficerLogin(
      tester,
      resetSender: (String _) async {
        throw Exception(
          'Network error while sending reset instructions. Please check the connection.',
        );
      },
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(
      find.byType(TextField).first,
      'officer@cissindia.co.in',
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();

    expect(
      find.text(
        'Network error while sending reset instructions. Please check the connection.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('blocks sign-in controls while a password reset is running', (
    WidgetTester tester,
  ) async {
    final completer = Completer<void>();
    var resetCallCount = 0;
    await pumpFieldOfficerLogin(
      tester,
      resetSender: (String _) {
        resetCallCount += 1;
        return completer.future;
      },
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(
      find.byType(TextField).first,
      'officer@cissindia.co.in',
    );
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();

    final signInButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sign in'),
    );
    expect(signInButton.onPressed, isNull);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isFalse,
    );

    await tester.showKeyboard(find.byType(TextField).at(1));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(resetCallCount, 1);

    completer.complete();
    await tester.pump();
  });

  testWidgets('reset lock disables every saved-account action', (
    WidgetTester tester,
  ) async {
    final resetCompleter = Completer<void>();
    final savedAccounts = FakeSavedAccountsService(<SavedAccount>[
      SavedAccount(
        role: 'fieldOfficer',
        loginId: 'manual@cissindia.co.in',
        displayName: 'Manual account',
        lastLoginAt: DateTime(2026),
      ),
      SavedAccount(
        role: 'fieldOfficer',
        loginId: 'biometric@cissindia.co.in',
        displayName: 'Biometric account',
        lastLoginAt: DateTime(2026),
        biometricEnabled: true,
      ),
    ]);
    final biometrics = FakeBiometricService();
    await pumpFieldOfficerLogin(
      tester,
      resetSender: (String _) => resetCompleter.future,
      overrides: <Override>[
        savedAccountsServiceProvider.overrideWithValue(savedAccounts),
        biometricServiceProvider.overrideWithValue(biometrics),
      ],
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(
      find.byType(TextField).first,
      'reset@cissindia.co.in',
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump();

    await tester.tap(find.text('Manual account'));
    await tester.tap(find.text('Biometric account'));
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'reset@cissindia.co.in',
    );
    expect(biometrics.fingerprintCallCount, 0);
    expect(savedAccounts.removeCallCount, 0);

    resetCompleter.complete();
    await tester.pump();
  });

  testWidgets('a fingerprint-marked recent account only fills its identifier', (
    WidgetTester tester,
  ) async {
    final savedAccounts = FakeSavedAccountsService(<SavedAccount>[
      SavedAccount(
        role: 'fieldOfficer',
        loginId: 'manual@cissindia.co.in',
        displayName: 'Manual account',
        lastLoginAt: DateTime(2026),
      ),
      SavedAccount(
        role: 'fieldOfficer',
        loginId: 'biometric@cissindia.co.in',
        displayName: 'Biometric account',
        lastLoginAt: DateTime(2026),
        biometricEnabled: true,
      ),
    ]);
    final biometrics = FakeBiometricService();
    await pumpFieldOfficerLogin(
      tester,
      resetSender: (String _) async {},
      overrides: <Override>[
        savedAccountsServiceProvider.overrideWithValue(savedAccounts),
        biometricServiceProvider.overrideWithValue(biometrics),
      ],
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump();

    await tester.tap(find.text('Biometric account'));
    await tester.pump();

    expect(biometrics.fingerprintCallCount, 0);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'biometric@cissindia.co.in',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('invalid guard PIN setup input makes zero backend calls', (
    WidgetTester tester,
  ) async {
    var setupCallCount = 0;
    await pumpGuardPinSetup(
      tester,
      setupSender: ({
        required String employeeId,
        required String phoneNumber,
        required String dateOfBirth,
        required String pin,
      }) async {
        setupCallCount += 1;
      },
      screen: const GuardPinSetupScreen(),
    );
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    await tester.tap(find.text('Create PIN'));
    await tester.pump();

    expect(find.text('Enter the registered phone number.'), findsOneWidget);
    expect(setupCallCount, 0);
  });

  testWidgets('rejects unsupported guard setup phone characters before calls', (
    WidgetTester tester,
  ) async {
    var setupCallCount = 0;
    await pumpGuardPinSetup(
      tester,
      setupSender: ({
        required String employeeId,
        required String phoneNumber,
        required String dateOfBirth,
        required String pin,
      }) async {
        setupCallCount += 1;
      },
      screen: const GuardPinSetupScreen(),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(1), '98765abc43210');
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    await tester.tap(find.text('Create PIN'));
    await tester.pump();

    expect(
      find.text('Phone number contains unsupported characters.'),
      findsOneWidget,
    );
    expect(setupCallCount, 0);
  });

  testWidgets(
    'rejects short and non-digit guard setup PINs before backend calls',
    (WidgetTester tester) async {
      var setupCallCount = 0;
      await pumpGuardPinSetup(
        tester,
        setupSender: ({
          required String employeeId,
          required String phoneNumber,
          required String dateOfBirth,
          required String pin,
        }) async {
          setupCallCount += 1;
        },
        screen: const GuardPinSetupScreen(
          initialPhoneNumber: '+91 98765 43210',
        ),
      );
      await tester.pump();
      await selectGuardDateOfBirth(tester);

      await tester.enterText(find.byType(TextField).at(3), '123');
      await tester.enterText(find.byType(TextField).at(4), '123');
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
      await tester.tap(find.text('Create PIN'));
      await tester.pump();
      expect(find.text('Enter a 4 to 6 digit PIN.'), findsOneWidget);
      expect(setupCallCount, 0);

      await tester.enterText(find.byType(TextField).at(3), '12a4');
      await tester.enterText(find.byType(TextField).at(4), '12a4');
      await tester.tap(find.text('Create PIN'));
      await tester.pump();
      expect(find.text('Enter a 4 to 6 digit PIN.'), findsOneWidget);
    },
  );

  testWidgets('requires a guard setup DOB and matching PIN confirmation', (
    WidgetTester tester,
  ) async {
    var setupCallCount = 0;
    await pumpGuardPinSetup(
      tester,
      setupSender: ({
        required String employeeId,
        required String phoneNumber,
        required String dateOfBirth,
        required String pin,
      }) async {
        setupCallCount += 1;
      },
      screen: const GuardPinSetupScreen(initialPhoneNumber: '9876543210'),
    );
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    await tester.tap(find.text('Create PIN'));
    await tester.pump();
    expect(find.text('Select your date of birth.'), findsOneWidget);

    await selectGuardDateOfBirth(tester);
    await tester.enterText(find.byType(TextField).at(3), '1234');
    await tester.enterText(find.byType(TextField).at(4), '5678');
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    await tester.tap(find.text('Create PIN'));
    await tester.pump();
    expect(find.text('PIN confirmation does not match.'), findsOneWidget);
    expect(setupCallCount, 0);
  });

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

  testWidgets('valid guard PIN setup normalizes the phone and calls once', (
    WidgetTester tester,
  ) async {
    var setupCallCount = 0;
    String? submittedPhoneNumber;
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder:
              (_, __) => const GuardPinSetupScreen(
                initialPhoneNumber: '+91 (98765) 43210',
              ),
        ),
        GoRoute(
          path: '/login/guard',
          builder: (_, __) => const Scaffold(body: Text('Guard login page')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          guardPinSetupSenderProvider.overrideWithValue(({
            required String employeeId,
            required String phoneNumber,
            required String dateOfBirth,
            required String pin,
          }) async {
            setupCallCount += 1;
            submittedPhoneNumber = phoneNumber;
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await selectGuardDateOfBirth(tester);
    await tester.enterText(find.byType(TextField).at(3), '1234');
    await tester.enterText(find.byType(TextField).at(4), '1234');
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    await tester.tap(find.text('Create PIN'));
    await tester.pumpAndSettle();

    expect(setupCallCount, 1);
    expect(submittedPhoneNumber, '919876543210');
    expect(find.text('Guard login page'), findsOneWidget);
  });

  test('password reset maps every Firebase error branch exactly', () {
    expect(
      MobileRepository.passwordResetErrorMessage(
        FirebaseAuthException(code: 'invalid-email'),
      ),
      'Enter a valid email address.',
    );
    expect(
      MobileRepository.passwordResetErrorMessage(
        FirebaseAuthException(code: 'too-many-requests'),
      ),
      'Too many password reset attempts. Please wait and try again.',
    );
    expect(
      MobileRepository.passwordResetErrorMessage(
        FirebaseAuthException(code: 'network-request-failed'),
      ),
      'Network error while sending reset instructions. Please check the connection.',
    );
    expect(
      MobileRepository.passwordResetErrorMessage(
        FirebaseAuthException(code: 'operation-not-allowed'),
      ),
      'Password reset is currently unavailable. Please contact support.',
    );
    expect(
      MobileRepository.passwordResetErrorMessage(
        FirebaseAuthException(code: 'user-not-found'),
      ),
      isNull,
    );
    expect(
      MobileRepository.passwordResetErrorMessage(
        FirebaseAuthException(code: 'user-disabled'),
      ),
      isNull,
    );
    expect(
      MobileRepository.passwordResetErrorMessage(
        FirebaseAuthException(code: 'unexpected-reset-error'),
      ),
      'Could not send reset instructions. Please try again.',
    );
  });

  testWidgets('renders the shared CISS branded app header', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(appBar: CissAppBar(title: 'Attendance')),
      ),
    );

    expect(find.text('CISS WORKFORCE'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
  });
}
