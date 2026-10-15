import 'package:ciss_mobile/core/models/duty_models.dart';
import 'package:ciss_mobile/core/models/guard_profile.dart';
import 'package:ciss_mobile/core/models/attendance_models.dart';
import 'package:ciss_mobile/core/models/mobile_dashboard_models.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_assignments_screen.dart';
import 'package:ciss_mobile/features/guard/application/duty_willingness_controller.dart';
import 'package:ciss_mobile/features/guard/presentation/widgets/duty_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/guard_redesign_fixtures.dart';

/// Regression for the root device QA finding: at 1.8 text scale the selected
/// "Regular" value in the assignment editor was clipped vertically.
///
/// `DropdownButtonFormField` defaults to `isDense: true`, whose collapsed
/// button height is clamped to the *scaled font size* rather than the line
/// height. From any text scale above 1.0 the value's line box is therefore
/// taller than the button and the glyphs are cut off.
void expectValueLineFits(WidgetTester tester, Finder valueText) {
  final paragraph = tester.renderObject<RenderParagraph>(valueText);
  final lineHeight = paragraph.getMinIntrinsicHeight(paragraph.size.width);
  expect(
    paragraph.size.height,
    greaterThanOrEqualTo(lineHeight - 0.5),
    reason:
        'Selected value "${paragraph.text.toPlainText()}" is '
        '${paragraph.size.height} tall but its line needs $lineHeight — '
        'the field clips the text.',
  );
}

class SchedulingRepository extends NoNetworkRepository {
  @override
  Future<List<GuardAssignment>> fetchGuardAssignments({
    String? from,
    String? to,
  }) async => <GuardAssignment>[];

  @override
  Future<List<FieldOfficerSiteOption>> fetchFieldOfficerSites({
    String? district,
  }) async => <FieldOfficerSiteOption>[
    const FieldOfficerSiteOption(
      id: 's1',
      siteName: 'Government Examination Campus Ernakulam',
      district: 'Ernakulam',
      clientName: 'Other client',
      clientId: 'c1',
      shiftTemplates: <ShiftTemplateModel>[
        ShiftTemplateModel(
          code: 'N',
          label: 'Night duty',
          startTime: '22:00',
          endTime: '06:00',
        ),
      ],
    ),
  ];

  @override
  Future<List<GuardProfileModel>> fetchFieldOfficerGuards({
    String? district,
    bool includeInactive = false,
  }) async => <GuardProfileModel>[
    GuardProfileModel.fromJson(<String, dynamic>{
      'name': 'Guard a',
      'clientName': 'TCS',
      'tcsCategory': 'permanent',
      'status': 'Active',
    }, id: 'employee-doc-a'),
  ];
}

/// The two sites the preview fixtures expose, including the long
/// "site name · district" label the device QA pass saw ellipsized.
class PreviewSiteRepository extends NoNetworkRepository {
  @override
  Future<List<GuardAssignment>> fetchGuardAssignments({
    String? from,
    String? to,
  }) async => <GuardAssignment>[];

  @override
  Future<List<FieldOfficerSiteOption>> fetchFieldOfficerSites({
    String? district,
  }) async => <FieldOfficerSiteOption>[
    const FieldOfficerSiteOption(
      id: 'site_preview',
      siteName: 'District examination centre',
      district: 'Thiruvananthapuram',
      clientName: 'TCS',
      clientId: 'client_preview',
    ),
    const FieldOfficerSiteOption(
      id: 'site_custom_preview',
      siteName: 'Community centre',
      district: 'Thiruvananthapuram',
      clientName: 'Other client',
      clientId: 'client_other',
    ),
  ];

  @override
  Future<List<GuardProfileModel>> fetchFieldOfficerGuards({
    String? district,
    bool includeInactive = false,
  }) async => <GuardProfileModel>[];
}

GuardDuty examDuty() => GuardDuty.fromJson(<String, dynamic>{
  'id': 'exam-1',
  'kind': 'exam',
  'status': 'open',
  'workOrderId': 'exam-1',
  'siteName': 'District examination centre',
  'date': '2026-10-20',
  'willingness': 'willing',
  'canRespond': true,
  'willingnessVersion': 1,
});

Future<void> mountAssignmentEditor(
  WidgetTester tester, {
  required double scale,
  required Brightness brightness,
}) async {
  await tester.pumpWidget(
    guardTestApp(
      screen: const FieldOfficerAssignmentsScreen(),
      scale: scale,
      brightness: brightness,
      overrides: <Override>[
        mobileRepositoryProvider.overrideWithValue(SchedulingRepository()),
      ],
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Schedule duty'));
  await tester.pumpAndSettle();
}

Future<void> mountWillingnessDetail(
  WidgetTester tester, {
  required double scale,
  required Brightness brightness,
}) async {
  await tester.pumpWidget(
    guardTestApp(
      screen: Scaffold(body: DutyDetailSheet(duty: examDuty())),
      scale: scale,
      brightness: brightness,
      overrides: <Override>[
        guardDutiesProvider.overrideWith(
          (ref) async => <GuardDuty>[examDuty()],
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadInterFont);

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(360, 800);
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  for (final scale in <double>[1.0, 1.8]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'assignment editor selected values keep their line height at ${scale}x $brightness',
        (tester) async {
          await mountAssignmentEditor(
            tester,
            scale: scale,
            brightness: brightness,
          );

          expectValueLineFits(tester, find.text('Regular'));

          final siteField = find.byType(DropdownButtonFormField<String>).first;
          await tester.ensureVisible(siteField);
          await tester.pumpAndSettle();
          await tester.tap(siteField);
          await tester.pumpAndSettle();
          await tester.tap(
            find
                .text('Government Examination Campus Ernakulam · Ernakulam')
                .last,
          );
          await tester.pumpAndSettle();
          expectValueLineFits(
            tester,
            find
                .text('Government Examination Campus Ernakulam · Ernakulam')
                .first,
          );

          final shiftField = find.byType(DropdownButtonFormField<String>).last;
          await tester.ensureVisible(shiftField);
          await tester.pumpAndSettle();
          await tester.tap(shiftField);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Night duty · 22:00–06:00').last);
          await tester.pumpAndSettle();
          expectValueLineFits(
            tester,
            find.text('Night duty · 22:00–06:00').first,
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'willingness response value keeps its line height at ${scale}x $brightness',
        (tester) async {
          await mountWillingnessDetail(
            tester,
            scale: scale,
            brightness: brightness,
          );
          await tester.ensureVisible(
            find.byType(DropdownButtonFormField<WillingnessStatus>),
          );
          await tester.pumpAndSettle();
          expectValueLineFits(tester, find.text('Willing').first);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  // Device QA at 1.8 text: the site field showed "District examination…" and
  // its menu "Community centre · Thir…", so the district was invisible.
  group('site value and menu keep the district at 1.8 text', () {
    testWidgets(
      'assignment editor site field shows the full site and district',
      (tester) async {
        await tester.pumpWidget(
          guardTestApp(
            screen: const FieldOfficerAssignmentsScreen(),
            scale: 1.8,
            overrides: <Override>[
              mobileRepositoryProvider.overrideWithValue(
                PreviewSiteRepository(),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Schedule duty'));
        await tester.pumpAndSettle();

        final siteField = find.byType(DropdownButtonFormField<String>).first;
        await tester.ensureVisible(siteField);
        await tester.pumpAndSettle();
        await tester.tap(siteField);
        await tester.pumpAndSettle();

        // Menu entries.
        expectRenderedInFull(
          tester,
          find.text('District examination centre · Thiruvananthapuram').last,
        );
        expectRenderedInFull(
          tester,
          find.text('Community centre · Thiruvananthapuram').last,
        );

        await tester.tap(
          find.text('District examination centre · Thiruvananthapuram').last,
        );
        await tester.pumpAndSettle();

        // Collapsed selected value.
        expectRenderedInFull(
          tester,
          find.text('District examination centre · Thiruvananthapuram').first,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
