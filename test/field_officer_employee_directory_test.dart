import 'package:ciss_mobile/app/theme/app_tokens.dart';
import 'package:ciss_mobile/core/models/guard_profile.dart';
import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_guards_screen.dart';
import 'package:ciss_mobile/shared/widgets/brand_banner.dart';
import 'package:ciss_mobile/shared/widgets/metric_card.dart';
import 'package:ciss_mobile/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/guard_redesign_fixtures.dart';

GuardProfileModel employee({
  required String name,
  required String client,
  required String status,
  String id = 'E-1',
  String? createdAt,
}) => GuardProfileModel(
  id: id,
  fullName: name,
  employeeId: id,
  clientName: client,
  district: 'Ernakulam',
  phoneNumber: '9876543210',
  status: status,
  createdAt: createdAt,
);

Future<void> pumpDirectory(
  WidgetTester tester, {
  required List<GuardProfileModel> employees,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    guardTestApp(
      screen: const FieldOfficerGuardsScreen(),
      role: AppRole.fieldOfficer,
      scale: scale,
      overrides: <Override>[
        fieldOfficerGuardsProvider.overrideWith((ref) async => employees),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadInterFont();
  });

  testWidgets('directory keeps one screen margin for header, metrics, fields', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 914);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      guardTestApp(
        screen: const FieldOfficerGuardsScreen(),
        role: AppRole.fieldOfficer,
        overrides: <Override>[
          fieldOfficerGuardsProvider.overrideWith(
            (ref) async => <GuardProfileModel>[
              employee(name: 'Asha Nair', client: 'Acme', status: 'Active'),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final margin = AppSpacing.md;
    final employeesCard = tester.getRect(
      find.ancestor(
        of: find.text('EMPLOYEES'),
        matching: find.byType(MetricCard),
      ),
    );
    final districtsCard = tester.getRect(
      find.ancestor(
        of: find.text('DISTRICTS'),
        matching: find.byType(MetricCard),
      ),
    );
    final searchField = tester.getRect(find.byType(TextField).first);
    final headerLogo = tester.getRect(find.byType(CissLogoBadge));

    expect(employeesCard.left, closeTo(margin, 0.5));
    expect(headerLogo.left, closeTo(margin, 0.5));
    expect(searchField.left, closeTo(margin, 0.5));
    expect(searchField.right, closeTo(411 - margin, 0.5));
    expect(districtsCard.right, closeTo(411 - margin, 0.5));
    expect(districtsCard.left, greaterThan(employeesCard.right));
  });

  testWidgets(
    'search and client/status filters intersect; reset restores all',
    (tester) async {
      await pumpDirectory(
        tester,
        employees: <GuardProfileModel>[
          employee(name: 'Asha Nair', client: 'Acme', status: 'Active'),
          employee(
            name: 'Asha Menon',
            client: 'Beta',
            status: 'Inactive',
            id: 'E-2',
          ),
          employee(
            name: 'Ravi Das',
            client: 'Acme',
            status: 'PendingReview',
            id: 'E-3',
          ),
        ],
      );

      expect(find.text('Employee Directory'), findsOneWidget);
      expect(find.text('Asha Nair'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Inactive'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Inactive'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Asha');
      await tester.pumpAndSettle();
      expect(find.text('Asha Nair'), findsOneWidget);
      expect(find.text('Asha Menon'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Active').last);
      await tester.pumpAndSettle();
      expect(find.text('Asha Nair'), findsOneWidget);
      expect(find.text('Asha Menon'), findsNothing);
      expect(find.text('Ravi Das'), findsNothing);

      await tester.tap(find.text('All').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acme').last);
      await tester.pumpAndSettle();
      expect(find.text('Asha Nair'), findsOneWidget);
      expect(find.text('Asha Menon'), findsNothing);
      expect(find.text('Ravi Das'), findsNothing);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Asha Nair'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Ravi Das'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ravi Das'), findsOneWidget);
    },
  );

  testWidgets('selected client survives refresh when absent from new roster', (
    tester,
  ) async {
    var employees = <GuardProfileModel>[
      employee(name: 'Asha Nair', client: 'Acme', status: 'Active'),
      employee(name: 'Ravi Das', client: 'Beta', status: 'Inactive', id: 'E-2'),
    ];
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          fieldOfficerGuardsProvider.overrideWith((ref) async => employees),
        ],
        child: MaterialApp(home: const FieldOfficerGuardsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('All').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acme').last);
    await tester.pumpAndSettle();
    expect(find.text('Asha Nair'), findsOneWidget);

    employees = <GuardProfileModel>[
      employee(name: 'Mina Roy', client: 'Gamma', status: 'Active', id: 'E-3'),
    ];
    final context = tester.element(find.byType(FieldOfficerGuardsScreen));
    ProviderScope.containerOf(context).invalidate(fieldOfficerGuardsProvider);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('0 of 1 employees'), findsOneWidget);
    expect(find.text('No matching employees'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Mina Roy'), findsOneWidget);
    expect(find.text('1 of 1 employees'), findsOneWidget);
  });

  testWidgets(
    'status filter shows non-active status tone and profile enrollment',
    (tester) async {
      await pumpDirectory(
        tester,
        employees: <GuardProfileModel>[
          employee(
            name: 'Ravi Das',
            client: 'Acme',
            status: 'PendingReview',
            createdAt: '2025-03-04T00:00:00Z',
          ),
        ],
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pending Review').last);
      await tester.pumpAndSettle();
      expect(find.text('Ravi Das'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is StatusChip && w.tone == StatusChipTone.warning,
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Ravi Das'));
      await tester.pumpAndSettle();
      expect(find.text('Employee profile'), findsOneWidget);
      expect(find.text('Enrollment date'), findsOneWidget);
    },
  );

  testWidgets('empty directory and 1.8 scale render without overflow', (
    tester,
  ) async {
    await pumpDirectory(
      tester,
      employees: const <GuardProfileModel>[],
      scale: 1.8,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Employee Directory'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('No employees found'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No employees found'), findsOneWidget);
  });

  testWidgets('large text directory content stays fully readable at 320dp', (
    tester,
  ) async {
    await pumpDirectory(
      tester,
      employees: <GuardProfileModel>[
        employee(
          name: 'Alexandria Montgomery-Smith',
          client: 'CISS Security Services',
          status: 'Active',
          id: 'EMPLOYEE-2026-001',
          createdAt: '2026-10-14T00:00:00Z',
        ),
        employee(
          name: 'Asha Nair',
          client: 'Acme',
          status: 'Active',
          id: 'E-2',
        ),
      ],
      scale: 1.8,
    );

    final title = find.text('Employee Directory');
    expect(title, findsOneWidget);
    expectRenderedInFull(tester, title);
    expect(find.text('CISS WORKFORCE'), findsOneWidget);
    expectRenderedInFull(tester, find.text('CISS WORKFORCE'));
    expectRenderedInFull(
      tester,
      find.text('Employees assigned to your districts'),
    );
    expect(find.text('2 of 2 employees'), findsOneWidget);

    final longName = find.text('Alexandria Montgomery-Smith');
    await tester.scrollUntilVisible(
      longName,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(longName, findsOneWidget);
    expectRenderedInFull(tester, longName);
    for (final text in <String>[
      'EMPLOYEE-2026-001',
      'CISS Security Services',
      '9876543210',
    ]) {
      final finder = find.text(text).first;
      await tester.scrollUntilVisible(
        finder,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expectRenderedInFull(tester, finder);
    }
    final phone = find.text('9876543210').first;
    expect(renderedLineCount(tester, phone), 1);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load failure offers retry', (tester) async {
    var attempts = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      guardTestApp(
        screen: const FieldOfficerGuardsScreen(),
        role: AppRole.fieldOfficer,
        overrides: <Override>[
          fieldOfficerGuardsProvider.overrideWith((ref) async {
            attempts++;
            if (attempts == 1) throw StateError('offline');
            return <GuardProfileModel>[];
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load employees'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No employees found'), findsOneWidget);
    expect(attempts, 2);
  });
}
