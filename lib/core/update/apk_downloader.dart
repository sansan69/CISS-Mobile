import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'update_url_policy.dart';

/// Errors thrown by [ApkDownloader].
sealed class ApkDownloadError implements Exception {
  ApkDownloadError(this.message);
  final String message;

  @override
  String toString() => 'ApkDownloadError: $message';
}

class ApkHashMismatchError extends ApkDownloadError {
  ApkHashMismatchError(String expected, String actual)
    : super('SHA256 mismatch: expected $expected, got $actual');
}

/// Thrown when the local storage cannot hold the update (F-16 / P-05).
///
/// [ApkDownloader] maps `FileSystemException`s whose OS error is `ENOSPC`
/// (and the Windows disk-full equivalents) onto this error so the gate can
/// show a specific message instead of an opaque "Download failed".
class ApkDiskFullError extends ApkDownloadError {
  ApkDiskFullError({int? neededBytes, int? availableBytes, String? detail})
    : super(_describe(neededBytes, availableBytes, detail));

  static String _describe(int? needed, int? available, String? detail) {
    if (needed != null && needed > 0 && available != null && available > 0) {
      return 'Insufficient disk space: need ${_mb(needed)} MB, '
          'only ${_mb(available)} MB available';
    }
    final suffix = detail == null || detail.isEmpty ? '' : ' ($detail)';
    return 'Insufficient disk space: the device ran out of storage while '
        'saving the update$suffix.';
  }

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}

class ApkNetworkError extends ApkDownloadError {
  ApkNetworkError(super.message);
}

/// A local file-system failure that is not disk exhaustion.
class ApkStorageError extends ApkDownloadError {
  ApkStorageError(super.message);
}

/// The server streamed more bytes than the manifest advertised (F-16 / P-05).
class ApkSizeExceededError extends ApkDownloadError {
  ApkSizeExceededError(this.expectedBytes, this.receivedBytes)
    : super(
        'The update server sent ${_mb(receivedBytes)} MB of data for an '
        'update advertised as ${_mb(expectedBytes)} MB. The download was '
        'aborted.',
      );

  final int expectedBytes;
  final int receivedBytes;

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}

/// The manifest itself is not trustworthy (bad URL or bad digest format).
class ApkManifestError extends ApkDownloadError {
  ApkManifestError(super.message);
}

/// Downloads an APK from [apkUrl], writes it to a temporary file, and
/// verifies its SHA-256 hash against [expectedSha256] while streaming.
///
/// Reports progress via [onProgress] as `(receivedBytes, totalBytes)`.
///
/// The download can be cancelled via [cancelToken].
///
/// Returns the absolute path to the downloaded and verified APK file. The
/// APK is only kept when the digest matches; every failure path deletes the
/// partial file.
class ApkDownloader {
  ApkDownloader({Dio? dio, Future<Directory> Function()? tempDirectoryProvider})
    : _dio = dio ?? Dio(),
      _tempDirectory = tempDirectoryProvider ?? getTemporaryDirectory;

  final Dio _dio;
  final Future<Directory> Function() _tempDirectory;

  static const _cacheSubdir = 'android_updates';
  static const _sizeCapFactor = 1.05;
  static const _staleDownloadMaxAge = Duration(hours: 24);
  static final _sha256Pattern = RegExp(r'^[0-9a-fA-F]{64}$');

  /// Downloads and verifies the update APK.
  ///
  /// The digest is computed incrementally with `sha256.startChunkedConversion`
  /// (a `Sink<Digest>` accumulator) so the APK is never buffered in the Dart
  /// heap. The byte stream is capped at `expectedSizeBytes * 1.05` when a
  /// positive size was advertised, which bounds a hostile or broken server.
  Future<String> downloadWithProgress({
    required String apkUrl,
    required String expectedSha256,
    required int expectedSizeBytes,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    // Fail closed before any network traffic leaves the device.
    final target = UpdateUrlPolicy.check(apkUrl);
    if (!target.isAllowed) {
      throw ApkManifestError(
        'Refusing to download an update from an untrusted URL '
        '(${target.rejection!.name}).',
      );
    }
    final expectedDigest = expectedSha256.trim().toLowerCase();
    if (!_sha256Pattern.hasMatch(expectedDigest)) {
      throw ApkManifestError(
        'The update manifest did not include a valid SHA-256 digest.',
      );
    }

    final Directory tempDir;
    try {
      tempDir = await _tempDirectory();
    } on FileSystemException catch (error) {
      throw mapFileSystemException(error);
    }
    final cacheDir = Directory('${tempDir.path}/$_cacheSubdir');
    try {
      if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);
    } on FileSystemException catch (error) {
      throw mapFileSystemException(error);
    }
    await _pruneStaleDownloads(cacheDir);

    final filePath =
        '${cacheDir.path}/ciss-update-${DateTime.now().millisecondsSinceEpoch}.apk';
    final file = File(filePath);

    RandomAccessFile? handle;
    var verified = false;
    try {
      final response = await _dio.get<ResponseBody>(
        apkUrl,
        options: Options(
          responseType: ResponseType.stream,
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 120),
        ),
        cancelToken: cancelToken,
      );

      final body = response.data;
      if (body == null) {
        throw ApkNetworkError('The update server returned an empty response.');
      }

      handle = await file.open(mode: FileMode.write);
      final digestSink = _DigestAccumulator();
      final hashSink = sha256.startChunkedConversion(digestSink);
      final sizeCap =
          expectedSizeBytes > 0
              ? (expectedSizeBytes * _sizeCapFactor).ceil()
              : 0;
      var received = 0;
      var lastReportedPercent = -1;

      onProgress(0, expectedSizeBytes);
      await for (final chunk in body.stream) {
        received += chunk.length;
        if (sizeCap > 0 && received > sizeCap) {
          throw ApkSizeExceededError(expectedSizeBytes, received);
        }
        try {
          await handle.writeFrom(chunk);
        } on FileSystemException catch (error) {
          throw mapFileSystemException(error);
        }
        hashSink.add(chunk);

        final percent =
            expectedSizeBytes > 0 ? (received * 100 ~/ expectedSizeBytes) : 0;
        if (percent != lastReportedPercent) {
          lastReportedPercent = percent;
          onProgress(received, expectedSizeBytes);
        }
      }

      hashSink.close();
      await handle.flush();
      await handle.close();
      handle = null;

      final actualDigest = digestSink.value.toString().toLowerCase();
      if (actualDigest != expectedDigest) {
        throw ApkHashMismatchError(expectedDigest, actualDigest);
      }

      verified = true;
      return filePath;
    } on DioException catch (error) {
      throw ApkNetworkError(
        cancelToken?.isCancelled ?? false
            ? 'Download cancelled.'
            : 'Download failed: ${error.message}',
      );
    } on FileSystemException catch (error) {
      throw mapFileSystemException(error);
    } finally {
      try {
        await handle?.close();
      } catch (_) {
        // Ignore: the handle is already gone or the disk is unusable.
      }
      if (!verified) await _deleteQuietly(file);
    }
  }

  /// True when [error] is an out-of-disk error.
  ///
  /// Android/Linux report `ENOSPC` (28); Windows reports
  /// `ERROR_HANDLE_DISK_FULL` (39) or `ERROR_DISK_FULL` (112). Some
  /// implementations only surface the message text.
  static bool isOutOfSpace(FileSystemException error) {
    final code = error.osError?.errorCode;
    if (code == 28 || code == 39 || code == 112) return true;
    final message =
        '${error.message} ${error.osError?.message ?? ''}'.toLowerCase();
    return message.contains('no space left') ||
        message.contains('enospc') ||
        message.contains('disk full') ||
        message.contains('not enough space') ||
        message.contains('insufficient storage');
  }

  /// Maps a [FileSystemException] onto the matching [ApkDownloadError].
  ///
  /// Exposed for tests: an `ENOSPC` write failure must surface as
  /// [ApkDiskFullError] rather than an opaque download failure.
  static ApkDownloadError mapFileSystemException(FileSystemException error) {
    if (isOutOfSpace(error)) {
      return ApkDiskFullError(detail: error.osError?.message ?? error.message);
    }
    return ApkStorageError(
      'Could not write the update to local storage: ${error.message}',
    );
  }

  /// Removes download leftovers from previous sessions so repeated failed
  /// updates cannot accumulate 86 MB files in the cache directory.
  Future<void> _pruneStaleDownloads(Directory cacheDir) async {
    try {
      final cutoff = DateTime.now().subtract(_staleDownloadMaxAge);
      await for (final entity in cacheDir.list()) {
        if (entity is! File || !entity.path.endsWith('.apk')) continue;
        try {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) await entity.delete();
        } catch (_) {
          // Best effort: never fail a download over cache housekeeping.
        }
      }
    } catch (_) {
      // Best effort: the directory may not be listable on some devices.
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort: a locked file must not mask the original failure.
    }
  }
}

/// Minimal `Sink<Digest>` used with `Hash.startChunkedConversion` so the
/// digest is accumulated chunk by chunk instead of hashing a fully buffered
/// file in memory (F-16: an 86 MB APK needed ~170-260 MB of heap before).
class _DigestAccumulator implements Sink<Digest> {
  Digest? _digest;

  Digest get value {
    final digest = _digest;
    if (digest == null) {
      throw StateError('The SHA-256 sink was closed without a digest.');
    }
    return digest;
  }

  @override
  void add(Digest data) => _digest = data;

  @override
  void close() {}
}
