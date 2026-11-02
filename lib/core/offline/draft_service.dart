import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Account-scoped, local draft storage.
///
/// Keys are namespaced with the active account uid (`uid::formKey`) so a draft
/// written by guard A can never auto-restore into guard B's form on a shared
/// device. Changing the owner clears the box: switching accounts wipes any
/// draft the previous account left behind. Writes made while no account is
/// active are not persisted (an ownerless draft would be cross-account data).
class DraftService extends ChangeNotifier {
  static const String boxName = 'draft_box';

  static const String _namespaceSeparator = '::';

  String? _ownerUid;

  String? get ownerUid => _ownerUid;

  bool get isInitialized => Hive.isBoxOpen(boxName);

  /// Test-only unencrypted open. Production must call [openEncrypted].
  @visibleForTesting
  static Future<void> init() async {
    await Hive.openBox<Map>(boxName);
  }

  /// Opens the draft box with the same AES cipher as the offline queue.
  ///
  /// Drafts contain incident/visit text and must never sit in plaintext on a
  /// shared device. A legacy plaintext box cannot be opened with a cipher, so
  /// it is discarded (drafts are disposable) and recreated encrypted. Callers
  /// that cannot provide a cipher must leave drafts disabled rather than fall
  /// back to plaintext.
  static Future<void> openEncrypted(HiveAesCipher cipher) async {
    try {
      await Hive.openBox<Map>(boxName, encryptionCipher: cipher);
      return;
    } catch (_) {
      // Old plaintext box (or a cipher from a previous install); discard it.
    }
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box<Map>(boxName).close();
    }
    await Hive.deleteBoxFromDisk(boxName);
    await Hive.openBox<Map>(boxName, encryptionCipher: cipher);
  }

  Box<Map> get _box {
    if (!isInitialized) {
      throw StateError('DraftService not initialized. Call init() first.');
    }
    return Hive.box<Map>(boxName);
  }

  /// Adopts [uid] as the active draft owner.
  ///
  /// Drafts belonging to any other account — including legacy global keys and
  /// drafts from a previous account on this device — are deleted, so switching
  /// accounts can never restore the previous account's text. Signing out
  /// (`uid == null`) clears every draft.
  Future<void> setOwner(String? uid) async {
    if (_ownerUid == uid) return;
    _ownerUid = uid;
    if (!isInitialized) return;
    if (uid == null) {
      await clearAll();
      return;
    }
    await _purgeForeignDrafts(uid);
  }

  Future<void> _purgeForeignDrafts(String uid) async {
    final prefix = '$uid$_namespaceSeparator';
    final foreignKeys = _box.keys
        .whereType<String>()
        .where((key) => !key.startsWith(prefix))
        .toList(growable: false);
    if (foreignKeys.isEmpty) return;
    await _box.deleteAll(foreignKeys);
    notifyListeners();
  }

  String _namespacedKey(String formKey) =>
      '$_ownerUid$_namespaceSeparator$formKey';

  Future<void> saveDraft(String formKey, Map<String, dynamic> data) async {
    if (!isInitialized) {
      // Draft storage is optional and may be disabled when secure storage is
      // unavailable. Never throw from a text-listener; just drop the draft.
      debugPrint('DraftService: storage unavailable — draft not persisted');
      return;
    }
    if (_ownerUid == null) {
      // No active account: persisting here would show the draft to whoever
      // signs in next. Keep it out of the box entirely.
      debugPrint('DraftService: no active account — draft not persisted');
      return;
    }
    await _box.put(_namespacedKey(formKey), data);
    notifyListeners();
  }

  Map<String, dynamic>? getDraft(String formKey) {
    if (!isInitialized || _ownerUid == null) return null;
    final data = _box.get(_namespacedKey(formKey));
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<void> clearDraft(String formKey) async {
    if (!isInitialized || _ownerUid == null) return;
    await _box.delete(_namespacedKey(formKey));
    notifyListeners();
  }

  bool hasDraft(String formKey) {
    if (!isInitialized || _ownerUid == null) return false;
    return _box.containsKey(_namespacedKey(formKey));
  }

  /// Removes every draft for every account. Used on sign-out/account change and
  /// by the local-data purger.
  Future<void> clearAll() async {
    if (!isInitialized) return;
    await _box.clear();
    notifyListeners();
  }
}

final draftServiceProvider = ChangeNotifierProvider<DraftService>((ref) => DraftService());
