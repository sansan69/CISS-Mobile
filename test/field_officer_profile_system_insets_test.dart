import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/core/models/guard_profile.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_guard_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/guard_redesign_fixtures.dart';

void main() {
  setUpAll(loadInterFont);

  testWidgets('profile viewport and header respect system insets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 914);
    const insets = FakeViewPadding(
      top: 48,
      bottom: 24,
      left: 20,
      right: 12,
    );
    tester.view.padding = insets;
    tester.view.viewPadding = insets;
    addTearDown(tester.view.reset);

    final guard = GuardProfileModel(
      id: 'fixture-1',
      fullName: 'Sample Employee',
      employeeId: 'TEST-001',
      clientName: 'Sample Client',
      district: 'Sample District',
      phoneNumber: '0000000000',
      status: 'Active',
    );
    await tester.pumpWidget(
      guardTestApp(
        screen: FieldOfficerGuardProfileScreen(guard: guard),
        role: AppRole.fieldOfficer,
        overrides: const <Override>[],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byType(ListView)),
      const Rect.fromLTRB(20, 48, 399, 890),
    );
    expect(
      tester.getTopLeft(find.text('Sample Employee').first).dy,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}
