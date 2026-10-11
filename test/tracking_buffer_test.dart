import 'dart:io';

import 'package:ciss_mobile/core/location/tracking_buffer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('tb').path);
  });

  setUp(() async {
    final buffer = TrackingBuffer();
    await buffer.init(null);
    await Hive.box<Map>(TrackingBuffer.boxName).clear();
  });

  tearDownAll(() async => Hive.close());

  test('caps at maxSamples and evicts oldest', () async {
    final b = TrackingBuffer();
    await b.init(null);
    for (var i = 0; i < TrackingBuffer.maxSamples + 5; i++) {
      await b.add({
        'latitude': i.toDouble(),
        'capturedAt': DateTime.now().toIso8601String(),
      });
    }
    expect(b.pending().length, TrackingBuffer.maxSamples);
    expect(b.pending().first['latitude'], 5.0);
  });

  test('pendingWithIds exposes ids and clear removes exactly those ids', () async {
    final b = TrackingBuffer();
    await b.init(null);
    await b.add({'latitude': 1.0});
    await b.add({'latitude': 2.0});
    await b.add({'latitude': 3.0});

    final keyed = b.pendingWithIds();
    expect(keyed.length, 3);
    expect(
      keyed.values.map((sample) => sample['latitude']).toList(),
      [1.0, 2.0, 3.0],
    );

    final ids = keyed.keys.toList();
    await b.clear(ids.take(2));

    final remaining = b.pendingWithIds();
    expect(remaining.keys.toList(), [ids[2]]);
    expect(remaining.values.single['latitude'], 3.0);
  });
}
