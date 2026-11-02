import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/models/payslip_document.dart';
import 'package:ciss_mobile/core/network/api_client.dart';
import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/core/region/region_service.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_payslips_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final payslips = <PayslipDocumentModel>[
    PayslipDocumentModel(
      id: 'slip-1',
      period: '2026-09',
      fileName: 'CISS-Sep-2026.pdf',
      sizeBytes: 188416,
      createdAt: DateTime(2026, 10, 2),
    ),
    PayslipDocumentModel(
      id: 'slip-2',
      period: '2026-08',
      fileName: 'CISS-Aug-2026.pdf',
      sizeBytes: 512,
      createdAt: null,
    ),
  ];

  Future<void> pumpScreen(
    WidgetTester tester, {
    required _FakePayslipRepository repository,
    _RecordingDelivery? delivery,
  }) async {
    // Drive a real phone viewport: the shared guard loading skeleton has a
    // fixed-height column that overflows the 800x600 default test surface.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final seams = delivery ?? _RecordingDelivery();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          mobileRepositoryProvider.overrideWithValue(repository),
          payslipFileWriterProvider.overrideWithValue(seams.write),
          payslipFileOpenerProvider.overrideWithValue(seams.open),
          payslipFileSharerProvider.overrideWithValue(seams.share),
        ],
        child: const MaterialApp(home: GuardPayslipsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders each slip with period, size and upload date', (
    tester,
  ) async {
    final repository = _FakePayslipRepository(payslips: payslips);
    await pumpScreen(tester, repository: repository);

    expect(find.text('Salary Slips'), findsOneWidget);
    expect(find.text('2 slips'), findsOneWidget);
    expect(find.text('2026-09'), findsOneWidget);
    expect(find.text('2026-08'), findsOneWidget);
    expect(find.textContaining('184 KB'), findsOneWidget);
    expect(find.textContaining('Uploaded 2 Oct 2026'), findsOneWidget);
    // The slip without a createdAt keeps just its size.
    expect(find.text('512 B'), findsOneWidget);
    expect(find.text('PDF'), findsNWidgets(2));
    expect(repository.fetchCalls, 1);
  });

  testWidgets('tapping a slip downloads, saves and opens it once', (
    tester,
  ) async {
    final repository = _FakePayslipRepository(payslips: payslips);
    final delivery = _RecordingDelivery();
    await pumpScreen(tester, repository: repository, delivery: delivery);

    await tester.tap(find.text('2026-09'));
    await tester.pumpAndSettle();

    expect(repository.downloadedIds, <String>['slip-1']);
    expect(delivery.written, hasLength(1));
    expect(delivery.written.single.payslip.id, 'slip-1');
    expect(delivery.written.single.bytes, repository.pdfBytes);
    expect(delivery.openedPaths, <String>['/tmp/payslip/CISS-Sep-2026.pdf']);
    expect(delivery.shared, isEmpty, reason: 'a viewer handled the file');
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('falls back to the share sheet when no viewer opens the PDF', (
    tester,
  ) async {
    final repository = _FakePayslipRepository(payslips: payslips);
    final delivery = _RecordingDelivery(canOpen: false);
    await pumpScreen(tester, repository: repository, delivery: delivery);

    await tester.tap(find.text('2026-08'));
    await tester.pumpAndSettle();

    expect(repository.downloadedIds, <String>['slip-2']);
    expect(delivery.openedPaths, hasLength(1));
    expect(delivery.shared.single.id, 'slip-2');
  });

  testWidgets('shows a human message when the download is forbidden', (
    tester,
  ) async {
    final repository = _FakePayslipRepository(
      payslips: payslips,
      downloadError: _forbiddenError(),
    );
    await pumpScreen(tester, repository: repository);

    await tester.tap(find.text('2026-09'));
    await tester.pumpAndSettle();

    final snackBarText = tester.widget<Text>(
      find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)),
    );
    expect(
      snackBarText.data,
      'Access denied. You do not have permission for this action.',
    );
    expect(snackBarText.data, isNot(contains('/api/')));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows the empty state when nothing is published', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      repository: _FakePayslipRepository(
        payslips: const <PayslipDocumentModel>[],
      ),
    );

    expect(find.text('No salary slips yet'), findsOneWidget);
    expect(find.textContaining('Pull down to refresh'), findsOneWidget);
  });

  testWidgets('shows a retry state when the list request fails', (tester) async {
    final repository = _FakePayslipRepository(fetchError: StateError('boom'));
    await pumpScreen(tester, repository: repository);

    expect(find.text('Could not load salary slips'), findsWidgets);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('pull-to-refresh refetches the list', (tester) async {
    final repository = _FakePayslipRepository(payslips: payslips);
    await pumpScreen(tester, repository: repository);
    expect(repository.fetchCalls, 1);

    await tester.fling(find.text('2026-09'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(repository.fetchCalls, 2);
  });
}

Object _forbiddenError() => DioException(
  requestOptions: RequestOptions(path: '/api/guard/payslips/slip-1/payslip'),
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/api/guard/payslips/slip-1/payslip'),
    statusCode: 403,
  ),
);

class _RecordedWrite {
  const _RecordedWrite(this.payslip, this.bytes);

  final PayslipDocumentModel payslip;
  final Uint8List bytes;
}

/// Stand-in for the platform plugins: records what the screen asked for.
class _RecordingDelivery {
  _RecordingDelivery({this.canOpen = true});

  final bool canOpen;
  final List<_RecordedWrite> written = <_RecordedWrite>[];
  final List<String> openedPaths = <String>[];
  final List<PayslipDocumentModel> shared = <PayslipDocumentModel>[];

  Future<File> write(PayslipDocumentModel payslip, Uint8List bytes) async {
    written.add(_RecordedWrite(payslip, bytes));
    return File('/tmp/payslip/${payslip.safeFileName}');
  }

  Future<bool> open(File file) async {
    openedPaths.add(file.path);
    return canOpen;
  }

  Future<void> share(File file, PayslipDocumentModel payslip) async {
    shared.add(payslip);
  }
}

class _FakePayslipRepository extends MobileRepository {
  _FakePayslipRepository({this.payslips, this.fetchError, this.downloadError})
    : super(
        ApiClient(authTokenProvider: () async => 'token'),
        _FakeFirebaseAuth(),
        _FakeRegionService(),
        log: (_) {},
      );

  final List<PayslipDocumentModel>? payslips;
  final Object? fetchError;
  final Object? downloadError;
  final Uint8List pdfBytes = Uint8List.fromList(<int>[37, 80, 68, 70]);
  int fetchCalls = 0;
  final List<String> downloadedIds = <String>[];

  @override
  Future<List<PayslipDocumentModel>> fetchPayslips() async {
    fetchCalls += 1;
    if (fetchError != null) throw fetchError!;
    return payslips ?? const <PayslipDocumentModel>[];
  }

  @override
  Future<Uint8List> downloadPayslipPdf(String payslipId) async {
    downloadedIds.add(payslipId);
    if (downloadError != null) throw downloadError!;
    return pdfBytes;
  }
}

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeRegionService implements RegionService {
  @override
  RegionInfo? get activeRegion => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
