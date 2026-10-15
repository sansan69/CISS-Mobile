import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:ciss_mobile/app/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/app/motion.dart';
import 'package:ciss_mobile/core/haptics.dart';
import 'package:ciss_mobile/core/haptics/haptic_platform.dart';
import 'package:ciss_mobile/core/haptics/haptics_engine.dart';
import 'package:ciss_mobile/shared/widgets/action_row.dart';
import 'package:ciss_mobile/shared/widgets/floating_nav_bar.dart';
import 'package:ciss_mobile/shared/widgets/primary_action.dart';
import 'package:ciss_mobile/shared/widgets/pressable.dart';

import 'support/guard_redesign_fixtures.dart';

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

  group('interaction regressions', () {
    testWidgets('null callback has no scale feedback or haptic', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const PressableScale(child: Text('Disabled'))),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressableScale)),
      );
      await tester.pump(AppMotion.press);
      expect(_scaleOf(tester), 1);
      expect(platform.calls, isEmpty);
      await gesture.up();
    });

    testWidgets('cancel restores scale without activating', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(PressableScale(child: const Text('Tap'), onTap: () => taps++)),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressableScale)),
      );
      await tester.pump(AppMotion.press);
      expect(_scaleOf(tester), 0.97);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(_scaleOf(tester), 1);
      expect(taps, 0);
      expect(platform.calls, ['light']);
    });

    testWidgets('two rapid complete taps activate and pulse twice', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(PressableScale(child: const Text('Tap'), onTap: () => taps++)),
      );
      await tester.tap(find.byType(PressableScale));
      await tester.tap(find.byType(PressableScale));
      await tester.pumpAndSettle();
      expect(taps, 2);
      expect(platform.calls, ['light', 'light']);
      expect(_scaleOf(tester), 1);
    });

    testWidgets('reduce motion keeps press scale at one', (tester) async {
      await tester.pumpWidget(
        _host(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: PressableScale(child: const Text('Tap'), onTap: () {}),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressableScale)),
      );
      await tester.pump(AppMotion.press);
      expect(_scaleOf(tester), 1);
      expect(platform.calls, ['light']);
      await gesture.up();
    });

    testWidgets(
      'disabling during press clears feedback and cancels activation',
      (tester) async {
        var enabled = true;
        var taps = 0;
        late StateSetter update;
        await tester.pumpWidget(
          _host(
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return PressableScale(
                  onTap: enabled ? () => taps++ : null,
                  child: const Text('Tap'),
                );
              },
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(PressableScale)),
        );
        await tester.pump(AppMotion.press);
        expect(_scaleOf(tester), 0.97);
        update(() => enabled = false);
        await tester.pump();
        expect(_scaleOf(tester), 1);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(taps, 0);
        expect(platform.calls, ['light']);
      },
    );
  });

  group('accessible actions', () {
    for (final primary in [true, false]) {
      for (final enabled in [true, false]) {
        testWidgets(
          '${primary ? 'primary' : 'row'} has one label and ${enabled ? 'one action' : 'no action'}',
          (tester) async {
            final semantics = tester.ensureSemantics();

            var taps = 0;
            final action =
                primary
                    ? PrimaryAction(
                      icon: Icons.check,
                      label: 'Attendance',
                      sublabel: 'Today',
                      enabled: enabled,
                      onTap: () => taps++,
                    )
                    : ActionRow(
                      icon: Icons.check,
                      label: 'Attendance',
                      trailing: 'Today',
                      onTap: enabled ? () => taps++ : null,
                    );
            await tester.pumpWidget(_host(action));
            final node = tester.getSemantics(
              find.byType(primary ? PrimaryAction : ActionRow),
            );
            expect(node.getSemanticsData().label, 'Attendance, Today');
            expect(
              node.getSemanticsData().hasFlag(SemanticsFlag.isButton),
              isTrue,
            );
            expect(
              node.getSemanticsData().hasFlag(SemanticsFlag.hasEnabledState),
              isTrue,
            );
            expect(
              node.getSemanticsData().hasFlag(SemanticsFlag.isEnabled),
              enabled,
            );
            expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap),
              enabled,
            );
            if (enabled) {
              tester.binding.performSemanticsAction(
                SemanticsActionEvent(
                  type: SemanticsAction.tap,
                  viewId: tester.view.viewId,
                  nodeId: node.id,
                ),
              );
              await tester.pump();
              expect(taps, 1);
              expect(platform.calls, [primary ? 'medium' : 'light']);
            }
            semantics.dispose();
          },
        );
      }
    }

    testWidgets('disabled row ignores physical press', (tester) async {
      await tester.pumpWidget(
        _host(const ActionRow(icon: Icons.check, label: 'Disabled')),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ActionRow)),
      );
      await tester.pump(AppMotion.press);
      expect(platform.calls, isEmpty);
      expect(_scaleOf(tester), 1);
      await gesture.up();
    });

    testWidgets('row uses a highlight without scaling', (tester) async {
      await tester.pumpWidget(
        _host(ActionRow(icon: Icons.check, label: 'Open', onTap: () {})),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ActionRow)),
      );
      await tester.pump(AppMotion.press);
      expect(_scaleOf(tester), 1);
      final highlights = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(
        highlights.any(
          (container) =>
              (container.decoration as BoxDecoration?)?.color != null &&
              (container.decoration as BoxDecoration).color!.a > 0,
        ),
        isTrue,
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('theme and layout', () {
    for (final brightness in Brightness.values) {
      testWidgets('$brightness long metadata fits narrow large-text layout', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCissTheme(brightness),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(2),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PrimaryAction(
                            icon: Icons.check,
                            label: 'Mark attendance for the current duty',
                            sublabel: 'Long detailed attendance instructions',
                            onTap: () {},
                          ),
                          ActionRow(
                            icon: Icons.check,
                            label: 'Payslips and documents',
                            trailing:
                                'Extremely long district and month metadata',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final layoutError = tester.takeException();
        expect(layoutError, isNull);
        expect(
          tester.getSize(find.byType(PrimaryAction)).height,
          greaterThanOrEqualTo(56),
        );
        expect(
          tester.getSize(find.byType(ActionRow)).height,
          greaterThanOrEqualTo(56),
        );
      });

      testWidgets(
        '$brightness primary text and icon have accessible contrast',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildCissTheme(brightness),
              home: Scaffold(
                body: PrimaryAction(
                  icon: Icons.check,
                  label: 'Attendance',
                  sublabel: 'Today',
                  onTap: () {},
                ),
              ),
            ),
          );
          final fill =
              tester
                  .widgetList<Container>(
                    find.descendant(
                      of: find.byType(PrimaryAction),
                      matching: find.byType(Container),
                    ),
                  )
                  .map((container) => container.decoration)
                  .whereType<BoxDecoration>()
                  .first
                  .color!;
          final colors = [
            tester.widget<Text>(find.text('Attendance')).style!.color!,
            tester.widget<Text>(find.text('Today')).style!.color!,
            tester.widget<Icon>(find.byIcon(Icons.check)).color!,
          ];
          for (final color in colors) {
            final visible = Color.alphaBlend(color, fill);
            final a = visible.computeLuminance();
            final b = fill.computeLuminance();
            final ratio =
                (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05);
            expect(ratio, greaterThanOrEqualTo(4.5));
          }
        },
      );
    }
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
            label: 'Payslips',
            trailing: 'March',
            onTap: () => taps++,
          ),
        ),
      );

      expect(find.text('Payslips'), findsOneWidget);
      expect(find.text('March'), findsOneWidget);

      await tester.tap(find.byType(ActionRow));
      await tester.pump();

      expect(taps, 1);
      expect(platform.calls, ['light']);
    });
  });

  // Device QA at TextScaler 1.8 reported a 5.0 px bottom RenderFlex overflow
  // from the floating nav bar's icon/label Column, and primary-action labels
  // cut to "Create assignme…" / "Scan the duty QR at you…".
  group('large text', () {
    setUpAll(loadInterFont);

    Widget navBarHost(double scale) => MaterialApp(
      theme: buildCissTheme(Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 800),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: Stack(
            children: <Widget>[
              FloatingNavBar(
                currentIndex: 0,
                onTap: (_) {},
                items: const <FloatingNavItem>[
                  FloatingNavItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home_rounded,
                    label: 'Home',
                  ),
                  FloatingNavItem(
                    icon: Icons.assignment_turned_in_outlined,
                    label: 'Duty',
                  ),
                  FloatingNavItem(icon: Icons.star_border, label: 'Activity'),
                  FloatingNavItem(icon: Icons.person_outline, label: 'Profile'),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    double navBarHeight(WidgetTester tester) =>
        tester.getSize(find.byType(ClipRRect)).height;

    testWidgets('floating nav bar keeps its 66 px bar at 1.0 text', (
      tester,
    ) async {
      await tester.pumpWidget(navBarHost(1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(navBarHeight(tester), 66);
    });

    testWidgets('floating nav bar grows instead of overflowing at 1.8 text', (
      tester,
    ) async {
      await tester.pumpWidget(navBarHost(1.8));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(navBarHeight(tester), greaterThan(66));
    });

    testWidgets('primary action wraps its label and sublabel at 1.8 text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCissTheme(Brightness.light),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 312,
                  child: PrimaryAction(
                    icon: Icons.check_circle_rounded,
                    label: 'Create assignments',
                    sublabel: 'Scan the duty QR at your post',
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectRenderedInFull(tester, find.text('Create assignments'));
      expectRenderedInFull(tester, find.text('Scan the duty QR at your post'));
      expect(
        tester.getSize(find.byType(PrimaryAction)).height,
        greaterThanOrEqualTo(56),
      );
    });

    testWidgets('primary action stays one line per label at 1.0 text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCissTheme(Brightness.light),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 312,
                child: PrimaryAction(
                  icon: Icons.check_circle_rounded,
                  label: 'Create assignments',
                  sublabel: 'Scan the duty QR at your post',
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final finder in <Finder>[
        find.text('Create assignments'),
        find.text('Scan the duty QR at your post'),
      ]) {
        expect(renderedLineCount(tester, finder), 1);
      }
    });
  });
}
