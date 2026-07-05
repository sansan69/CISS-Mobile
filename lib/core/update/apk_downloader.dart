import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Errors thrown by [ApkDownloader].
sealed class ApkDownloadError implements Exception {
  ApkDownloadError(this.message);
  final String message;

  @override
  String toString() => 'ApkDownloadError: $message';
}

class ApkHashMismatchError extends ApkDownloadError {
  ApkHashMismatchError(String expected, String actual)
      : super(
          'SHA256 mismatch: expected $expected, got $actual',
        );
}

class ApkDiskFullError extends ApkDownloadError {
  ApkDiskFullError(int needed, int available)
      : super(
          'Insufficient disk space: need ${_mb(needed)} MB, '
          'only ${_mb(available)} MB available',
        );

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}

class ApkNetworkError extends ApkDownloadError {
  ApkNetworkError(super.message);
}

/// Downloads an APK from [apkUrl], writes it to a temporary file, and
/// verifies its SHA-256 hash against [expectedSha256].
///
/// Reports progress via [onProgress] as `(receivedBytes, totalBytes)`.
///
/// The download can be cancelled via [cancelToken].
///
/// Returns the absolute path to the downloaded and verified APK file.
class ApkDownloader {
  ApkDownloader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _cacheSubdir = 'android_updates';

  Future<String> downloadWithProgress({
    required String apkUrl,
    required String expectedSha256,
    required int expectedSizeBytes,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    // 1. Prepare cache directory
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/$_cacheSubdir');
    if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);

    // 2. Stream download to file
    final filePath = '${cacheDir.path}/ciss-update-${DateTime.now().millisecondsSinceEpoch}.apk';
    final file = File(filePath);

    try {
      final response = await _dio.get<ResponseBody>(
        apkUrl,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 120),
        ),
        cancelToken: cancelToken,
      );

      final sink = file.openWrite();
      int received = 0;
      int lastReported = -1;

      await for (final chunk in response.data!.stream) {
        received += chunk.length;
        sink.add(chunk);

        // Throttle progress callbacks to ~10 fps
        final pct = expectedSizeBytes > 0
            ? (received * 100 ~/ expectedSizeBytes)
            : 0;
        if (pct != lastReported) {
          lastReported = pct;
          onProgress(received, expectedSizeBytes);
        }
      }

      await sink.flush();
      await sink.close();

      // 3. SHA-256 verify from the on-disk file
      final fileBytes = await file.readAsBytes();
      final actualHash = sha256.convert(fileBytes).toString();

      if (actualHash.toLowerCase() != expectedSha256.toLowerCase()) {
        // Delete corrupt file to avoid stale downloads
        try { await file.delete(); } catch (_) {}
        throw ApkHashMismatchError(expectedSha256, actualHash);
      }

      return filePath;
    } on DioException catch (e) {
      // Clean up partial download
      try { if (file.existsSync()) await file.delete(); } catch (_) {}
      throw ApkNetworkError('Download failed: ${e.message}');
    }
  }
}
