import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'offline_request.dart';

class OfflineQueue extends ChangeNotifier {
  static const String boxName = 'offline_queue';
  static const String _keyName = 'hive_encryption_key';
  static const int _maxQueueSize = 100;
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

  int get failedCount => getQueuedRequests().where((r) => r.retryCount >= 15).length;

  int get pendingCount => getQueuedRequests().where((r) => r.retryCount < 15).length;

  Future<String> enqueue({
    required String path,
    required String method,
    required Map<String, dynamic> body,
  }) async {
    // Enforce max queue size: drop oldest items when limit exceeded
    if (_box.length >= _maxQueueSize) {
      final sorted = getQueuedRequests();
      final toRemove = sorted.length - _maxQueueSize + 1;
      for (var i = 0; i < toRemove; i++) {
        await _box.delete(sorted[i].id);
      }
    }

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
    return id;
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

  Future<void> retryFailedRequests() async {
    final requests = getQueuedRequests();
    for (final request in requests) {
      if (request.retryCount >= 15) {
        await updateRequest(request.copyWith(retryCount: 0));
      }
    }
  }

  Future<void> clearFailedRequests() async {
    final requests = getQueuedRequests();
    for (final request in requests) {
      if (request.retryCount >= 15) {
        await removeRequest(request.id);
      }
    }
  }

  Future<void> clear() async {
    await _box.clear();
    notifyListeners();
  }
}
