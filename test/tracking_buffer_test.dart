import 'dart:io';

import 'package:ciss_mobile/core/location/tracking_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

/// The buffer is now an append-only, line-delimited JSON spool file rather
/// than a Hive box: Hive boxes are per-isolate, so samples written by the
/// `flutter_background_service` background isolate were invisible to the main
/// isolate's `SyncService` flush. Writing them to a shared file that the main
/// isolate drains makes the offline buffer actually survive.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('tracking_spool');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<TrackingBuffer> newBuffer() async {
    final b = TrackingBuffer(directory: dir);
    await b.init();
    return b;
  }

  test(
    'appends are drained oldest-first and commit clears the spool',
    () async {
      final b = await newBuffer();
      await b.add({'latitude': 1.0});
      await b.add({'latitude': 2.0});
      await b.add({'latitude': 3.0});

      final drained = await b.readPending();
      expect(drained.map((s) => s.sample['latitude']).toList(), [
        1.0,
        2.0,
        3.0,
      ]);

      await b.commit(const []);
      expect(await b.readPending(), isEmpty);
    },
  );

  test('caps at maxSamples and evicts the oldest', () async {
    final b = await newBuffer();
    for (var i = 0; i < TrackingBuffer.maxSamples + 5; i++) {
      await b.add({'latitude': i.toDouble()});
    }
    final drained = await b.readPending();
    expect(drained.length, TrackingBuffer.maxSamples);
    expect(drained.first.sample['latitude'], 5.0);
    expect(
      drained.last.sample['latitude'],
      (TrackingBuffer.maxSamples + 4).toDouble(),
    );
  });

  test('commit keeps only the unsent remainder for the next flush', () async {
    final b = await newBuffer();
    await b.add({'latitude': 1.0});
    await b.add({'latitude': 2.0});
    await b.add({'latitude': 3.0});

    final drained = await b.readPending();
    await b.commit(drained.sublist(2));

    // A brand new instance (as the next flush pass would use) sees the
    // remainder, plus anything appended after the drain.
    final reader = await newBuffer();
    await b.add({'latitude': 4.0});
    final remaining = await reader.readPending();
    expect(remaining.map((s) => s.sample['latitude']).toList(), [3.0, 4.0]);
  });

  test('samples appended by a separate writer instance are visible', () async {
    // Two instances over the same directory stand in for the two isolates:
    // the background service appends, the main isolate drains.
    final writer = await newBuffer();
    final reader = await newBuffer();

    await writer.add({'latitude': 9.0});
    await writer.add({'latitude': 10.0});

    final drained = await reader.readPending();
    expect(drained.map((s) => s.sample['latitude']).toList(), [9.0, 10.0]);

    // The reader's drain must not drop a concurrently appended sample.
    await reader.commit(const []);
    await writer.add({'latitude': 11.0});
    final next = await reader.readPending();
    expect(next.map((s) => s.sample['latitude']).toList(), [11.0]);
  });

  test('clear removes buffered samples', () async {
    final b = await newBuffer();
    await b.add({'latitude': 1.0});
    await b.clear();
    expect(await b.readPending(), isEmpty);
  });

  test('records the capturing guard and origin with each sample', () async {
    final b = await newBuffer();
    await b.add(
      {'latitude': 1.0},
      owner: 'employee-doc-a',
      origin: 'https://cisskerala.site/',
    );

    final drained = await b.readPending();
    expect(drained.single.owner, 'employee-doc-a');
    expect(drained.single.origin, 'https://cisskerala.site/');
    expect(
      drained.single.belongsTo(
        owner: 'employee-doc-a',
        origin: 'https://cisskerala.site',
      ),
      isTrue,
      reason: 'A trailing slash on either side must not change the origin',
    );
    expect(
      drained.single.belongsTo(
        owner: 'employee-doc-b',
        origin: 'https://cisskerala.site',
      ),
      isFalse,
    );
    expect(
      drained.single.belongsTo(
        owner: 'employee-doc-a',
        origin: 'https://other.example',
      ),
      isFalse,
    );
  });

  test('a sample without an envelope is never attributable', () async {
    final b = await newBuffer();
    // A bare row, as written before the envelope existed.
    await b.add({'latitude': 1.0});

    final drained = await b.readPending();
    expect(drained.single.isAttributed, isFalse);
    expect(
      drained.single.belongsTo(
        owner: 'employee-doc-a',
        origin: 'https://cisskerala.site',
      ),
      isFalse,
    );
  });

  test('committing keeps unattributed rows in the spool', () async {
    final b = await newBuffer();
    await b.add(
      {'latitude': 1.0},
      owner: 'employee-doc-a',
      origin: 'https://cisskerala.site',
    );
    await b.add({'latitude': 2.0});

    final drained = await b.readPending();
    await b.commit(<TrackingSpoolEntry>[drained.last]);

    final remaining = await b.readPending();
    expect(remaining.single.sample['latitude'], 2.0);
    expect(remaining.single.isAttributed, isFalse);
  });
}
