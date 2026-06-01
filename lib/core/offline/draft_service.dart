import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DraftService extends ChangeNotifier {
  static const String boxName = 'draft_box';
  static const String _keyName = 'draft_encryption_key';
  static final _secureStorage = const FlutterSecureStorage();

  static Future<void> init() async {
    String? key = await _secureStorage.read(key: _keyName);
    HiveAesCipher? cipher;
    if (key == null) {
      final newKey = Hive.generateSecureKey();
      await _secureStorage.write(key: _keyName, value: base64UrlEncode(newKey));
      cipher = HiveAesCipher(newKey);
    } else {
      cipher = HiveAesCipher(base64Url.decode(key));
    }
    await Hive.openBox<Map>(boxName, encryptionCipher: cipher);
  }

  Box<Map> get _box => Hive.box<Map>(boxName);

  Future<void> saveDraft(String formKey, Map<String, dynamic> data) async {
    await _box.put(formKey, data);
    notifyListeners();
  }

  Map<String, dynamic>? getDraft(String formKey) {
    final data = _box.get(formKey);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<void> clearDraft(String formKey) async {
    await _box.delete(formKey);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _box.clear();
    notifyListeners();
  }

  bool hasDraft(String formKey) {
    return _box.containsKey(formKey);
  }
}

final draftServiceProvider = Provider((ref) => DraftService());
