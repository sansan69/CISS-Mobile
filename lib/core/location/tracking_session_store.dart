import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TrackingSessionStore {
  const TrackingSessionStore();

  static const String _storageKey = 'ciss_active_tracking_session_v1';
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<void> save(Map<String, dynamic> context) async {
    await _storage.write(key: _storageKey, value: jsonEncode(context));
  }

  Future<Map<String, dynamic>?> load() async {
    final encoded = await _storage.read(key: _storageKey);
    if (encoded == null || encoded.isEmpty) return null;

    try {
      final decoded = jsonDecode(encoded);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      await clear();
      return null;
    }
  }

  Future<void> clear() => _storage.delete(key: _storageKey);
}
