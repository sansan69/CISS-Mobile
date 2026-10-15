import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ciss_mobile/core/models/duty_models.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/core/offline/willingness_queue.dart';
import 'package:ciss_mobile/core/settings/remote_config_provider.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';
import 'package:ciss_mobile/features/guard/application/duty_willingness_controller.dart';
import 'support/guard_redesign_fixtures.dart';
import 'support/duty_core_review_support.dart' as repro;

class Repo extends NoNetworkRepository {
  Repo(this.origin);
  final String origin;
  final sent = <String>[];
  final first = Completer<WillingnessReceipt>();
  @override
  User? get currentUser => repro.TestUser('auth-a');
  @override
  String get dutyApiBaseUrl => origin;
  @override
  Future<WillingnessReceipt> setDutyWillingness({
    required String workOrderId,
    required WillingnessStatus response,
    required String clientRequestId,
    required int expectedVersion,
    String? expectedOwnerUid,
    String? expectedApiBaseUrl,
    Future<bool> Function()? isCurrentOperation,
  }) {
    sent.add(workOrderId);
    if (workOrderId == 'a-duty') return first.future;
    return Future.value(WillingnessReceipt(response: response, version: 1));
  }
}

final regionIndex = StateProvider<int>((ref) => 0);
void main() {
  test(
    'queue B must not use captured repository A after an origin switch',
    () async {
      final a = Repo('https://a.invalid'),
          b = Repo('https://b.invalid'),
          q = WillingnessQueue(repro.Store());
      await q.choose(
        ownerUid: 'auth-a',
        apiBaseUrl: a.origin,
        workOrderId: 'a-duty',
        response: WillingnessStatus.willing,
        expectedVersion: 0,
      );
      await q.choose(
        ownerUid: 'auth-a',
        apiBaseUrl: b.origin,
        workOrderId: 'b-duty',
        response: WillingnessStatus.unavailable,
        expectedVersion: 0,
      );
      final container = ProviderContainer(
        overrides: [
          remoteConfigProvider.overrideWith(() => FixedConfig()),
          authSessionProvider.overrideWith(repro.Session.new),
          mobileRepositoryProvider.overrideWith(
            (ref) => ref.watch(regionIndex) == 0 ? a : b,
          ),
          willingnessQueueProvider.overrideWith((ref) => q),
          guardDutiesProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authSessionProvider.future);
      final processing =
          container.read(dutyWillingnessControllerProvider).sync();
      await Future<void>.delayed(Duration.zero);
      container.read(regionIndex.notifier).state = 1;
      await container.pump();
      a.first.complete(
        const WillingnessReceipt(
          response: WillingnessStatus.willing,
          version: 1,
        ),
      );
      await processing;
      expect(a.sent, ['a-duty']);
      expect(b.sent, isEmpty);
      expect(q.forOwner('auth-a', b.origin).single.state, 'pending');
    },
  );
}
