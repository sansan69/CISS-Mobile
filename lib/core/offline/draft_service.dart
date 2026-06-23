import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DraftService extends ChangeNotifier {
  static const String boxName = 'draft_box';

  static Future<void> init() async {
    // Note: This box is NOT encrypted by default to keep it fast, 
    // but we could use the same cipher if needed.
    await Hive.openBox<Map>(boxName);
  }

  Box<Map> get _box {
    if (!Hive.isBoxOpen(boxName)) {
      throw StateError('DraftService not initialized. Call init() first.');
    }
    return Hive.box<Map>(boxName);
  }

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

  bool hasDraft(String formKey) {
    return _box.containsKey(formKey);
  }
}

final draftServiceProvider = ChangeNotifierProvider<DraftService>((ref) => DraftService());
