import 'package:ciss_mobile/core/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncService.chunked', () {
    test('splits a large batch into size-capped chunks', () {
      final items = List<int>.generate(500, (i) => i);
      final chunks = SyncService.chunked(items, 200).toList();
      expect(chunks.map((c) => c.length).toList(), [200, 200, 100]);
      expect(chunks.first.first, 0);
      expect(chunks.last.last, 499);
    });

    test('returns a single chunk when the batch fits', () {
      final chunks = SyncService.chunked([1, 2, 3], 200).toList();
      expect(chunks, [
        [1, 2, 3],
      ]);
    });

    test('returns nothing for an empty batch', () {
      expect(SyncService.chunked(const <int>[], 200), isEmpty);
    });
  });
}
