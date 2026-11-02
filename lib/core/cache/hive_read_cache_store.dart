import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'read_cache.dart';

/// [ReadCacheStore] backed by the `read_cache` Hive box.
///
/// The box is opened by app bootstrap (`main.dart`) with the same AES cipher as
/// the offline queue. This store deliberately **never opens the box itself**:
/// if the box is not already open (bootstrap failed, secure-storage key is
/// unavailable, or this is a unit-test process) every operation degrades to a
/// miss instead of creating a plaintext cache on disk. The cached payloads are
/// disposable, so losing them is always preferable to persisting them
/// unencrypted.
class HiveReadCacheStore implements ReadCacheStore {
  HiveReadCacheStore({this.boxName = defaultBoxName, Box<dynamic>? box})
    : _box = box;

  static const String defaultBoxName = 'read_cache';

  final String boxName;
  Box<dynamic>? _box;

  Box<dynamic>? _open() {
    final current = _box;
    if (current != null && current.isOpen) return current;
    if (!Hive.isBoxOpen(boxName)) return null;
    final box = Hive.box<dynamic>(boxName);
    _box = box;
    return box;
  }

  @override
  Future<String?> read(String key) async {
    final box = _open();
    if (box == null) return null;
    try {
      final value = box.get(key);
      return value is String ? value : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    final box = _open();
    if (box == null) return;
    try {
      await box.put(key, value);
    } catch (_) {
      // Durability is best-effort.
    }
  }

  @override
  Future<void> delete(String key) async {
    final box = _open();
    if (box == null) return;
    try {
      await box.delete(key);
    } catch (_) {
      // Ignore.
    }
  }

  @override
  Future<void> clear() async {
    final box = _open();
    if (box == null) return;
    try {
      await box.clear();
    } catch (_) {
      // Ignore.
    }
  }
}

/// Process-wide read cache used by [MobileRepository] and the local-data
/// purger, so clearing one clears both the in-memory view and the encrypted
/// box. Tests inject their own [ReadCache] into the repository instead.
final ReadCache sharedReadCache = ReadCache(store: HiveReadCacheStore());

/// Exposes [sharedReadCache] to the local-data purger.
final Provider<ReadCache> readCacheProvider = Provider<ReadCache>(
  (Ref ref) => sharedReadCache,
);
