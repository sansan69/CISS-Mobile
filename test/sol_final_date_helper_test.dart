import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'tcs_duty_large_text_test.dart' as existing;
import 'support/guard_redesign_fixtures.dart';

void main() {
  setUpAll(loadInterFont);
  for (final brightness in Brightness.values) {
    testWidgets('date helper at phone 1.8 $brightness', (t) async {
      usePhoneViewport(t);
      await existing.mountAssignmentEditor(
        t,
        scale: 1.8,
        brightness: brightness,
      );
      await t.ensureVisible(find.text('Enter date as YYYY-MM-DD'));
      await t.pumpAndSettle();
      expectRenderedInFull(t, find.text('Duty date'));
      expectRenderedInFull(t, find.text('Enter date as YYYY-MM-DD'));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('date helper at phone 1.0 light smoke', (t) async {
    usePhoneViewport(t);
    await existing.mountAssignmentEditor(
      t,
      scale: 1,
      brightness: Brightness.light,
    );
    await t.ensureVisible(find.text('Enter date as YYYY-MM-DD'));
    await t.pumpAndSettle();
    expectRenderedInFull(t, find.text('Enter date as YYYY-MM-DD'));
    expect(t.takeException(), isNull);
  });
}
