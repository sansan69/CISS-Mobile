import 'dart:io';
import 'dart:typed_data';

import 'package:ciss_mobile/core/update/apk_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _trustedUrl =
    'https://cisskerala.site/downloads/ciss-workforce-1.0.22.apk';

/// A fake Dio transport that streams fixed chunks, so the downloader can be
/// exercised without touching the network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.chunks);

  final List<List<int>> chunks;
  int fetchCount = 0;

  int get totalBytes =>
      chunks.fold<int>(0, (total, chunk) => total + chunk.length);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount += 1;
    return ResponseBody(
      Stream<Uint8List>.fromIterable(
        chunks.map((chunk) => Uint8List.fromList(chunk)),
      ),
      200,
      headers: <String, List<String>>{
        Headers.contentLengthHeader: <String>[totalBytes.toString()],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

List<int> _payload(int length) =>
    List<int>.generate(length, (index) => (index * 31 + 7) % 256);

Directory _tempDir() {
  final dir = Directory.systemTemp.createTempSync('ciss-apk-downloader-');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

ApkDownloader _downloaderFor(_FakeAdapter adapter, Directory tempDir) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ApkDownloader(dio: dio, tempDirectoryProvider: () async => tempDir);
}

Iterable<File> _leftoverApks(Directory tempDir) {
  final cacheDir = Directory('${tempDir.path}/android_updates');
  if (!cacheDir.existsSync()) return const <File>[];
  return cacheDir.listSync().whereType<File>().where(
    (file) => file.path.endsWith('.apk'),
  );
}

void main() {
  group('ApkDownloader streams and verifies', () {
    test('hashes incrementally while streaming and keeps the file', () async {
      final payload = _payload(64 * 1024);
      final adapter = _FakeAdapter(<List<int>>[
        payload.sublist(0, 1024),
        payload.sublist(1024, 4096),
        payload.sublist(4096),
      ]);
      final tempDir = _tempDir();
      final progress = <int>[];

      final path = await _downloaderFor(adapter, tempDir).downloadWithProgress(
        apkUrl: _trustedUrl,
        expectedSha256: sha256.convert(payload).toString(),
        expectedSizeBytes: payload.length,
        onProgress: (received, total) => progress.add(received),
      );

      final file = File(path);
      expect(file.existsSync(), isTrue);
      expect(await file.readAsBytes(), payload);
      expect(adapter.fetchCount, 1);
      // Progress is reported from zero and ends exactly at the advertised size.
      expect(progress.first, 0);
      expect(progress.last, payload.length);
      expect(progress, orderedEquals(progress.toList()..sort()));
    });

    test('deletes the partial file when the digest does not match', () async {
      final payload = _payload(8 * 1024);
      final adapter = _FakeAdapter(<List<int>>[payload]);
      final tempDir = _tempDir();
      final wrongDigest = sha256.convert(_payload(16 * 1024)).toString();

      await expectLater(
        _downloaderFor(adapter, tempDir).downloadWithProgress(
          apkUrl: _trustedUrl,
          expectedSha256: wrongDigest,
          expectedSizeBytes: payload.length,
          onProgress: (_, __) {},
        ),
        throwsA(isA<ApkHashMismatchError>()),
      );

      expect(_leftoverApks(tempDir), isEmpty);
    });
  });

  group('ApkDownloader enforces the advertised size', () {
    test('aborts a stream larger than expectedSizeBytes * 1.05', () async {
      final payload = _payload(200 * 1024);
      final adapter = _FakeAdapter(<List<int>>[payload]);
      final tempDir = _tempDir();

      await expectLater(
        _downloaderFor(adapter, tempDir).downloadWithProgress(
          apkUrl: _trustedUrl,
          expectedSha256: sha256.convert(payload).toString(),
          expectedSizeBytes: 64 * 1024,
          onProgress: (_, __) {},
        ),
        throwsA(
          isA<ApkSizeExceededError>()
              .having(
                (error) => error.expectedBytes,
                'expectedBytes',
                64 * 1024,
              )
              .having(
                (error) => error.receivedBytes,
                'receivedBytes',
                greaterThan(64 * 1024),
              ),
        ),
      );

      // The aborted download must not leave a corrupt APK behind.
      expect(_leftoverApks(tempDir), isEmpty);
    });

    test('does not cap the stream when no size was advertised', () async {
      final payload = _payload(32 * 1024);
      final adapter = _FakeAdapter(<List<int>>[payload]);
      final tempDir = _tempDir();

      final path = await _downloaderFor(adapter, tempDir).downloadWithProgress(
        apkUrl: _trustedUrl,
        expectedSha256: sha256.convert(payload).toString(),
        expectedSizeBytes: 0,
        onProgress: (_, __) {},
      );
      expect(File(path).lengthSync(), payload.length);
    });
  });

  group('ApkDownloader refuses untrusted manifests', () {
    test('rejects a non-allowlisted URL before any request is made', () async {
      final adapter = _FakeAdapter(<List<int>>[
        <int>[1, 2, 3],
      ]);
      final tempDir = _tempDir();

      await expectLater(
        _downloaderFor(adapter, tempDir).downloadWithProgress(
          apkUrl: 'https://evil.example/downloads/app.apk',
          expectedSha256: sha256.convert(<int>[1, 2, 3]).toString(),
          expectedSizeBytes: 3,
          onProgress: (_, __) {},
        ),
        throwsA(isA<ApkManifestError>()),
      );

      expect(adapter.fetchCount, 0);
      expect(_leftoverApks(tempDir), isEmpty);
    });

    test(
      'rejects an invalid expected digest before any request is made',
      () async {
        final adapter = _FakeAdapter(<List<int>>[
          <int>[1, 2, 3],
        ]);
        final tempDir = _tempDir();

        await expectLater(
          _downloaderFor(adapter, tempDir).downloadWithProgress(
            apkUrl: _trustedUrl,
            expectedSha256: 'not-a-digest',
            expectedSizeBytes: 3,
            onProgress: (_, __) {},
          ),
          throwsA(isA<ApkManifestError>()),
        );

        expect(adapter.fetchCount, 0);
      },
    );
  });

  group('ApkDownloader disk-full handling', () {
    test('maps ENOSPC to ApkDiskFullError', () {
      final enospc = FileSystemException(
        'Failed to write file',
        '/tmp/ciss-update.apk',
        const OSError('No space left on device', 28),
      );

      expect(ApkDownloader.isOutOfSpace(enospc), isTrue);
      final mapped = ApkDownloader.mapFileSystemException(enospc);
      expect(mapped, isA<ApkDiskFullError>());
      expect(mapped.message.toLowerCase(), contains('disk space'));
    });

    test('maps the Windows disk-full OS errors to ApkDiskFullError', () {
      final handleFull = FileSystemException(
        'Failed to write file',
        r'C:\cache\update.apk',
        const OSError('There is not enough space on the disk.', 112),
      );
      expect(ApkDownloader.isOutOfSpace(handleFull), isTrue);
      expect(
        ApkDownloader.mapFileSystemException(handleFull),
        isA<ApkDiskFullError>(),
      );
    });

    test('keeps other file-system errors as ApkStorageError', () {
      final denied = FileSystemException(
        'Failed to open file',
        '/tmp/ciss-update.apk',
        const OSError('Permission denied', 13),
      );

      expect(ApkDownloader.isOutOfSpace(denied), isFalse);
      expect(
        ApkDownloader.mapFileSystemException(denied),
        isA<ApkStorageError>(),
      );
    });
  });
}
