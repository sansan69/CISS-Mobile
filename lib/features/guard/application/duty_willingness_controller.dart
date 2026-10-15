import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_controller.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/models/duty_models.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/network/api_client.dart'
    show kApiRequestIdentityChanged;
import '../../../../core/offline/willingness_queue.dart';
import '../../../../core/settings/remote_config_provider.dart';

final guardDutiesProvider = FutureProvider<List<GuardDuty>>((ref) {
  ref.watch(
    authSessionProvider.select(
      (state) => (state.valueOrNull?.uid, state.valueOrNull?.role),
    ),
  );
  return ref.watch(mobileRepositoryProvider).fetchGuardDuties();
});
final willingnessQueueProvider = ChangeNotifierProvider<WillingnessQueue>(
  (ref) => WillingnessQueue(HiveWillingnessStore()),
);
final dutyWillingnessControllerProvider = Provider<DutyWillingnessController>(
  (ref) => DutyWillingnessController(ref),
);

class DutyWillingnessController {
  DutyWillingnessController(this.ref);
  final Ref ref;
  String? get _owner {
    final session = ref.read(authSessionProvider).valueOrNull;
    return session?.role == AppRole.guard ? session?.uid : null;
  }

  Future<void> choose(GuardDuty duty, WillingnessStatus response) async {
    final session = await ref.read(authSessionProvider.future);
    final owner = session?.role == AppRole.guard ? session?.uid : null;
    if (owner == null || !duty.canRespond || duty.workOrderId == null) {
      throw StateError('Refresh duty details before responding.');
    }
    final current = await ref.read(guardDutiesProvider.future);
    if (!current.any((row) => identical(row, duty)) ||
        !ref
            .read(remoteConfigProvider)
            .modules
            .isOn('workOrders', fallback: true)) {
      throw StateError('Refresh duty details before responding.');
    }
    final repo = ref.read(mobileRepositoryProvider);
    if (repo.currentUser?.uid != owner) {
      throw StateError('Sign in again before responding.');
    }
    await ref
        .read(willingnessQueueProvider)
        .choose(
          ownerUid: owner,
          apiBaseUrl: repo.dutyApiBaseUrl,
          workOrderId: duty.workOrderId!,
          response: response,
          expectedVersion: duty.willingnessVersion,
        );
    await sync();
  }

  Future<void> sync() async {
    final owner = _owner;
    if (owner == null ||
        !ref
            .read(remoteConfigProvider)
            .modules
            .isOn('workOrders', fallback: true)) {
      return;
    }
    final repo = ref.read(mobileRepositoryProvider);
    final origin = willingnessOrigin(repo.dutyApiBaseUrl);
    if (repo.currentUser?.uid != owner) {
      return;
    }
    bool runIsCurrent() {
      final session = ref.read(authSessionProvider).valueOrNull;
      final activeRepo = ref.read(mobileRepositoryProvider);
      return session?.role == AppRole.guard &&
          session?.uid == owner &&
          identical(activeRepo, repo) &&
          activeRepo.currentUser?.uid == owner &&
          willingnessOrigin(activeRepo.dutyApiBaseUrl) == origin;
    }

    await ref
        .read(willingnessQueueProvider)
        .process(
          owner: () => runIsCurrent() ? owner : null,
          // Keep queue selection pinned to the same deployment that supplied the
          // repository. The send guard below also checks the live provider before
          // dispatch, so a region rebuild cannot send B through captured A.
          origin: () => origin,
          send: (op) {
            final activeRepo = ref.read(mobileRepositoryProvider);
            if (!runIsCurrent() ||
                op.ownerUid != owner ||
                op.apiBaseUrl != origin ||
                willingnessOrigin(activeRepo.dutyApiBaseUrl) != op.apiBaseUrl) {
              throw DioException(
                requestOptions: RequestOptions(
                  path: '/api/guard/duties/${op.workOrderId}/willingness',
                ),
                type: DioExceptionType.cancel,
                message: kApiRequestIdentityChanged,
              );
            }
            return repo.setDutyWillingness(
              workOrderId: op.workOrderId,
              response: op.response,
              clientRequestId: op.id,
              expectedVersion: op.expectedVersion,
              expectedOwnerUid: op.ownerUid,
              expectedApiBaseUrl: op.apiBaseUrl,
              isCurrentOperation: () async => runIsCurrent(),
            );
          },
        );
    // Refresh after both receipts and business rejection: the server's answer
    // may have changed on another device or the duty may have closed.
    ref.invalidate(guardDutiesProvider);
  }
}

final dutyResponseProvider = Provider.family<WillingnessOperation?, String>((
  ref,
  workOrderId,
) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session?.role != AppRole.guard) return null;
  final repo = ref.watch(mobileRepositoryProvider);
  final queue = ref.watch(willingnessQueueProvider);
  return queue
      .forOwner(session!.uid, repo.dutyApiBaseUrl)
      .where((e) => e.workOrderId == workOrderId)
      .lastOrNull;
});

/// Durable responses stay visible even after the server feed removes the duty.
/// Saved receipts are omitted; pending and terminal results remain scoped to
/// the active authenticated guard and API origin.
final dutyResponseHistoryProvider = Provider<List<WillingnessOperation>>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session?.role != AppRole.guard) return const <WillingnessOperation>[];
  final repo = ref.watch(mobileRepositoryProvider);
  final queue = ref.watch(willingnessQueueProvider);
  return queue
      .forOwner(session!.uid, repo.dutyApiBaseUrl)
      .where(
        (operation) =>
            operation.state == 'pending' || operation.state == 'rejected',
      )
      .toList(growable: false);
});
