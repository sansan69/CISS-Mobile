import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'offline_request.dart';

class OfflineQueue extends ChangeNotifier {
  static const String boxName = 'offline_queue';
  static const String _keyName = 'hive_encryption_key';
  final _uuid = const Uuid();
  final _secureStorage = const FlutterSecureStorage();

  Future<HiveAesCipher?> getEncryptionCipher() async {
    String? key = await _secureStorage.read(key: _keyName);
    if (key == null) {
      final newKey = Hive.generateSecureKey();
      await _secureStorage.write(key: _keyName, value: base64UrlEncode(newKey));
      return HiveAesCipher(newKey);
    }
    return HiveAesCipher(base64Url.decode(key));
  }

  Future<void> init() async {
    final cipher = await getEncryptionCipher();
    await Hive.openBox<Map>(boxName, encryptionCipher: cipher);
  }

  Box<Map> get _box => Hive.box<Map>(boxName);

  int get queueSize => _box.length;

  Future<void> enqueue({
    required String path,
    required String method,
    required Map<String, dynamic> body,
  }) async {
    final id = _uuid.v4();
    final request = OfflineRequest(
      id: id,
      path: path,
      method: method,
      body: body,
      createdAt: DateTime.now(),
    );
    await _box.put(id, request.toJson());
    notifyListeners();
  }

  List<OfflineRequest> getQueuedRequests() {
    return _box.values
        .map((e) => OfflineRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> removeRequest(String id) async {
    await _box.delete(id);
    notifyListeners();
  }

  Future<void> updateRequest(OfflineRequest request) async {
    await _box.put(request.id, request.toJson());
    notifyListeners();
  }

  Future<void> clear() async {
    await _box.clear();
    notifyListeners();
  }
}
