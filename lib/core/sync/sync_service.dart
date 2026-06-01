import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' as foundation;

import '../network/mobile_repository.dart';
import '../offline/local_report_store.dart';
import '../offline/offline_queue.dart';
import '../offline/offline_request.dart';

class SyncService {
  SyncService(this._repository, this._queue, this._localReportStore);

  final MobileRepository _repository;
  final OfflineQueue _queue;
  final LocalReportStore _localReportStore;
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isSyncing = false;
  static const int _maxRetries = 15;

  void start() {
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        processQueue();
      }
    });
    // Drain queue on startup — connectivity change may not fire if already online.
    _drainOnStartup();
  }

  Future<void> _drainOnStartup() async {
    final results = await _connectivity.checkConnectivity();
    if (results.any((r) => r != ConnectivityResult.none)) {
      // Small delay to let Hive and auth settle.
      await Future.delayed(const Duration(seconds: 2));
      await processQueue();
    }
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
        // Skip requests that have exceeded max retries.
        if (request.retryCount >= _maxRetries) {
          foundation.debugPrint(
            'Sync: skipping request ${request.id} after $_maxRetries retries.',
          );
          continue;
        }

        // Exponential backoff: wait 2^retryCount seconds (capped at 5 min).
        if (request.retryCount > 0) {
          final backoff = Duration(
            seconds: (1 << request.retryCount.clamp(0, 9)).clamp(1, 300),
          );
          await Future.delayed(backoff);
        }

        final success = await _processRequest(request);
        if (success) {
          await _queue.removeRequest(request.id);
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

      // 1. Handle single photo upload if present.
      if (body.containsKey('photoDataUrl')) {
        final dataUrl = body['photoDataUrl'] as String;
        final employeeDocId = body['employeeDocId'] as String?;
        final uploadPath = employeeDocId != null
            ? 'employees/$employeeDocId/attendance/${request.id}_${DateTime.now().millisecondsSinceEpoch}.jpg'
            : 'temp/attendance/${request.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final result = await _repository.uploadAttendancePhoto(
          path: uploadPath,
          dataUrl: dataUrl,
        );
        body['photoUrl'] = result['url'];
        body.remove('photoDataUrl');
        currentRequest = currentRequest.copyWith(body: body);
        await _queue.updateRequest(currentRequest);
      }

      // 2. Handle multiple photos upload if present.
      if (body.containsKey('photoDataUrls')) {
        final dataUrls = List<String>.from(body['photoDataUrls'] as List);
        final photoUrls = List<String>.from(body['photoUrls'] ?? <String>[]);

        while (dataUrls.isNotEmpty) {
          final currentDataUrl = dataUrls.first;
          final index = photoUrls.length;
          final mimeType = _mimeTypeFromDataUrl(currentDataUrl);
          final extension = _extensionFromMimeType(mimeType);
          final uploadPath =
              'foReports/${request.id}/photos/${request.id}_${index}_${DateTime.now().millisecondsSinceEpoch}.$extension';
          final result = await _repository.uploadAttendancePhoto(
            path: uploadPath,
            dataUrl: currentDataUrl,
          );

          photoUrls.add(result['url'] as String);
          dataUrls.removeAt(0);

          body['photoUrls'] = photoUrls;
          body['photoDataUrls'] = dataUrls;
          currentRequest = currentRequest.copyWith(body: body);
          await _queue.updateRequest(currentRequest);
        }

        body.remove('photoDataUrls');
        currentRequest = currentRequest.copyWith(body: body);
        await _queue.updateRequest(currentRequest);
      }

      if (body.containsKey('attachmentDataUrls')) {
        final dataUrls = List<String>.from(body['attachmentDataUrls'] as List);
        final attachmentUrls = List<String>.from(
          body['attachmentUrls'] ?? <String>[],
        );

        while (dataUrls.isNotEmpty) {
          final currentDataUrl = dataUrls.first;
          final index = attachmentUrls.length;
          final mimeType = _mimeTypeFromDataUrl(currentDataUrl);
          final extension = _extensionFromMimeType(mimeType);
          final uploadPath =
              'foReports/${request.id}/trainingReportFiles/${request.id}_${index}_${DateTime.now().millisecondsSinceEpoch}.$extension';
          final result = await _repository.uploadReportPhoto(
            path: uploadPath,
            dataUrl: currentDataUrl,
          );

          attachmentUrls.add(result['url'] as String);
          dataUrls.removeAt(0);

          body['attachmentUrls'] = attachmentUrls;
          body['attachmentDataUrls'] = dataUrls;
          currentRequest = currentRequest.copyWith(body: body);
          await _queue.updateRequest(currentRequest);
        }

        body.remove('attachmentDataUrls');
        currentRequest = currentRequest.copyWith(body: body);
        await _queue.updateRequest(currentRequest);
      }

      final response = await dio.request<dynamic>(
        request.path,
        data: body,
        options: options,
      );

      // Handle reports syncing feedback loop
      if (request.path == '/api/field-officer/visit-reports' ||
          request.path == '/api/field-officer/training-reports') {
        String? serverId;
        final responseData = response.data;
        List<String>? photoUrls;
        List<String>? attachmentUrls;
        if (responseData is Map) {
          serverId =
              responseData['id']?.toString() ?? responseData['_id']?.toString();
        }
        if (body['photoUrls'] is List) {
          photoUrls = List<String>.from(body['photoUrls'] as List);
        }
        if (body['attachmentUrls'] is List) {
          attachmentUrls = List<String>.from(body['attachmentUrls'] as List);
        }
        await _localReportStore.markSynced(
          request.id,
          serverId: serverId,
          photoUrls: photoUrls,
          attachmentUrls: attachmentUrls,
        );
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

  String _mimeTypeFromDataUrl(String dataUrl) {
    final match = RegExp(r'^data:([^;]+);base64,').firstMatch(dataUrl);
    return match?.group(1) ?? 'application/octet-stream';
  }

  String _extensionFromMimeType(String mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
        return 'heic';
      case 'image/heif':
        return 'heif';
      case 'application/pdf':
        return 'pdf';
      case 'application/msword':
        return 'doc';
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return 'docx';
      case 'application/vnd.ms-excel':
        return 'xls';
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return 'xlsx';
      case 'application/vnd.ms-powerpoint':
        return 'ppt';
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        return 'pptx';
      case 'text/plain':
        return 'txt';
      default:
        return 'bin';
    }
  }
}
