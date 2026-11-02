import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/widgets.dart';

import '../network/mobile_repository.dart';
import '../network/api_client.dart';
import '../location/background_tracking_service.dart';
import '../location/tracking_buffer.dart';
import '../offline/offline_queue.dart';
import '../offline/offline_request.dart';

/// Sends queued offline work.
///
/// Design rules (see audit F-22):
/// * **Never replay or mutate account-scoped work while nobody is signed in.**
///   A boot-time flush with no account must not accrue retry counts against or
///   evict another account's work. Unauthenticated public attendance
///   submissions are the one exception: they carry their own verification
///   proof, are sent without a bearer token, and drain while signed out.
/// * **Backoff is per entry and persisted** ([OfflineRequest.nextAttemptAt]) so
///   one failing entry never delays later entries and the wait survives process
///   death. The pass never sleeps.
/// * **Triggers coalesce** instead of being dropped: a connectivity/resume
///   trigger that arrives during a pass requests exactly one more pass.
/// * **Nothing is deleted after failures.** After [maxRetryAttempts] the entry is
///   marked blocked, kept on disk, and surfaced in `SyncStatusBadge`.
/// * A foreground [foregroundFlushInterval] timer and an app-resume observer
///   keep retries flowing while the app is open.
typedef OfflineRequestProcessor = Future<bool> Function(OfflineRequest request);

class SyncService with WidgetsBindingObserver {
  SyncService(
    this._repository,
    this._queue,
    this._trackingBuffer, {
    DateTime Function()? clock,
    math.Random? random,
    OfflineRequestProcessor? requestProcessor,
    Duration foregroundFlushInterval = SyncService.foregroundFlushInterval,
    Duration backoffBase = SyncService.backoffBase,
    Duration backoffCap = SyncService.maxBackoff,
    Duration backoffJitter = SyncService.maxJitter,
  }) : _now = clock ?? DateTime.now,
       _random = random ?? math.Random(),
       _requestProcessor = requestProcessor,
       _flushInterval = foregroundFlushInterval,
       _backoffBase = backoffBase,
       _backoffCap = backoffCap,
       _backoffJitter = backoffJitter;

  final MobileRepository _repository;
  final OfflineQueue _queue;
  final TrackingBuffer _trackingBuffer;
  final Connectivity _connectivity = Connectivity();
  final DateTime Function() _now;
  final math.Random _random;
  final OfflineRequestProcessor? _requestProcessor;
  final Duration _flushInterval;
  final Duration _backoffBase;
  final Duration _backoffCap;
  final Duration _backoffJitter;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _timer;
  bool _observerRegistered = false;
  bool _started = false;

  /// The pass currently running. Additional triggers await it and set
  /// [_rerunRequested] so exactly one more pass runs afterwards.
  Future<void>? _inFlight;
  bool _rerunRequested = false;

  /// Number of sync passes completed, including coalesced reruns. Exposed for
  /// tests that assert trigger coalescing.
  @foundation.visibleForTesting
  int completedPasses = 0;

  /// Tracking samples posted per batch request. The server rejects an
  /// oversized payload, so a single request for the entire (up to 5000-sample)
  /// buffer could be retried forever; chunking keeps each request bounded.
  static const int trackingBatchChunkSize = 200;

  /// Foreground flush cadence while the app is open.
  static const Duration foregroundFlushInterval = Duration(minutes: 3);

  /// Attempts before an entry is marked blocked (kept, not deleted).
  static const int maxRetryAttempts = 20;

  static const Duration backoffBase = Duration(seconds: 30);
  static const Duration maxBackoff = Duration(minutes: 15);
  static const Duration maxJitter = Duration(seconds: 5);

  /// Splits [items] into consecutive chunks of at most [size] elements.
  static Iterable<List<T>> chunked<T>(List<T> items, int size) sync* {
    for (var start = 0; start < items.length; start += size) {
      final end = math.min(start + size, items.length);
      yield items.sublist(start, end);
    }
  }

  void start() {
    if (_started) return;
    _started = true;
    _subscription?.cancel();
    try {
      _subscription = _connectivity.onConnectivityChanged.listen(
        (results) {
          if (results.any((r) => r != ConnectivityResult.none)) {
            unawaited(processQueue());
          }
        },
        onError: (Object error) {
          foundation.debugPrint('Connectivity stream error: $error');
        },
      );
    } catch (error) {
      // Connectivity is unavailable in unit tests / restricted environments;
      // the timer and resume trigger keep sync alive without it.
      foundation.debugPrint(
        'SyncService: connectivity listener unavailable '
        '(${error.runtimeType})',
      );
      _subscription = null;
    }
    _registerObserver();
    _timer?.cancel();
    _timer = Timer.periodic(_flushInterval, (_) {
      unawaited(processQueue());
    });
    // Process any queued requests immediately on startup.
    unawaited(processQueue());
  }

  void stop() {
    _started = false;
    _subscription?.cancel();
    _subscription = null;
    _timer?.cancel();
    _timer = null;
    _unregisterObserver();
  }

  void _registerObserver() {
    if (_observerRegistered) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    } catch (error) {
      // Unit tests / very early startup may run before a binding exists.
      foundation.debugPrint(
        'SyncService: lifecycle observer unavailable (${error.runtimeType})',
      );
    }
  }

  void _unregisterObserver() {
    if (!_observerRegistered) return;
    _observerRegistered = false;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {
      // Nothing to unregister if the binding is gone.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(processQueue());
    }
  }

  /// Runs a sync pass, coalescing overlapping triggers.
  ///
  /// If a pass is already running the returned future completes with that pass
  /// and exactly one additional pass is queued afterwards — connectivity events
  /// that arrive mid-pass are no longer dropped.
  Future<void> processQueue() {
    final existing = _inFlight;
    if (existing != null) {
      _rerunRequested = true;
      return existing;
    }
    final future = _drain();
    _inFlight = future;
    return future;
  }

  Future<void> _drain() async {
    try {
      do {
        _rerunRequested = false;
        await _processPass();
        completedPasses += 1;
      } while (_rerunRequested);
    } finally {
      _inFlight = null;
    }
    // A trigger that landed after the loop's last check but before the in-flight
    // handle was cleared still earns its one extra pass.
    if (_rerunRequested) {
      unawaited(processQueue());
    }
  }

  Future<void> _processPass() async {
    // Capture the account this pass belongs to. If the signed-in identity
    // changes while an attempt is awaiting (A signs out, B signs in), the
    // remaining A-owned snapshot entries must not be sent with B's bearer
    // token and must not be recreated by failure bookkeeping.
    final activeUid = _repository.currentUser?.uid;

    // Location samples are account-scoped: the batch endpoint needs a bearer
    // token, so they are flushed only while the account is signed in.
    if (activeUid != null) {
      await _flushTrackingSamples(activeUid);
    }

    // Unauthenticated public attendance submissions carry their own short-lived
    // verification proof and are replayed without a bearer token, so a signed
    // out device still drains them instead of dropping the work (NEW-03).
    final requests = _queue.getQueuedRequests();
    if (requests.isEmpty) return;

    var skippedBlocked = 0;
    for (final request in requests) {
      // Account-scoped work must never be replayed or mutated under a different
      // account: stop the pass if the identity changed or the entry belongs to
      // someone else.
      final isPublic = request.isPublicAttendance;
      if (!isPublic) {
        final currentUid = _repository.currentUser?.uid;
        // A pass with no account still drains public attendance entries. Skip
        // account-scoped entries instead of aborting the rest of the snapshot;
        // they are rejected/purged elsewhere.
        if (activeUid == null) {
          continue;
        }
        if (currentUid == null ||
            currentUid != activeUid ||
            request.uid != activeUid) {
          return;
        }
      }

      if (_isRetiredRequest(request)) {
        await _markRetired(request);
        skippedBlocked += 1;
        continue;
      }
      if (request.blocked) {
        skippedBlocked += 1;
        continue;
      }
      // Entries migrated from the old implementation could already exceed the
      // cap without being marked; block them without spending another attempt.
      if (request.retryCount >= maxRetryAttempts) {
        await _markBlocked(request);
        skippedBlocked += 1;
        continue;
      }
      if (!request.isDue(_now())) {
        // Backed off: continue with later entries instead of sleeping.
        continue;
      }

      // Recheck immediately before dispatch: an earlier await may have
      // completed a sign-out/sign-in transition.
      if (!isPublic && _repository.currentUser?.uid != activeUid) return;

      final success = await _attempt(request);
      if (!success) continue;

      // Do not mutate A's queue entries after the identity has moved to B.
      if (!isPublic && _repository.currentUser?.uid != activeUid) return;

      await _removeRequest(request.id);
      if (request.path == '/api/attendance/submit') {
        try {
          await BackgroundTrackingService.reconcileWithServer(_repository);
        } catch (error) {
          foundation.debugPrint(
            'Attendance synced; tracking reconciliation deferred: $error',
          );
        }
      }
    }
    if (skippedBlocked > 0) {
      foundation.debugPrint(
        'SyncService: $skippedBlocked blocked request(s) kept for inspection',
      );
    }
  }

  Future<bool> _attempt(OfflineRequest request) async {
    final processor = _requestProcessor;
    try {
      final success =
          processor != null
              ? await processor(request)
              : await _sendRequest(request);
      if (success) return true;
      await _recordFailure(request, 'The server rejected the request.');
    } on _SyncFailure catch (failure) {
      await _recordFailure(failure.request, failure.message);
    } catch (error) {
      await _recordFailure(request, error.toString());
    }
    return false;
  }

  Future<void> _recordFailure(OfflineRequest request, String error) async {
    // An unauthenticated pass must not mutate account-scoped work, and a
    // failure that arrives after an account switch must not update (or
    // recreate) the previous account's entry.
    if (!request.isPublicAttendance) {
      final currentUid = _repository.currentUser?.uid;
      if (currentUid == null || currentUid != request.uid) return;
    }
    final retryCount = request.retryCount + 1;
    final blocked = retryCount >= maxRetryAttempts;
    final nextAttemptAt =
        blocked ? null : _now().add(_backoffFor(retryCount));
    try {
      await _queue.updateRequest(
        request.copyWith(
          retryCount: retryCount,
          lastError: error,
          blocked: blocked,
          nextAttemptAt: nextAttemptAt,
          clearNextAttemptAt: blocked,
        ),
      );
    } catch (updateError) {
      foundation.debugPrint(
        'SyncService: could not persist retry state for ${request.id} '
        '(${updateError.runtimeType})',
      );
    }
    if (blocked) {
      foundation.debugPrint(
        'SyncService: request ${request.id} blocked after $retryCount '
        'attempts — kept on disk for inspection.',
      );
    } else {
      foundation.debugPrint(
        'SyncService: request ${request.id} failed (retry #$retryCount), '
        'next attempt at ${nextAttemptAt!.toIso8601String()}.',
      );
    }
  }

  Future<void> _markBlocked(OfflineRequest request) async {
    if (_repository.currentUser == null && !request.isPublicAttendance) return;
    try {
      await _queue.updateRequest(
        request.copyWith(blocked: true, clearNextAttemptAt: true),
      );
    } catch (updateError) {
      foundation.debugPrint(
        'SyncService: could not mark ${request.id} blocked '
        '(${updateError.runtimeType})',
      );
    }
    foundation.debugPrint(
      'SyncService: request ${request.id} blocked at retry count '
      '${request.retryCount} — kept on disk for inspection.',
    );
  }

  static const String _retiredRequestMessage =
      'This queued request targets the retired leave feature and was not sent.';

  bool _isRetiredRequest(OfflineRequest request) =>
      request.path.split('?').first == '/api/guard/leave';

  Future<void> _markRetired(OfflineRequest request) async {
    if (_repository.currentUser == null && !request.isPublicAttendance) return;
    try {
      await _queue.updateRequest(
        request.copyWith(
          blocked: true,
          lastError: _retiredRequestMessage,
          clearNextAttemptAt: true,
        ),
      );
    } catch (updateError) {
      foundation.debugPrint(
        'SyncService: could not mark retired request ${request.id} blocked '
        '(${updateError.runtimeType})',
      );
    }
  }

  /// Exponential backoff with a cap and a small jitter.
  ///
  /// Failure 1 waits [backoffBase], then doubles per failure up to
  /// [maxBackoff], plus 0..[maxJitter] to avoid a thundering herd when
  /// connectivity returns for many devices at once.
  Duration _backoffFor(int retryCount) {
    final exponent = math.min(math.max(retryCount - 1, 0), 10);
    final scaled = _backoffBase.inMilliseconds * (1 << exponent);
    final capped = math.min(scaled, _backoffCap.inMilliseconds);
    final jitter =
        _backoffJitter.inMilliseconds <= 0
            ? 0
            : _random.nextInt(_backoffJitter.inMilliseconds + 1);
    return Duration(milliseconds: capped + jitter);
  }

  Future<void> _removeRequest(String id) async {
    try {
      await _queue.removeRequest(id);
    } catch (removeError) {
      foundation.debugPrint(
        'Failed to remove request $id from queue: $removeError',
      );
    }
  }

  /// Uploads buffered tracking samples in bounded chunks, persisting progress
  /// after each chunk so a delivered chunk is not re-sent. Never throws: a
  /// failure (offline, non-2xx, auth) is logged and the un-sent tail is retried
  /// on the next [processQueue] pass.
  Future<void> _flushTrackingSamples(String expectedUid) async {
    final List<Map<String, dynamic>> pending;
    try {
      pending = await _trackingBuffer.readPending();
    } catch (error) {
      // Buffer not initialized yet (early startup) — retry on the next pass.
      return;
    }
    if (pending.isEmpty) return;

    final chunks = chunked(pending, trackingBatchChunkSize);
    var sent = 0;
    for (final chunk in chunks) {
      try {
        // The spool is account-scoped. If A signs out and B signs in while a
        // batch is awaiting, stop: the remaining samples must not be sent with
        // B's bearer token or committed to B's spool.
        if (_repository.currentUser?.uid != expectedUid) return;
        final dio = _repository.apiClient.dio;
        final response = await dio.post<dynamic>(
          '/api/mobile/tracking/batch',
          data: <String, dynamic>{'samples': chunk},
          options: Options(headers: await _repository.authHeaders()),
        );
        if (_repository.currentUser?.uid != expectedUid) return;
        final data = response.data;
        if (data is Map && data['success'] == false) {
          throw Exception(
            data['error']?.toString() ?? 'Server rejected tracking batch',
          );
        }
        sent += chunk.length;
        // Persist progress: keep only the un-sent tail so a crash mid-flush
        // does not resend the chunks that already landed. An empty remainder
        // clears the spool.
        await _trackingBuffer.commit(pending.sublist(sent));
      } catch (error) {
        foundation.debugPrint(
          'Tracking batch sync failed (${pending.length} samples, '
          '$sent already sent), will retry later: $error',
        );
        break;
      }
    }
  }

  /// Performs one queued request. Throws [_SyncFailure] (carrying the possibly
  /// narrowed request with uploaded photo URLs persisted) on failure so the
  /// retry bookkeeping happens in exactly one place.
  Future<bool> _sendRequest(OfflineRequest request) async {
    var currentRequest = request;
    try {
      final dio = _repository.apiClient.dio;
      final body = Map<String, dynamic>.from(request.body);
      var verificationToken =
          body['attendanceVerificationToken'] is String
              ? body['attendanceVerificationToken'] as String
              : null;
      final isPublicAttendance = request.isPublicAttendance;

      // Account-scoped work is bound to the uid that queued it. Re-check after
      // every await so a mid-flight A -> B switch cannot upload or submit A's
      // work under B's token.
      bool stillOwned() =>
          isPublicAttendance || _repository.currentUser?.uid == request.uid;
      if (!stillOwned()) {
        throw _SyncFailure(
          currentRequest,
          'Account changed before the queued request could be sent.',
        );
      }

      // Public attendance proofs intentionally expire. A request can remain
      // in the offline queue longer than that lifetime, so refresh the proof
      // from the canonical identity endpoint before replaying the upload.
      // Keep the original queued token if re-identification returns no proof;
      // the normal server response will still determine whether the request
      // can be accepted.
      if (isPublicAttendance) {
        final employeeId = body['employeeId']?.toString().trim() ?? '';
        final phoneNumber = body['employeePhoneNumber']?.toString().trim();
        if (employeeId.isNotEmpty) {
          final identified = await _repository.fetchAttendanceEmployee(
            employeeId,
            phoneNumber,
          );
          final freshToken = identified?.verificationToken;
          if (freshToken != null && freshToken.isNotEmpty) {
            verificationToken = freshToken;
            body['attendanceVerificationToken'] = freshToken;
          }
        }
      }

      final options = Options(
        method: request.method,
        headers: isPublicAttendance ? null : await _repository.authHeaders(),
        extra:
            isPublicAttendance ? <String, dynamic>{kSkipApiAuth: true} : null,
      );
      bool bodyChanged = false;

      // 1. Handle single photo upload if present
      if (body.containsKey('photoDataUrl')) {
        final dataUrl = body.remove('photoDataUrl') as String;
        final employeeDocId = body['employeeDocId'] as String?;
        if (employeeDocId == null || employeeDocId.trim().isEmpty) {
          throw Exception('Attendance photo upload requires an employee id.');
        }

        if (!stillOwned()) {
          throw _SyncFailure(
            currentRequest,
            'Account changed before the attendance photo upload.',
          );
        }
        final result = await _repository.uploadAttendancePhoto(
          employeeDocId: employeeDocId.trim(),
          dataUrl: dataUrl,
          siteId: body['siteId'] as String? ?? '',
          verificationToken: isPublicAttendance ? verificationToken : null,
          authenticated: !isPublicAttendance,
        );
        final uploadedUrl = result['url'];
        if (uploadedUrl == null || uploadedUrl is! String) {
          throw Exception('Photo upload did not return a URL');
        }
        body['photoUrl'] = uploadedUrl;
        body['photoStoragePath'] = result['path'];
        bodyChanged = true;
      }

      // 2. Handle multiple photos upload if present
      if (body.containsKey('photoDataUrls')) {
        final dataUrls = List<String>.from(
          body.remove('photoDataUrls') as List,
        );
        final photoUrls = <String>[];
        // Detect FO report paths for correct upload folder
        final isVisitReport = request.path.contains('visit-reports');
        final isTrainingReport = request.path.contains('training-reports');
        final ts = DateTime.now().millisecondsSinceEpoch;
        for (var i = 0; i < dataUrls.length; i++) {
          if (!stillOwned()) {
            throw _SyncFailure(
              currentRequest,
              'Account changed before the report photo upload.',
            );
          }
          final String uploadPath;
          if (isVisitReport || isTrainingReport) {
            final folder = isVisitReport ? 'visitReports' : 'trainingReports';
            // Bind the storage path to the account that queued the work, not
            // to whichever account is current when the upload runs.
            final uid = request.uid ?? _repository.currentUser?.uid ?? 'unknown';
            uploadPath = 'foReports/$folder/$uid/${ts}_$i.jpg';
          } else {
            uploadPath = 'reports/${ts}_$i.jpg';
          }
          final result = await _repository.uploadReportPhoto(
            path: uploadPath,
            dataUrl: dataUrls[i],
          );
          final url = result['url'];
          if (url == null || url is! String) {
            throw Exception('Report photo upload did not return a URL');
          }
          photoUrls.add(url);
        }
        body['photoUrls'] = photoUrls;
        bodyChanged = true;
      }

      if (body.containsKey('clientReportDataUrls')) {
        final dataUrls = List<String>.from(
          body.remove('clientReportDataUrls') as List,
        );
        String? clientReportUrl;
        final ts = DateTime.now().millisecondsSinceEpoch;
        final uid = request.uid ?? _repository.currentUser?.uid ?? 'unknown';
        for (var i = 0; i < dataUrls.length; i++) {
          if (!stillOwned()) {
            throw _SyncFailure(
              currentRequest,
              'Account changed before the client report photo upload.',
            );
          }
          final result = await _repository.uploadReportPhoto(
            path:
                'foReports/trainingReportFiles/$uid/${ts}_client_report_$i.jpg',
            dataUrl: dataUrls[i],
          );
          final url = result['url'];
          if (url is! String || url.isEmpty) {
            throw Exception('Client report upload did not return a URL');
          }
          clientReportUrl = url;
        }
        if (clientReportUrl != null) body['clientReportUrl'] = clientReportUrl;
        bodyChanged = true;
      }

      if (bodyChanged) {
        currentRequest = currentRequest.copyWith(body: body);
      }

      if (!stillOwned()) {
        throw _SyncFailure(
          currentRequest,
          'Account changed before the queued request could be sent.',
        );
      }
      final response = await dio.request<dynamic>(
        request.path,
        data: body,
        options: options,
      );
      // Treat 200/201/204 as success; also validate response body if present.
      final responseData = response.data;
      if (responseData is Map && responseData['success'] == false) {
        throw Exception(
          responseData['error']?.toString() ?? 'Server rejected the request',
        );
      }
      return true;
    } catch (error) {
      throw _SyncFailure(currentRequest, error.toString());
    }
  }
}

class _SyncFailure implements Exception {
  const _SyncFailure(this.request, this.message);

  final OfflineRequest request;
  final String message;
}
