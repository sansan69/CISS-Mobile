import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/app/motion.dart';
import 'package:ciss_mobile/core/haptics.dart';
import 'package:ciss_mobile/core/haptics/haptic_platform.dart';
import 'package:ciss_mobile/core/haptics/haptics_engine.dart';
import 'package:ciss_mobile/shared/widgets/action_row.dart';
import 'package:ciss_mobile/shared/widgets/primary_action.dart';
import 'package:ciss_mobile/shared/widgets/pressable.dart';

class _RecordingPlatform implements HapticPlatform {
  final List<String> calls = [];

  @override
  Future<void> lightImpact() async => calls.add('light');

  @override
  Future<void> mediumImpact() async => calls.add('medium');

  @override
  Future<void> heavyImpact() async => calls.add('heavy');

  @override
  Future<void> selectionClick() async => calls.add('selection');

  @override
  Future<void> vibrate() async => calls.add('vibrate');
}

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

double _scaleOf(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

void main() {
  late _RecordingPlatform platform;
  late HapticsEngine previous;

  setUp(() {
    previous = Haptics.engine;
    platform = _RecordingPlatform();
    Haptics.engine = HapticsEngine(platform);
    Haptics.enabled = true;
  });

  tearDown(() {
    Haptics.engine = previous;
    Haptics.enabled = true;
  });

  group('PressableScale', () {
    testWidgets('scales on press-in and returns on release', (tester) async {
      await tester.pumpWidget(
        _host(PressableScale(child: const Text('Tap'), onTap: () {})),
      );

      expect(_scaleOf(tester), 1.0);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressableScale)),
      );
      await tester.pump(AppMotion.press);
      expect(_scaleOf(tester), 0.97);

      await gesture.up();
      await tester.pump();
      expect(_scaleOf(tester), 1.0);
    });

    testWidgets('fires exactly one haptic per press-in', (tester) async {
      await tester.pumpWidget(
        _host(PressableScale(child: const Text('Tap'), onTap: () {})),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressableScale)),
      );
      await tester.pump(AppMotion.press);
      await gesture.up();
      await tester.pump();

      expect(platform.calls, ['light']);
    });
  });

  group('PrimaryAction', () {
    testWidgets('invokes onTap and uses the medium haptic', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PrimaryAction(
            icon: Icons.check_circle_rounded,
            label: 'Mark Attendance',
            sublabel: 'Start your duty',
            onTap: () => taps++,
          ),
        ),
      );

      expect(find.text('Mark Attendance'), findsOneWidget);
      await tester.tap(find.byType(PrimaryAction));
      await tester.pump();

      expect(taps, 1);
      expect(platform.calls, ['medium']);
    });

    testWidgets('is inert when disabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PrimaryAction(
            icon: Icons.check_circle_rounded,
            label: 'Mark Attendance',
            onTap: () => taps++,
            enabled: false,
          ),
        ),
      );

      await tester.tap(find.byType(PrimaryAction), warnIfMissed: false);
      await tester.pump();

      expect(taps, 0);
      expect(platform.calls, isEmpty);
    });
  });

  group('ActionRow', () {
    testWidgets('renders label + trailing and taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          ActionRow(
            icon: Icons.receipt_long_rounded,
            label: 'Documents',
            trailing: 'March',
            onTap: () => taps++,
          ),
        ),
      );

      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('March'), findsOneWidget);

      await tester.tap(find.byType(ActionRow));
      await tester.pump();

      expect(taps, 1);
      expect(platform.calls, ['light']);
    });
  });
}
