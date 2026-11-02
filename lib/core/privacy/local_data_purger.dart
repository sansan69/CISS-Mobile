import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../cache/hive_read_cache_store.dart';
import '../cache/read_cache.dart';
import '../auth/session_snapshot_store.dart';
import '../location/tracking_buffer.dart';
import '../location/tracking_session_store.dart';
import '../offline/draft_service.dart';
import '../offline/offline_queue.dart';
import 'privacy_log.dart';
import '../sync/providers.dart';

/// Outcome of a [LocalDataPurger.purge] run. Deliberately contains only step
/// names and exception class names — never payloads, uids or file names.
class LocalDataPurgeReport {
  final Set<String> completed = <String>{};
  final Map<String, String> failures = <String, String>{};

  bool get isClean => failures.isEmpty;

  bool didClear(String step) => completed.contains(step);
}

typedef PurgeLogger = void Function(String message);
typedef FcmTokenDeleter = Future<void> Function();
typedef TempDirectoryProvider = Future<Directory> Function();
typedef TrackingSessionClearer = Future<void> Function();

/// Clears account-scoped local data that must not survive sign-out or an
/// account change:
///
/// * the read-through cache (encrypted Hive box, uid-scoped keys),
/// * the encrypted offline request queue,
/// * form drafts,
/// * the offline tracking spool (and its owner marker),
/// * the secure-storage tracking session descriptor,
/// * the bounded offline session snapshot,
/// * the FCM device token (guarded when Firebase is not initialised),
/// * downloaded `payslip-*.pdf` files in the temp directory.
///
/// Every step is best-effort and independently guarded: a failure in one store
/// (e.g. secure storage is unavailable) must not prevent the others from being
/// cleared, and must never throw into the sign-out path. Failures are logged by
/// step name + exception type only.
class LocalDataPurger {
  LocalDataPurger({
    required ReadCache readCache,
    required OfflineQueue offlineQueue,
    required DraftService draftService,
    required TrackingBuffer trackingBuffer,
    SessionSnapshotStore? sessionSnapshotStore,
    FcmTokenDeleter? deleteFcmToken,
    TempDirectoryProvider? tempDirectoryProvider,
    TrackingSessionClearer? clearTrackingSession,
    PurgeLogger? log,
  }) : _readCache = readCache,
       _offlineQueue = offlineQueue,
       _draftService = draftService,
       _trackingBuffer = trackingBuffer,
       _sessionSnapshotStore = sessionSnapshotStore ?? SessionSnapshotStore(),
       _deleteFcmToken = deleteFcmToken ?? _deleteFcmDeviceToken,
       _tempDirectoryProvider = tempDirectoryProvider ?? getTemporaryDirectory,
       _clearTrackingSession =
           clearTrackingSession ?? const TrackingSessionStore().clear,
       _log = log ?? debugPrint;

  final ReadCache _readCache;
  final OfflineQueue _offlineQueue;
  final DraftService _draftService;
  final TrackingBuffer _trackingBuffer;
  final SessionSnapshotStore _sessionSnapshotStore;
  final FcmTokenDeleter _deleteFcmToken;
  final TempDirectoryProvider _tempDirectoryProvider;
  final TrackingSessionClearer _clearTrackingSession;
  final PurgeLogger _log;

  static const Duration stepTimeout = Duration(seconds: 2);

  static const String readCacheStep = 'read_cache';
  static const String offlineQueueStep = 'offline_queue';
  static const String draftsStep = 'drafts';
  static const String trackingSpoolStep = 'tracking_spool';
  static const String trackingSessionStep = 'tracking_session';
  static const String sessionSnapshotStep = 'session_snapshot';
  static const String fcmTokenStep = 'fcm_token';
  static const String payslipFilesStep = 'payslip_files';

  static final RegExp payslipTempFilePattern = RegExp(
    r'^payslip-.*\.pdf$',
    caseSensitive: false,
  );

  Future<LocalDataPurgeReport> purge() async {
    final report = LocalDataPurgeReport();

    await _run(report, readCacheStep, _readCache.clear);

    await _run(report, offlineQueueStep, () async {
      // Drop account-scoped ownership first so no in-flight replay can claim
      // an entry while the box is being emptied.
      await _offlineQueue.setOwner(null);
      await _offlineQueue.clear();
    });

    await _run(report, draftsStep, () async {
      await _draftService.setOwner(null);
      await _draftService.clearAll();
    });

    await _run(report, trackingSpoolStep, () async {
      await _trackingBuffer.setOwner(null);
      await _trackingBuffer.clear();
    });

    await _run(report, trackingSessionStep, _clearTrackingSession);

    await _run(report, sessionSnapshotStep, _sessionSnapshotStore.clear);

    await _run(report, fcmTokenStep, _deleteFcmToken);

    await _run(report, payslipFilesStep, _deletePayslipTempFiles);

    return report;
  }

  Future<void> _run(
    LocalDataPurgeReport report,
    String step,
    Future<void> Function() action,
  ) async {
    try {
      await action().timeout(stepTimeout);
      report.completed.add(step);
    } catch (error) {
      // Store/plugin exception messages can contain paths; log the class only.
      report.failures[step] = error.runtimeType.toString();
      _log(
        'LocalDataPurger: $step cleanup failed (${error.runtimeType})',
      );
    }
  }

  Future<void> _deletePayslipTempFiles() async {
    final directory = await _tempDirectoryProvider();
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isEmpty
          ? ''
          : entity.uri.pathSegments.last;
      if (!payslipTempFilePattern.hasMatch(name)) continue;
      try {
        await entity.delete();
      } catch (error) {
        _log(
          'LocalDataPurger: could not delete a payslip file '
          '(${error.runtimeType})',
        );
      }
    }
  }

  /// Deletes the FCM registration token so push notifications for the signed
  /// out account stop arriving on a shared/reassigned device. No-op when
  /// Firebase is not initialised (unit tests, no-Firebase builds).
  static Future<void> _deleteFcmDeviceToken() async {
    if (Firebase.apps.isEmpty) return;
    await FirebaseMessaging.instance.deleteToken();
  }
}

/// Default purger wired to the live stores. Failures are logged with PII
/// redaction applied by the stores themselves.
final Provider<LocalDataPurger> localDataPurgerProvider =
    Provider<LocalDataPurger>((Ref ref) {
      return LocalDataPurger(
        readCache: ref.read(readCacheProvider),
        offlineQueue: ref.read(offlineQueueProvider),
        draftService: ref.read(draftServiceProvider),
        trackingBuffer: ref.read(trackingBufferProvider),
        log: (message) => debugPrint(PrivacyLog.redactForLog(message)),
      );
    });
