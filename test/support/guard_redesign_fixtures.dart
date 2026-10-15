import 'package:ciss_mobile/app/theme/app_theme.dart';
import 'package:ciss_mobile/core/fcm/notification_service.dart';
import 'package:ciss_mobile/core/models/mobile_dashboard_models.dart';
import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/core/models/auth_session.dart';
import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/core/settings/remote_config.dart';
import 'package:ciss_mobile/core/settings/remote_config_provider.dart';
import 'package:ciss_mobile/dev/mock_data.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled production Inter font so large-text wrapping assertions
/// measure the same metrics the device uses. Without it `flutter test` renders
/// with the wider test-only placeholder font, which wraps far earlier.
Future<void> loadInterFont() async {
  final font = FontLoader('Inter');
  for (final weight in <String>['Regular', 'Medium', 'SemiBold', 'Bold']) {
    font.addFont(rootBundle.load('assets/fonts/Inter-$weight.otf'));
  }
  await font.load();
}

/// Pins the widget-test surface to the phone geometry the device QA pass used
/// (360x800 logical px at dpr 1) so large-text wrapping matches the device
/// instead of the wider 800x600 default test surface.
void usePhoneViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(tester.view.reset);
}

/// Fails when the rendered paragraph was ellipsized or clipped, i.e. the user
/// cannot read the whole string at the current width/text scale.
void expectRenderedInFull(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final text = paragraph.text.toPlainText();
  expect(
    paragraph.didExceedMaxLines,
    isFalse,
    reason: '"$text" is ellipsized at the current width',
  );
  expect(
    paragraph.size.height,
    greaterThanOrEqualTo(paragraph.textSize.height - 0.5),
    reason:
        '"$text" is clipped: ${paragraph.size.height} px box for a '
        '${paragraph.textSize.height} px paragraph',
  );
  // A paragraph with no maxLines is clipped rather than ellipsized when its
  // box is narrower than the laid-out text (e.g. a fixed-height tab label).
  expect(
    paragraph.size.width,
    greaterThanOrEqualTo(paragraph.textSize.width - 0.5),
    reason:
        '"$text" is clipped: ${paragraph.size.width} px box for a '
        '${paragraph.textSize.width} px paragraph',
  );
}

/// Number of rendered text lines (one selection box per line).
int renderedLineCount(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final text = paragraph.text.toPlainText();
  return paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
      )
      .length;
}

class FixedConfig extends RemoteConfigNotifier {
  FixedConfig([this.modules = const <String, bool>{}]);
  final Map<String, bool> modules;
  @override
  RemoteConfig build() =>
      RemoteConfig.fromJson(<String, dynamic>{'modules': modules});
  @override
  Future<void> refresh({bool force = false}) async {}
}

class NoNetworkRepository implements MobileRepository {
  @override
  String get dutyApiBaseUrl => 'https://fixture.invalid';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError('Unexpected repository call ${invocation.memberName}');
  }
}

GuardDashboardSnapshot dashboardFixture({
  String name = 'Rahul Kumar',
  String employeeId = 'E1',
  String district = 'Ernakulam',
  String? site = 'Central post',
  String? shift = 'Night duty',
  String? date = '2026-10-14',
  bool unavailable = false,
  int absentDays = 2,
}) => GuardDashboardSnapshot(
  employeeName: name,
  employeeId: employeeId,
  clientName: 'CISS client',
  district: district,
  profilePhotoUrl: null,
  presentDays: 18,
  absentDays: absentDays,
  workingDays: 22,
  leaveBalance: null,
  latestEvalScore: null,
  latestEvalPeriod: null,
  nextShiftLabel: shift,
  nextShiftSiteName: site,
  nextShiftDate: date,
  recentAttendance: mockAttendanceHistory,
  nextShiftUnavailable: unavailable,
);

Widget guardTestApp({
  required Widget screen,
  required List<Override> overrides,
  Brightness brightness = Brightness.light,
  double scale = 1,
  AppRole role = AppRole.guard,
}) => ProviderScope(
  overrides: <Override>[
    mobileRepositoryProvider.overrideWithValue(NoNetworkRepository()),
    remoteConfigProvider.overrideWith(() => FixedConfig()),
    NotificationService.unreadCountProvider.overrideWith(
      (ref) => Stream.value(0),
    ),
    ...overrides,
    authSessionProvider.overrideWith(() => _SurfaceTestSession(role)),
    workspaceAccessSessionKeyProvider.overrideWith(
      (ref) => '${role.name}:auth-a',
    ),
  ],
  child: MaterialApp(
    theme: buildCissTheme(brightness),
    builder:
        (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
    home: screen,
  ),
);

class _SurfaceTestSession extends AuthSessionNotifier {
  _SurfaceTestSession(this.role);
  final AppRole role;

  @override
  Future<AuthSession?> build() async => AuthSession(
    role: role,
    displayName: 'Surface test user',
    primaryId: 'surface-test',
    uid: 'auth-a',
  );
}
