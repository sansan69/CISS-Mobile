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
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        processQueue();
      }
    });
  }

  void stop() {
    _subscription?.cancel();
  }

  Future<void> processQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final requests = _queue.getQueuedRequests();
      for (final request in requests) {
        final success = await _processRequest(request);
        if (success) {
          await _queue.removeRequest(request.id);
        } else {
          // If failed, _processRequest has already updated the retry count and 
          // potentially cleared large base64 photo data if they were successfully 
          // uploaded before the main request failed.
          foundation.debugPrint('Sync failed for request ${request.id}, will retry later.');
          
          if (request.retryCount > 10) {
            // Optional: Move to a "failed" box for manual intervention
          }
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
        body['photoUrl'] = result['url'];
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
            final uid = _repository.apiClient.dio.options.headers['Authorization']?.toString() ?? '';
            uploadPath = 'foReports/$folder/offline_sync/${ts}_$i.jpg';
          } else {
            uploadPath = 'reports/${ts}_$i.jpg';
          }
          final result = await _repository.uploadReportPhoto(
            path: uploadPath,
            dataUrl: dataUrls[i],
          );
          photoUrls.add(result['url'] as String);
        }
        body['photoUrls'] = photoUrls;
        bodyChanged = true;
      }

      if (bodyChanged) {
        currentRequest = currentRequest.copyWith(body: body);
      }

      await dio.request<dynamic>(
        request.path,
        data: body,
        options: options,
      );
      return true;
    } catch (e) {
      final newRetryCount = currentRequest.retryCount + 1;
      await _queue.updateRequest(
        currentRequest.copyWith(
          retryCount: newRetryCount,
          lastError: e.toString(),
        ),
      );

      if (newRetryCount > 20) {
        foundation.debugPrint(
          'Request ${currentRequest.id} to ${currentRequest.path} failed permanently after 20 attempts.',
        );
      }
      return false;
    }
  }
}
