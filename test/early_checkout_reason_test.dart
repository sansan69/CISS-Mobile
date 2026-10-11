import 'package:ciss_mobile/core/attendance/early_checkout.dart';
import 'package:ciss_mobile/core/models/attendance_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SheetHarness extends StatelessWidget {
  const _SheetHarness({required this.onResult});

  final void Function(String?) onResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder:
              (BuildContext inner) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await showEarlyCheckoutReasonSheet(inner);
                    onResult(result);
                  },
                  child: const Text('Open sheet'),
                ),
              ),
        ),
      ),
    );
  }
}

void main() {
  group('kEarlyCheckoutReasons', () {
    test('exposes the canonical preset reasons ending in Other', () {
      expect(kEarlyCheckoutReasons, contains('Personal emergency'));
      expect(kEarlyCheckoutReasons, contains('Shift relief arrived'));
      expect(kEarlyCheckoutReasons, contains('Supervisor instruction'));
      expect(kEarlyCheckoutReasons.last, kEarlyCheckoutReasonOther);
      expect(kEarlyCheckoutReasonOther, 'Other');
    });
  });

  group('showEarlyCheckoutReasonSheet', () {
    testWidgets('returns the tapped preset reason', (
      WidgetTester tester,
    ) async {
      String? result;
      bool completed = false;
      await tester.pumpWidget(
        _SheetHarness(
          onResult: (String? value) {
            result = value;
            completed = true;
          },
        ),
      );

      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Shift relief arrived'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(result, 'Shift relief arrived');
    });

    testWidgets('Other with free text returns the trimmed text', (
      WidgetTester tester,
    ) async {
      String? result;
      await tester.pumpWidget(_SheetHarness(onResult: (v) => result = v));

      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(kEarlyCheckoutReasonOther));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  Feeling unwell  ');
      await tester.tap(find.text('Submit reason'));
      await tester.pumpAndSettle();

      expect(result, 'Feeling unwell');
    });

    testWidgets('Other left blank returns null', (WidgetTester tester) async {
      String? result;
      await tester.pumpWidget(_SheetHarness(onResult: (v) => result = v));

      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(kEarlyCheckoutReasonOther));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit reason'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('isEarlyCheckoutForShift', () {
    const ShiftTemplateModel dayShift = ShiftTemplateModel(
      code: 'D',
      label: 'Day',
      startTime: '08:00',
      endTime: '20:00',
    );

    test('true before shift end', () {
      expect(
        isEarlyCheckoutForShift(dayShift, at: DateTime(2026, 1, 1, 15, 30)),
        isTrue,
      );
    });

    test('false after shift end', () {
      expect(
        isEarlyCheckoutForShift(dayShift, at: DateTime(2026, 1, 1, 20, 1)),
        isFalse,
      );
    });

    test('false for overnight shifts and null shift', () {
      const ShiftTemplateModel night = ShiftTemplateModel(
        code: 'N',
        label: 'Night',
        startTime: '20:00',
        endTime: '08:00',
      );
      expect(
        isEarlyCheckoutForShift(night, at: DateTime(2026, 1, 1, 3)),
        isFalse,
      );
      expect(
        isEarlyCheckoutForShift(null, at: DateTime(2026, 1, 1, 3)),
        isFalse,
      );
    });
  });
}
