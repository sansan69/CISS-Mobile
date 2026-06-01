import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' as foundation;

import '../network/mobile_repository.dart';
import '../offline/offline_queue.dart';
import '../offline/offline_request.dart';

class SyncService {
  SyncService(this._repository, this._queue);

  final MobileRepository _repository;
  final OfflineQueue _queue;
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isSyncing = false;

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
    // Process any queued requests immediately on startup.
    processQueue();
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> processQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final requests = _queue.getQueuedRequests();
      for (final request in requests) {
        // Evict requests that have failed too many times.
        if (request.retryCount > 20) {
          await _queue.removeRequest(request.id);
          foundation.debugPrint(
            'Evicted request ${request.id} after ${request.retryCount} failed attempts.',
          );
          continue;
        }

        final success = await _processRequest(request);
        if (success) {
          try {
            await _queue.removeRequest(request.id);
          } catch (removeError) {
            foundation.debugPrint(
              'Failed to remove request ${request.id} from queue: $removeError',
            );
          }
        } else {
          foundation.debugPrint(
            'Sync failed for request ${request.id}, will retry later.',
          );
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _processRequest(OfflineRequest request) async {
    var currentRequest = request;
    try {
      final dio = _repository.apiClient.dio;
      final options = Options(
        method: request.method,
        headers: await _repository.authHeaders(),
      );

      final body = Map<String, dynamic>.from(request.body);
      bool bodyChanged = false;

      // 1. Handle single photo upload if present
      if (body.containsKey('photoDataUrl')) {
        final dataUrl = body.remove('photoDataUrl') as String;
        final employeeDocId = body['employeeDocId'] as String?;
        final uploadPath = employeeDocId != null
            ? 'employees/$employeeDocId/attendance/${DateTime.now().millisecondsSinceEpoch}.jpg'
            : 'temp/attendance/${DateTime.now().millisecondsSinceEpoch}.jpg';

        final result = await _repository.uploadAttendancePhoto(
          path: uploadPath,
          dataUrl: dataUrl,
        );
        final uploadedUrl = result['url'];
        if (uploadedUrl == null || uploadedUrl is! String) {
          throw Exception('Photo upload did not return a URL');
        }
        body['photoUrl'] = uploadedUrl;
        bodyChanged = true;
      }

      // 2. Handle multiple photos upload if present
      if (body.containsKey('photoDataUrls')) {
        final dataUrls = List<String>.from(body.remove('photoDataUrls') as List);
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
            uploadPath = 'foReports/$folder/offline_sync/${uid}_${ts}_$i.jpg';
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

      if (bodyChanged) {
        currentRequest = currentRequest.copyWith(body: body);
      }

      final response = await dio.request<dynamic>(
        request.path,
        data: body,
        options: options,
      );
      // Treat 200/201/204 as success; also validate response body if present.
      final responseData = response.data;
      if (responseData is Map && responseData['success'] == false) {
        throw Exception(responseData['error']?.toString() ?? 'Server rejected the request');
      }
      return true;
    } catch (e) {
      final newRetryCount = currentRequest.retryCount + 1;
      await _queue.updateRequest(
        currentRequest.copyWith(
          retryCount: newRetryCount,
          lastError: e.toString(),
        ),
      );
      return false;
    }
  }
}
