// lib/core/settings/remote_config_store.dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'remote_config.dart';

class RemoteConfigStore {
  static const String boxName = 'remote_config';

  Future<void> init(HiveAesCipher? cipher) async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<Map>(boxName, encryptionCipher: cipher);
    }
  }

  static String keyFor(String regionCode, String role) => '$regionCode:$role';

  Box<Map> get _box {
    if (!Hive.isBoxOpen(boxName)) {
      throw StateError('RemoteConfigStore not initialized. Call init() first.');
    }
    return Hive.box(boxName);
  }

  RemoteConfig? read(String key) {
    if (!Hive.isBoxOpen(boxName)) return null;
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(raw);
      final fetchedAt = DateTime.tryParse(map['fetchedAt']?.toString() ?? '');
      return RemoteConfig.fromJson(map, fetchedAt: fetchedAt);
    } catch (e) {
      debugPrint('RemoteConfigStore: corrupt entry for $key — $e');
      return null;
    }
  }

  Future<void> write(String key, RemoteConfig cfg) => _box.put(key, cfg.toJson());
}
