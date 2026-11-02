import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/cache/read_cache.dart';

void main() {
  group('ReadCache (JSON + store)', () {
    test('setJson then readJson returns the value from memory', () async {
      final cache = ReadCache();
      cache.setJson('k', <String, dynamic>{'a': 1});
      expect(cache.peekJson('k'), <String, dynamic>{'a': 1});
      expect(await cache.readJson('k'), <String, dynamic>{'a': 1});
      expect(cache.has('k'), isTrue);
    });

    test('readJson falls back to a timestamped persisted entry', () async {
      final store = MemoryReadCacheStore();
      final cache = ReadCache(store: store);

      // Simulate a different session having persisted the value.
      await store.write(
        'k',
        '{"fetchedAt":"2026-01-01T00:00:00.000Z","value":{"b":2}}',
      );

      expect(cache.peekJson('k'), isNull);
      final loaded = await cache.readJson('k');
      expect(loaded, <String, dynamic>{'b': 2});
      // Now backed by memory too.
      expect(cache.peekJson('k'), <String, dynamic>{'b': 2});
    });

    test('legacy un-timestamped persisted entries are treated as misses',
        () async {
      final store = MemoryReadCacheStore();
      final cache = ReadCache(store: store);
      // Format written by the pre-fix build (raw payload, no fetch timestamp).
      await store.write('k', '{"b":2}');

      expect(await cache.readJson('k'), isNull);
      expect(cache.peekJson('k'), isNull);
    });

    test('readJson returns null for a missing key', () async {
      final cache = ReadCache();
      expect(await cache.readJson('nope'), isNull);
      expect(cache.peekJson('nope'), isNull);
    });

    test('isFresh respects the TTL window', () {
      var now = DateTime(2026, 1, 1);
      final cache = ReadCache(now: () => now);
      cache.setJson('k', <String, dynamic>{'x': 1});
      expect(cache.isFresh('k'), isTrue);

      now = now.add(const Duration(minutes: 6));
      expect(cache.isFresh('k'), isFalse);
    });

    test('readJson enforces a maximum fallback age', () async {
      var now = DateTime.utc(2026, 1, 1);
      final cache = ReadCache(now: () => now);
      cache.setJson('k', <String, dynamic>{'x': 1});

      now = now.add(const Duration(hours: 23));
      expect(
        await cache.readJson('k', maxAge: ReadCache.maxFallbackAge),
        <String, dynamic>{'x': 1},
      );

      now = now.add(const Duration(hours: 2));
      expect(
        await cache.readJson('k', maxAge: ReadCache.maxFallbackAge),
        isNull,
      );
      // An expired value is evicted, not merely hidden.
      expect(cache.has('k'), isFalse);
    });

    test('max fallback age applies to persisted entries too', () async {
      final store = MemoryReadCacheStore();
      final now = DateTime.utc(2026, 1, 2, 12);
      await store.write(
        'k',
        '{"fetchedAt":"2026-01-01T00:00:00.000Z","value":{"x":1}}',
      );
      final cache = ReadCache(now: () => now, store: store);

      expect(
        await cache.readJson('k', maxAge: ReadCache.maxFallbackAge),
        isNull,
      );
    });

    test('invalidate removes from memory and the durable store', () async {
      final store = MemoryReadCacheStore();
      final cache = ReadCache(store: store);
      cache.setJson('k', <String, dynamic>{'x': 1});
      // setJson persists fire-and-forget; let the microtask complete.
      await Future<void>.delayed(Duration.zero);
      expect(await store.read('k'), isNotNull);

      cache.invalidate('k');
      await Future<void>.delayed(Duration.zero);
      expect(cache.has('k'), isFalse);
      expect(await store.read('k'), isNull);
    });

    test('clear empties memory and the durable store', () async {
      final store = MemoryReadCacheStore();
      final cache = ReadCache(store: store);
      cache.setJson('a', <String, dynamic>{'x': 1});
      cache.setJson('b', <String, dynamic>{'y': 2});

      await cache.clear();
      expect(cache.length, 0);
      expect(await store.read('a'), isNull);
    });

    test('store failures degrade to in-memory only', () async {
      final cache = ReadCache(store: _ThrowingStore());
      cache.setJson('k', <String, dynamic>{'safe': true});
      // setJson did not throw; memory copy is available.
      expect(cache.peekJson('k'), <String, dynamic>{'safe': true});
    });
  });
}

class _ThrowingStore implements ReadCacheStore {
  @override
  Future<String?> read(String key) async => throw StateError('no store');

  @override
  Future<void> write(String key, String value) async =>
      throw StateError('no store');

  @override
  Future<void> delete(String key) async => throw StateError('no store');

  @override
  Future<void> clear() async => throw StateError('no store');
}
