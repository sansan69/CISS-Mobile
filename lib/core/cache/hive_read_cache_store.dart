import 'package:hive/hive.dart';

import 'read_cache.dart';

/// [ReadCacheStore] backed by a lazily-opened Hive box.
///
/// The box is opened on first use (so no `main()` wiring change is required;
/// `Hive.initFlutter()` already runs at startup). Every operation is guarded so
/// a misconfigured/unavailable box degrades to a no-op rather than breaking the
/// request being served.
class HiveReadCacheStore implements ReadCacheStore {
  HiveReadCacheStore({this.boxName = 'read_cache'});

  final String boxName;
  Box<dynamic>? _box;

  Future<Box<dynamic>?> _open() async {
    if (_box != null) return _box;
    try {
      final box = await Hive.openBox<dynamic>(boxName);
      _box = box;
      return box;
    } catch (_) {
      // Hive not initialized / unavailable — degrade to a miss.
      return null;
    }
  }

  @override
  Future<String?> read(String key) async {
    final box = await _open();
    if (box == null) return null;
    final value = box.get(key);
    return value is String ? value : null;
  }

  @override
  Future<void> write(String key, String value) async {
    final box = await _open();
    if (box == null) return;
    try {
      await box.put(key, value);
    } catch (_) {
      // Durability is best-effort.
    }
  }

  @override
  Future<void> delete(String key) async {
    final box = await _open();
    if (box == null) return;
    try {
      await box.delete(key);
    } catch (_) {
      // Ignore.
    }
  }

  @override
  Future<void> clear() async {
    final box = await _open();
    if (box == null) return;
    try {
      await box.clear();
    } catch (_) {
      // Ignore.
    }
  }
}
