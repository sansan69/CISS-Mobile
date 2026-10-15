import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ciss_mobile/core/models/duty_models.dart';
import 'package:ciss_mobile/core/settings/remote_config_provider.dart';
import 'package:ciss_mobile/core/offline/willingness_queue.dart';
import 'package:ciss_mobile/core/models/guard_profile.dart';
import 'package:ciss_mobile/features/guard/application/duty_willingness_controller.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_duties_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_dashboard_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_profile_screen.dart';
import 'package:ciss_mobile/dev/preview_safety.dart';
import 'support/guard_redesign_fixtures.dart';

GuardDuty exam({bool open = true}) => GuardDuty.fromJson({
  'id': 'exam-1',
  'kind': 'exam',
  'status': open ? 'open' : 'cancelled',
  'workOrderId': 'exam-1',
  'siteName': 'District examination centre',
  'examName': 'Graduate examination',
  'date': '2026-10-20',
  'canRespond': open,
  'respondBy': '2026-10-19T18:30:00Z',
  'maleGuardsRequired': 2,
  'femaleGuardsRequired': 1,
});
WillingnessOperation localResponse(String state, {String? reason}) =>
    WillingnessOperation(
      id: 'uuid-1',
      ownerUid: 'auth-a',
      apiBaseUrl: 'https://a.invalid',
      workOrderId: 'exam-1',
      response: WillingnessStatus.willing,
      expectedVersion: 1,
      state: state,
      attempted: true,
      reason: reason,
    );
void main() {
  setUpAll(loadInterFont);
  testWidgets('Home shows one available exam prompt and category', (
    tester,
  ) async {
    await tester.pumpWidget(
      guardTestApp(
        screen: const GuardDashboardScreen(),
        overrides: [
          ...previewSafetyOverrides(),
          guardDashboardProvider.overrideWith(
            (ref) async => dashboardFixture(),
          ),
          guardDutiesProvider.overrideWith((ref) async => [exam()]),
          guardProfileProvider.overrideWith(
            (ref) async => GuardProfileModel.fromJson({
              'clientName': 'TCS',
              'tcsCategory': 'adhoc',
            }),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Exam duty available'), findsOneWidget);
    expect(find.text('Adhoc'), findsOneWidget);
    expect(find.text('Mark attendance'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'eligible exam detail explains interest and honest shift ${dark ? 'dark' : 'light'}',
      (tester) async {
        await tester.pumpWidget(
          guardTestApp(
            screen: const GuardDutiesScreen(),
            brightness: dark ? Brightness.dark : Brightness.light,
            overrides: [
              ...previewSafetyOverrides(),
              guardDutiesProvider.overrideWith((ref) async => [exam()]),
              guardProfileProvider.overrideWith(
                (ref) async => GuardProfileModel.fromJson({
                  'clientName': 'TCS',
                  'tcsCategory': 'adhoc',
                }),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('District examination centre'), findsOneWidget);
        await tester.tap(find.text('District examination centre'));
        await tester.pumpAndSettle();
        expect(find.text('Shift to be confirmed'), findsOneWidget);
        expect(find.text('This does not confirm assignment.'), findsOneWidget);
        expect(find.text('Save response'), findsOneWidget);
        expect(find.text('2 male · 1 female required'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('cancelled duty is read only and attendance remains explained', (
    tester,
  ) async {
    await tester.pumpWidget(
      guardTestApp(
        screen: const GuardDutiesScreen(),
        overrides: [
          ...previewSafetyOverrides(),
          guardDutiesProvider.overrideWith((ref) async => [exam(open: false)]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'), findsOneWidget);
    await tester.tap(find.text('District examination centre'));
    await tester.pumpAndSettle();
    expect(find.text('Save response'), findsNothing);
  });
  testWidgets('feed works independently of a failing profile', (tester) async {
    await tester.pumpWidget(
      guardTestApp(
        screen: const GuardDutiesScreen(),
        overrides: [
          ...previewSafetyOverrides(),
          guardDutiesProvider.overrideWith((ref) async => [exam(open: false)]),
          guardProfileProvider.overrideWith(
            (ref) async => throw StateError('profile unavailable'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('District examination centre'), findsOneWidget);
  });
  testWidgets(
    'workOrders off removes responses but keeps attendance independent',
    (tester) async {
      await tester.pumpWidget(
        guardTestApp(
          screen: const GuardDutiesScreen(),
          overrides: [
            ...previewSafetyOverrides(),
            guardDutiesProvider.overrideWith((ref) async => [exam()]),
            remoteConfigProvider.overrideWith(
              () => FixedConfig({'workOrders': false}),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('District examination centre'));
      await tester.pumpAndSettle();
      expect(find.text('Save response'), findsNothing);
      expect(find.textContaining('Attendance'), findsWidgets);
    },
  );

  testWidgets('pending response is readable and never claims saved', (
    tester,
  ) async {
    await tester.pumpWidget(
      guardTestApp(
        screen: const GuardDutiesScreen(),
        overrides: [
          ...previewSafetyOverrides(),
          guardDutiesProvider.overrideWith((ref) async => [exam()]),
          guardProfileProvider.overrideWith(
            (ref) async => GuardProfileModel.fromJson({
              'clientName': 'TCS',
              'tcsCategory': 'adhoc',
            }),
          ),
          dutyResponseProvider.overrideWith(
            (ref, id) => localResponse('pending'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pending — not yet saved'), findsOneWidget);
    expect(find.textContaining('Response saved'), findsNothing);
    await tester.tap(find.text('District examination centre'));
    await tester.pumpAndSettle();
    expect(
      find.text('Pending — your response is not yet saved.'),
      findsOneWidget,
    );
    expect(find.textContaining('Response saved:'), findsNothing);
  });

  testWidgets(
    'rejected response shows the server reason with refresh available',
    (tester) async {
      await tester.pumpWidget(
        guardTestApp(
          screen: const GuardDutiesScreen(),
          overrides: [
            ...previewSafetyOverrides(),
            guardDutiesProvider.overrideWith((ref) async => [exam()]),
            guardProfileProvider.overrideWith(
              (ref) async => GuardProfileModel.fromJson({
                'clientName': 'TCS',
                'tcsCategory': 'adhoc',
              }),
            ),
            dutyResponseProvider.overrideWith(
              (ref, id) => localResponse('rejected', reason: 'Duty closed'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Response not sent:'), findsOneWidget);
      await tester.tap(find.text('District examination centre'));
      await tester.pumpAndSettle();
      expect(find.text('Response not sent: Duty closed'), findsOneWidget);
      expect(find.text('Refresh duty details'), findsOneWidget);
      expect(find.textContaining('Response saved:'), findsNothing);
    },
  );

  testWidgets(
    'unset category explains the block while assignments stay readable',
    (tester) async {
      await tester.pumpWidget(
        guardTestApp(
          screen: const GuardDutiesScreen(),
          overrides: [
            ...previewSafetyOverrides(),
            guardDutiesProvider.overrideWith((ref) async => [exam()]),
            guardProfileProvider.overrideWith(
              (ref) async => GuardProfileModel.fromJson({'clientName': 'TCS'}),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Category not set'), findsOneWidget);
      expect(
        find.text(
          'Your category must be set by an administrator before you can respond to exam duties.',
        ),
        findsOneWidget,
      );
      expect(find.text('District examination centre'), findsOneWidget);
    },
  );

  // Device QA reported further large-text overflows on visited screens that were
  // not attributed to a specific surface: the guard duties feed and its detail
  // sheet are two of the surfaces this workstream owns.
  testWidgets('guard duties feed and detail hold at 1.8 text', (tester) async {
    await tester.pumpWidget(
      guardTestApp(
        screen: const GuardDutiesScreen(),
        scale: 1.8,
        overrides: [
          ...previewSafetyOverrides(),
          guardDutiesProvider.overrideWith((ref) async => [exam()]),
          guardProfileProvider.overrideWith(
            (ref) async => GuardProfileModel.fromJson({
              'clientName': 'TCS',
              'tcsCategory': 'adhoc',
            }),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('District examination centre'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Shift to be confirmed'), findsOneWidget);
    expect(find.text('Save response'), findsOneWidget);
    expect(find.text('This does not confirm assignment.'), findsOneWidget);
  });
}
