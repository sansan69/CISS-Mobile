import 'package:ciss_mobile/app/theme/app_theme.dart';
import 'package:ciss_mobile/core/cache/preload_controller.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/dev/mock_data.dart';
import 'package:ciss_mobile/dev/preview_safety.dart';
import 'package:ciss_mobile/features/field_officer/field_officer_tab_provider.dart';
import 'package:ciss_mobile/features/field_officer/presentation/field_officer_shell.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_dashboard_screen.dart';
import 'package:ciss_mobile/features/shared/notification_inbox_screen.dart';
import 'package:ciss_mobile/core/fcm/notification_service.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_attendance_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_duties_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_guards_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_reports_screen.dart';
import 'package:ciss_mobile/shared/widgets/floating_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'dart:ui' show BoxHeightStyle;
import 'support/guard_redesign_fixtures.dart' show loadInterFont;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    await loadInterFont();
  });

  testWidgets('five primary destinations route to existing FO screens', (
    tester,
  ) async {
    await _mountShell(tester);

    await tester.tap(find.text('Attendance').last);
    await tester.pumpAndSettle();
    expect(find.byType(FieldOfficerGuardAttendanceScreen), findsOneWidget);

    await tester.tap(find.text('Employees').last);
    await tester.pumpAndSettle();
    expect(find.byType(FieldOfficerGuardsScreen), findsOneWidget);

    await tester.tap(find.text('Duties').last);
    await tester.pumpAndSettle();
    expect(find.byType(FieldOfficerDutiesScreen), findsOneWidget);

    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    final reportTile = find.descendant(
      of: find.byType(FieldOfficerMoreScreen),
      matching: find.text('Reports'),
    );
    await tester.ensureVisible(reportTile);
    await tester.pumpAndSettle();
    await tester.tap(reportTile);
    await tester.pumpAndSettle();
    expect(find.byType(FieldOfficerReportsScreen), findsOneWidget);

    // Reports retains More's selected appearance, but More remains actionable.
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    expect(find.byType(FieldOfficerMoreScreen), findsOneWidget);
    expect(find.byType(FieldOfficerReportsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard Employee Directory quick action opens Employees tab', (
    tester,
  ) async {
    await _mountShell(tester);
    final dashboard = find.byType(FieldOfficerDashboardScreen);
    final directoryAction = find.descendant(
      of: dashboard,
      matching: find.text('Employee Directory'),
    );
    await tester.ensureVisible(directoryAction);
    await tester.tap(directoryAction);
    await tester.pumpAndSettle();
    expect(find.byType(FieldOfficerGuardsScreen), findsOneWidget);
    expect(find.text('Employees assigned to your districts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android back from Reports returns to More', (tester) async {
    await _mountShell(tester, initialTab: fieldOfficerReportsTabIndex);
    expect(find.byType(FieldOfficerReportsScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(FieldOfficerMoreScreen), findsOneWidget);
    expect(find.byType(FieldOfficerReportsScreen), findsNothing);
  });

  testWidgets('inbox notification kinds target reordered FO destinations', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        NotificationService.notificationsProvider.overrideWith(
          (ref) => const AsyncData([
            {
              'id': 'work',
              'type': 'work_order',
              'title': 'Work order',
              'read': true,
            },
            {'id': 'duty', 'type': 'duty', 'title': 'Duty', 'read': true},
            {
              'id': 'attendance',
              'type': 'attendance_marked',
              'title': 'Attendance',
              'read': true,
            },
            {
              'id': 'report',
              'type': 'report_review',
              'title': 'Report',
              'read': true,
            },
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed:
                        () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const NotificationInboxScreen(),
                          ),
                        ),
                    child: const Text('Open inbox'),
                  ),
            ),
          ),
        ),
      ),
    );

    for (final entry in [
      ('Work order', fieldOfficerDutiesTabIndex),
      ('Duty', fieldOfficerDutiesTabIndex),
      ('Attendance', fieldOfficerAttendanceTabIndex),
      ('Report', fieldOfficerReportsTabIndex),
    ]) {
      await tester.tap(find.text('Open inbox'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.$1));
      await tester.pumpAndSettle();
      expect(container.read(fieldOfficerTabIndexProvider), entry.$2);
    }
  });

  for (final width in [320.0, 411.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('nav labels fit at ${width}dp and ${scale}x', (tester) async {
        await _mountNavOnly(tester, width: width, textScale: scale);

        final paragraphs = tester.widgetList<RichText>(
          find.descendant(
            of: find.byType(FloatingNavBar),
            matching: find.byWidgetPredicate(
              (widget) => widget is RichText && widget.maxLines == 1,
            ),
          ),
        );
        expect(paragraphs, hasLength(5));
        for (final paragraph in paragraphs) {
          final render = tester.renderObject<RenderParagraph>(
            find.byWidget(paragraph),
          );
          expect(
            render.didExceedMaxLines,
            isFalse,
            reason: paragraph.text.toPlainText(),
          );
          expect(
            render.size.width,
            greaterThanOrEqualTo(render.getMaxIntrinsicWidth(double.infinity)),
            reason: paragraph.text.toPlainText(),
          );
          final barRect = tester.getRect(find.byType(ClipRRect));
          final boxes = render.getBoxesForSelection(
            TextSelection(
              baseOffset: 0,
              extentOffset: paragraph.text.toPlainText().length,
            ),
            boxHeightStyle: BoxHeightStyle.tight,
          );
          final radius =
              tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius
                  as BorderRadius;
          for (final box in boxes) {
            final paintRect = box.toRect().shift(
              render.localToGlobal(Offset.zero),
            );
            for (final corner in <Offset>[
              paintRect.topLeft,
              paintRect.topRight,
              paintRect.bottomLeft,
              paintRect.bottomRight,
            ]) {
              expect(
                _insideRoundedRect(corner, barRect, radius.topLeft.x),
                isTrue,
                reason:
                    '${paragraph.text.toPlainText()} at $corner in $barRect radius ${radius.topLeft.x}',
              );
            }
          }
        }

        final nav = find.byType(FloatingNavBar);
        expect(tester.getSize(nav).width, closeTo(width, 0.1));
        final navItems = tester.widget<FloatingNavBar>(nav).items;
        expect(navItems[1].semanticLabel, 'Attendance Records');
        expect(navItems[2].semanticLabel, 'Employee Directory');
        final row = find.descendant(
          of: nav,
          matching: find.byWidgetPredicate((widget) => widget is Row),
        );
        final itemWidth = tester.getSize(row).width / navItems.length;
        expect(itemWidth, greaterThanOrEqualTo(44));
        expect(tester.getSize(row).height, greaterThanOrEqualTo(44));
        final compact = width < 360 || scale > 1.3;
        for (final label in [
          'Home',
          compact ? 'Logs' : 'Attendance',
          compact ? 'Staff' : 'Employees',
          compact ? 'Duty' : 'Duties',
          'More',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Future<void> _mountNavOnly(
  WidgetTester tester, {
  required double width,
  required double textScale,
}) async {
  _configureViewport(tester, width, textScale);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCissTheme(Brightness.light),
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: SizedBox(
          height: 130,
          child: FloatingNavBar(
            cornerRadius: 16,
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              FloatingNavItem(icon: Icons.home_outlined, label: 'Home'),
              FloatingNavItem(
                icon: Icons.fact_check_outlined,
                label: 'Attendance',
                compactLabel: 'Logs',
                semanticLabel: 'Attendance Records',
              ),
              FloatingNavItem(
                icon: Icons.groups_2_outlined,
                label: 'Employees',
                compactLabel: 'Staff',
                semanticLabel: 'Employee Directory',
              ),
              FloatingNavItem(
                icon: Icons.assignment_turned_in_outlined,
                label: 'Duties',
                compactLabel: 'Duty',
              ),
              FloatingNavItem(icon: Icons.grid_view_outlined, label: 'More'),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _insideRoundedRect(Offset point, Rect rect, double radius) {
  if (!rect.contains(point)) return false;
  final nearestX = point.dx.clamp(rect.left + radius, rect.right - radius);
  final nearestY = point.dy.clamp(rect.top + radius, rect.bottom - radius);
  final dx = point.dx - nearestX;
  final dy = point.dy - nearestY;
  return dx * dx + dy * dy <= radius * radius;
}

Future<void> _mountShell(
  WidgetTester tester, {
  int initialTab = fieldOfficerHomeTabIndex,
}) async {
  _configureViewport(tester, 411, 1);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...previewSafetyOverrides(),
        preloadControllerProvider.overrideWith((ref) => _NoopPreload()),
        mobileRepositoryProvider.overrideWithValue(
          ReadOnlyDutyPreviewRepository(),
        ),
        fieldOfficerDashboardProvider.overrideWith(
          (ref) async => mockFieldOfficerDashboard,
        ),
        fieldOfficerGuardsProvider.overrideWith(
          (ref) async => mockFieldOfficerGuards,
        ),
        fieldOfficerGuardAttendanceProvider.overrideWith(
          (ref) async => mockFieldOfficerAttendance,
        ),
        fieldOfficerGuardAttendanceHistoryProvider.overrideWith(
          (ref) async => mockFieldOfficerAttendance,
        ),
        fieldOfficerAttendanceSitesProvider.overrideWith(
          (ref) async => const [],
        ),
        fieldOfficerVisitReportsProvider.overrideWith(
          (ref) async => mockVisitReports,
        ),
        fieldOfficerTrainingReportsProvider.overrideWith(
          (ref) async => mockTrainingReports,
        ),
        fieldOfficerTabIndexProvider.overrideWith((ref) => initialTab),
      ],
      child: MaterialApp(
        theme: buildCissTheme(Brightness.light),
        home: const FieldOfficerShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _configureViewport(WidgetTester tester, double width, double textScale) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 850);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

class _NoopPreload implements PreloadController {
  @override
  void preloadAllGuard() {}

  @override
  void preloadAllFieldOfficer() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
