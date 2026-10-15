import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ciss_mobile/core/models/duty_models.dart';
import 'package:ciss_mobile/core/offline/offline_queue.dart';
import 'package:ciss_mobile/core/offline/offline_request.dart';
import 'package:ciss_mobile/core/offline/willingness_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'encrypted disk restart retains original ownership and leaves attendance spool intact',
    () async {
      final folder = await Directory.systemTemp.createTemp('ciss-duty-spool-');
      Hive.init(folder.path);
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async =>
                call.method == 'read'
                    ? base64UrlEncode(List<int>.filled(32, 7))
                    : null,
          );
      addTearDown(() async {
        await Hive.close();
        await folder.delete(recursive: true);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final attendance = OfflineQueue();
      await attendance.init();
      await attendance.enqueue(
        path: '/api/attendance/submit',
        method: 'POST',
        body: {'employeeDocId': 'employee-doc-a'},
      );
      final attendanceId = attendance.getQueuedRequests().single.id;
      final q = WillingnessQueue(HiveWillingnessStore());
      await q.load();
      final op = await q.choose(
        ownerUid: 'auth-a',
        apiBaseUrl: 'https://a.invalid/',
        workOrderId: 'e1',
        response: WillingnessStatus.willing,
        expectedVersion: 2,
      );
      await Hive.close();
      final restored = WillingnessQueue(HiveWillingnessStore());
      await restored.load();
      final pending = restored.forOwner('auth-a', 'https://a.invalid').single;
      expect(pending.id, op.id);
      expect(pending.expectedVersion, 2);
      expect(pending.state, 'pending');
      expect(restored.forOwner('auth-b', 'https://a.invalid'), isEmpty);
      expect(restored.forOwner('auth-a', 'https://b.invalid'), isEmpty);
      await attendance.init();
      expect(attendance.getQueuedRequests().single.id, attendanceId);
      expect(
        attendance.getQueuedRequests().single.path,
        '/api/attendance/submit',
      );
      expect(
        pending.body.keys,
        unorderedEquals(['response', 'clientRequestId', 'expectedVersion']),
      );
    },
  );

  test('legacy spool rows without duty metadata still deserialize', () {
    final legacy = OfflineRequest.fromJson({
      'id': 'legacy-1',
      'path': '/api/attendance/submit',
      'method': 'POST',
      'body': {'employeeDocId': 'employee-doc-a'},
      'createdAt': '2026-10-01T04:00:00.000Z',
    });
    expect(legacy.id, 'legacy-1');
    expect(legacy.body['employeeDocId'], 'employee-doc-a');
    expect(legacy.retryCount, 0);
    expect(legacy.lastError, isNull);
    expect(
      legacy.toJson().keys,
      unorderedEquals([
        'id',
        'path',
        'method',
        'body',
        'createdAt',
        'retryCount',
        'lastError',
      ]),
    );
  });

  test('legacy spool rows with missing or corrupt fields still load', () {
    final empty = OfflineRequest.fromJson(const <String, dynamic>{});
    expect(empty.id, '');
    expect(empty.method, 'POST');
    expect(empty.body, isEmpty);
    final corrupt = OfflineRequest.fromJson({
      'id': 'legacy-2',
      'createdAt': 'not-a-timestamp',
      'body': 'unexpected',
    });
    expect(corrupt.body, isEmpty);
    expect(corrupt.createdAt.year, isNonNegative);
  });
}
