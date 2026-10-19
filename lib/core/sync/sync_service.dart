import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' as foundation;

import '../network/mobile_repository.dart';
import '../telemetry/app_telemetry.dart';
import '../network/api_client.dart'
    show kApiRequestIdentityChanged, kApiRequestIdentityGuard, kSkipApiAuth;
import '../location/background_tracking_service.dart';
import '../location/tracking_buffer.dart';
import '../location/tracking_session_store.dart';
import '../offline/offline_queue.dart';
import '../offline/offline_request.dart';

class SyncService {
  SyncService(
    this._repository,
    this._queue,
    this._trackingBuffer, {
    Future<void> Function()? syncWillingness,
    Future<String?> Function()? trackingOwner,
    DateTime Function()? now,
    double Function()? jitter,
    AppTelemetry? telemetry,
  }) : _syncWillingness = syncWillingness,
       _trackingOwner = trackingOwner,
       _telemetry = telemetry ?? AppTelemetry.instance,
       _now = now ?? DateTime.now,
       _jitter = jitter ?? math.Random().nextDouble;

  final AppTelemetry _telemetry;
  final DateTime Function() _now;
  final double Function() _jitter;
  Timer? _periodic;
  final Future<void> Function()? _syncWillingness;
  final Future<String?> Function()? _trackingOwner;

  final MobileRepository _repository;
  final OfflineQueue _queue;
  final TrackingBuffer _trackingBuffer;
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isSyncing = false;
  int _runGeneration = 0;

  /// Tracking samples posted per batch request. The server rejects an
  /// oversized payload, so a single request for the entire (up to 5000-sample)
  /// buffer could be retried forever; chunking keeps each request bounded.
  static const int trackingBatchChunkSize = 200;

  /// Splits [items] into consecutive chunks of at most [size] elements.
  static Iterable<List<T>> chunked<T>(List<T> items, int size) sync* {
    for (var start = 0; start < items.length; start += size) {
      final end = math.min(start + size, items.length);
      yield items.sublist(start, end);
    }
  }

  static Duration retryDelay(int attempts, double jitter) => Duration(
    milliseconds:
        (1000 *
                math.min(300, math.pow(2, math.min(attempts, 9))) *
                (0.5 + jitter.clamp(0, 1)))
            .round(),
  );

  void start() {
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        if (results.any((r) => r != ConnectivityResult.none)) {
          processQueue();
        }
      },
      onError: (Object error) {
        foundation.debugPrint('Connectivity stream error: $error');
      },
    );
    _periodic?.cancel();
    _periodic = Timer.periodic(
      const Duration(seconds: 30),
      (_) => processQueue(),
    );
    // Process any queued requests immediately on startup.
    processQueue();
  }

  void stop() {
    _runGeneration++;
    _periodic?.cancel();
    _periodic = null;
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> processQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;
    final generation = _runGeneration;
    unawaited(
      _telemetry.record('sync_flush', stage: 'start', count: _queue.queueSize),
    );

    try {
      try {
        await _syncWillingness?.call();
      } catch (error) {
        foundation.debugPrint('Duty sync deferred: $error');
      }
      if (generation != _runGeneration) return;
      // Flush buffered location samples first — independent of the generic
      // request queue and fully best-effort (errors are swallowed).
      await _flushTrackingSamples(generation);
      if (generation != _runGeneration) return;

      final owner = _repository.currentUser?.uid;
      final origin = _normalizedOrigin(_repository.dutyApiBaseUrl);
      final requests =
          _queue.getQueuedRequests().where((request) {
            if (request.state != 'pending' || request.origin != origin) {
              return false;
            }
            if (request.ownerUid == null) {
              return request.path == '/api/attendance/submit' &&
                  request.body['attendanceVerificationToken'] is String;
            }
            return owner != null && request.ownerUid == owner;
          }).toList();
      final blockedStreams = <String>{};
      for (final request in requests) {
        if (generation != _runGeneration) return;
        final streamKey =
            request.streamKey ?? 'owner:${request.ownerUid ?? ''}';
        if (blockedStreams.contains(streamKey)) continue;
        // Keep each causal identity/session stream in order while allowing
        // independent public proof or other account streams to make progress.
        if (request.nextAttemptAt?.isAfter(_now()) ?? false) {
          blockedStreams.add(streamKey);
          continue;
        }
        final success = await _processRequest(request, generation);
        if (generation != _runGeneration) return;
        if (success) {
          try {
            await _queue.acknowledge(request.id, _now());
          } catch (removeError) {
            foundation.debugPrint(
              'Failed to remove request ${request.id} from queue: $removeError',
            );
          }
          if (request.path == '/api/attendance/submit') {
            try {
              await BackgroundTrackingService.reconcileWithServer(_repository);
            } catch (error) {
              foundation.debugPrint(
                'Attendance synced; tracking reconciliation deferred: $error',
              );
            }
          }
        } else {
          foundation.debugPrint(
            'Sync failed for request ${request.id}, will retry later.',
          );
          blockedStreams.add(streamKey);
        }
      }
    } finally {
      _isSyncing = false;
      unawaited(
        _telemetry.record(
          'sync_flush',
          stage: 'complete',
          count: _queue.pendingCount,
        ),
      );
    }
  }

  String _normalizedOrigin(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasAuthority) {
      return value.trim().replaceFirst(RegExp(r'/+$'), '');
    }
    return '${uri.scheme.toLowerCase()}://${uri.authority.toLowerCase()}';
  }

  Future<bool> _isCurrent(OfflineRequest request, int generation) async {
    if (generation != _runGeneration) return false;
    final origin = _normalizedOrigin(_repository.dutyApiBaseUrl);
    if (origin != request.origin) {
      return false;
    }
    if (request.ownerUid == null) {
      return true;
    }
    return _repository.currentUser?.uid == request.ownerUid;
  }

  /// Uploads buffered tracking samples in bounded chunks, persisting progress
  /// after each chunk so a delivered chunk is not re-sent. Never throws: a
  /// failure (offline, non-2xx, auth) is logged and the un-sent tail is retried
  /// on the next [processQueue] pass.
  Future<void> _flushTrackingSamples(int generation) async {
    final List<TrackingSpoolEntry> pending;
    try {
      pending = await _trackingBuffer.readPending();
    } catch (error) {
      // Buffer not initialized yet (early startup) — retry on the next pass.
      return;
    }
    if (pending.isEmpty) {
      return;
    }

    // The spool file is shared by every account this device has ever used and
    // survives logout, so delivery is restricted to rows this guard captured
    // for this backend. Anything else — another guard's samples, or legacy rows
    // written before the envelope existed — stays in the spool untouched rather
    // than being posted under the current credentials.
    final authUid = _repository.currentUser?.uid;
    final origin = _repository.dutyApiBaseUrl;
    final owner = await _currentTrackingOwner();
    if (generation != _runGeneration ||
        authUid == null ||
        _repository.currentUser?.uid != authUid ||
        _normalizedOrigin(_repository.dutyApiBaseUrl) !=
            _normalizedOrigin(origin)) {
      return;
    }
    final deliverable = <int>[];
    if (owner != null && owner.isNotEmpty) {
      for (var index = 0; index < pending.length; index++) {
        if (pending[index].belongsTo(owner: owner, origin: origin)) {
          deliverable.add(index);
        }
      }
    }
    if (deliverable.isEmpty) return;

    // Rows the server has finished with: accepted, or rejected for a reason
    // retrying cannot fix. Retryable rejections stay in the spool.
    final retired = <int>{};
    for (final chunk in chunked(deliverable, trackingBatchChunkSize)) {
      try {
        final dio = _repository.apiClient.dio;
        Future<bool> identityGuard() async =>
            generation == _runGeneration &&
            _repository.currentUser?.uid == authUid &&
            _normalizedOrigin(_repository.dutyApiBaseUrl) ==
                _normalizedOrigin(origin);
        if (!await identityGuard()) return;
        final headers = await _repository.authHeaders();
        if (!await identityGuard()) return;
        final response = await dio.post<dynamic>(
          '/api/mobile/tracking/batch',
          data: <String, dynamic>{
            'samples': <Map<String, dynamic>>[
              for (final index in chunk) pending[index].sample,
            ],
          },
          options: Options(
            headers: headers,
            extra: {kApiRequestIdentityGuard: identityGuard},
          ),
        );
        if (!await identityGuard()) return;
        final data = response.data;
        if (data is Map && data['success'] == false) {
          throw Exception(
            data['error']?.toString() ?? 'Server rejected tracking batch',
          );
        }
        final results = data is Map ? data['results'] : null;
        if (results is List && results.isNotEmpty) {
          for (final result in results) {
            if (result is! Map) continue;
            final index = result['index'];
            if (index is! int || index < 0 || index >= chunk.length) {
              continue;
            }
            final accepted = result['accepted'] == true;
            final permanentRejection =
                result['accepted'] == false && result['retryable'] == false;
            if (accepted || permanentRejection) retired.add(chunk[index]);
          }
        } else {
          // Older servers report counts only; the whole chunk is settled.
          retired.addAll(chunk);
        }
        // Persist progress: keep only the un-sent tail so a crash mid-flush
        // does not resend the chunks that already landed. An empty remainder
        // clears the spool.
        await _trackingBuffer.commit(<TrackingSpoolEntry>[
          for (var index = 0; index < pending.length; index++)
            if (!retired.contains(index)) pending[index],
        ]);
      } catch (error) {
        foundation.debugPrint(
          'Tracking batch sync failed (${deliverable.length} deliverable '
          'samples, ${retired.length} already settled), will retry later: '
          '$error',
        );
        break;
      }
    }
  }

  /// The guard the current credentials belong to, or null when it cannot be
  /// established locally — in which case nothing is dispatched.
  Future<String?> _currentTrackingOwner() async {
    final injected = _trackingOwner;
    if (injected != null) return injected();
    try {
      final saved = await const TrackingSessionStore().load();
      final owner = (saved?['employeeDocId'] as String?)?.trim();
      if (owner != null && owner.isNotEmpty) return owner;
    } catch (error) {
      foundation.debugPrint('Could not read the tracking owner: $error');
    }
    return null;
  }

  Future<bool> _processRequest(OfflineRequest request, int generation) async {
    var currentRequest = request;
    try {
      final dio = _repository.apiClient.dio;
      final body = Map<String, dynamic>.from(request.body);
      var verificationToken =
          body['attendanceVerificationToken'] is String
              ? body['attendanceVerificationToken'] as String
              : null;
      final isPublicAttendance =
          request.path == '/api/attendance/submit' &&
          verificationToken?.trim().isNotEmpty == true;
      if (!await _isCurrent(request, generation)) return false;

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
          if (!await _isCurrent(request, generation)) {
            return false;
          }
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
        extra: <String, dynamic>{
          if (isPublicAttendance) kSkipApiAuth: true,
          kApiRequestIdentityGuard: () => _isCurrent(request, generation),
        },
      );
      if (!await _isCurrent(request, generation)) {
        return false;
      }
      bool bodyChanged = false;

      // 1. Handle single photo upload if present
      if (body.containsKey('photoDataUrl')) {
        final existingPhotoUrl = body['photoUrl'];
        if (existingPhotoUrl is String && existingPhotoUrl.trim().isNotEmpty) {
          // The upload may have succeeded before the attendance POST timed
          // out. Reuse its durable URL so replay cannot rotate an accepted
          // photo token or upload a duplicate object.
          body.remove('photoDataUrl');
        } else {
          final dataUrl = body.remove('photoDataUrl') as String;
          final employeeDocId = body['employeeDocId'] as String?;
          if (employeeDocId == null || employeeDocId.trim().isEmpty) {
            throw Exception('Attendance photo upload requires an employee id.');
          }

          final result = await _repository.uploadAttendancePhoto(
            employeeDocId: employeeDocId.trim(),
            dataUrl: dataUrl,
            siteId: body['siteId'] as String? ?? '',
            attemptId: body['attendanceAttemptId'] as String? ?? request.id,
            verificationToken: isPublicAttendance ? verificationToken : null,
            authenticated: !isPublicAttendance,
            identityGuard: () => _isCurrent(request, generation),
          );
          if (!await _isCurrent(request, generation)) {
            return false;
          }
          final uploadedUrl = result['url'];
          if (uploadedUrl == null || uploadedUrl is! String) {
            throw Exception('Photo upload did not return a URL');
          }
          body['photoUrl'] = uploadedUrl;
          body['photoStoragePath'] = result['path'];
        }
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
          final String uploadPath;
          if (isVisitReport || isTrainingReport) {
            final folder = isVisitReport ? 'visitReports' : 'trainingReports';
            final uid = _repository.currentUser?.uid ?? 'unknown';
            uploadPath = 'foReports/$folder/$uid/${ts}_$i.jpg';
          } else {
            uploadPath = 'reports/${ts}_$i.jpg';
          }
          final result = await _repository.uploadReportPhoto(
            path: uploadPath,
            dataUrl: dataUrls[i],
            identityGuard: () => _isCurrent(request, generation),
          );
          if (!await _isCurrent(request, generation)) {
            return false;
          }
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
        final uid = _repository.currentUser?.uid ?? 'unknown';
        for (var i = 0; i < dataUrls.length; i++) {
          final result = await _repository.uploadReportPhoto(
            path:
                'foReports/trainingReportFiles/$uid/${ts}_client_report_$i.jpg',
            dataUrl: dataUrls[i],
            identityGuard: () => _isCurrent(request, generation),
          );
          if (!await _isCurrent(request, generation)) {
            return false;
          }
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
        await _queue.updateRequest(currentRequest);
      }

      if (!await _isCurrent(request, generation)) {
        return false;
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
    } catch (e) {
      if (!await _isCurrent(request, generation)) {
        return false;
      }
      if (e is DioException && e.message == kApiRequestIdentityChanged) {
        return false;
      }
      final newRetryCount = currentRequest.retryCount + 1;
      final status = e is DioException ? e.response?.statusCode : null;
      final terminal =
          status != null &&
          status >= 400 &&
          status < 500 &&
          status != 401 &&
          status != 408 &&
          status != 429;
      final data = e is DioException ? e.response?.data : null;
      final reason =
          data is Map
              ? (data['code'] ?? 'http_$status').toString()
              : (status == null
                  ? 'connection_or_upload_failed'
                  : 'http_$status');
      unawaited(
        _telemetry.record(
          'sync_flush',
          stage: 'failed',
          reason: reason,
          failed: true,
        ),
      );
      await _queue.updateRequest(
        currentRequest.copyWith(
          retryCount: newRetryCount,
          lastError: reason,
          state: terminal ? 'rejected' : 'pending',
          nextAttemptAt: _now().add(retryDelay(newRetryCount, _jitter())),
        ),
      );
      return false;
    }
  }
}
