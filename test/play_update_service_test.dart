import 'package:ciss_mobile/core/update/app_update_gate.dart';
import 'package:flutter/material.dart';
import 'package:ciss_mobile/core/update/play_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'mandatory Play update stays open after a failed install and cannot be dismissed',
    (tester) async {
      final source = FakeSource()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: PlayUpdateDialog(
            service: PlayUpdateService(source: source, enabled: true),
            mandatory: true,
          ),
        ),
      );
      expect(find.text('Later'), findsNothing);
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(find.textContaining('did not finish'), findsOneWidget);
      expect(find.text('Update required'), findsOneWidget);
    },
  );

  test(
    'Play builds use the store and unsupported installs fail open',
    () async {
      final source = FakeSource();
      final play = PlayUpdateService(source: source, enabled: true);
      expect(await play.available(), isTrue);
      expect(await play.install(), isTrue);
      source.fail = true;
      expect(await play.available(), isFalse);
      expect(await play.install(), isFalse);
      final sideload = PlayUpdateService(source: source, enabled: false);
      expect(await sideload.available(), isFalse);
    },
  );

  test('minimum supported version decides whether a Play gate is mandatory', () {
    expect(isBelowMinimumVersion('1.2.3+45', '1.2.3'), isFalse);
    expect(isBelowMinimumVersion('1.2.2+99', '1.2.3'), isTrue);
    expect(isBelowMinimumVersion('1.2.3+1', ''), isFalse);
  });

  test('current app is never trapped by a force flag or unavailable Play check', () {
    expect(
      shouldShowPlayUpdate(PlayUpdateStatus.upToDate, mandatory: false),
      isFalse,
    );
    expect(
      shouldShowPlayUpdate(PlayUpdateStatus.unavailable, mandatory: false),
      isFalse,
    );
    expect(
      shouldShowPlayUpdate(PlayUpdateStatus.unavailable, mandatory: true),
      isTrue,
    );
  });

  test('Play update check distinguishes current version from store errors', () async {
    final source = StatusSource(PlayUpdateStatus.upToDate);
    final service = PlayUpdateService(source: source, enabled: true);
    expect(await service.check(), PlayUpdateStatus.upToDate);
    source.status = PlayUpdateStatus.updateAvailable;
    expect(await service.check(), PlayUpdateStatus.updateAvailable);
    source.fail = true;
    expect(await service.check(), PlayUpdateStatus.unavailable);
  });
}

class FakeSource implements PlayUpdateSource {
  bool fail = false;
  @override
  Future<PlayUpdateStatus> check() async {
    if (fail) throw StateError('not Play-installed');
    return PlayUpdateStatus.updateAvailable;
  }

  @override
  Future<bool> install() async {
    if (fail) throw StateError('cancelled');
    return true;
  }
}

class StatusSource implements PlayUpdateSource {
  StatusSource(this.status);
  PlayUpdateStatus status;
  bool fail = false;
  @override
  Future<PlayUpdateStatus> check() async {
    if (fail) throw StateError('offline');
    return status;
  }
  @override
  Future<bool> install() async => true;
}
