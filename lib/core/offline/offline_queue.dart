import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'offline_request.dart';

/// Raised when the durable offline queue cannot be used safely.
///
/// The queue is encrypted with an AES key held in platform secure storage. If
/// that key cannot be read or created, the queue must **not** fall back to an
/// unencrypted box: callers get this typed error instead of silently persisting
/// attendance payloads, photos, and other sensitive request data in plaintext.
abstract class OfflineQueueError implements Exception {
  const OfflineQueueError(this.message);

  final String message;

  @override
  String toString() => message;
}

class OfflineQueueUnavailableError extends OfflineQueueError {
  const OfflineQueueUnavailableError([
    super.message =
        'Offline storage is unavailable. This entry was not saved.',
  ]);
}

/// Raised when the encrypted queue is at capacity.
///
/// The queue no longer deletes the oldest entry to make room: that silently
/// destroyed unsynced work (including blocked entries kept for inspection).
/// Callers must tell the user that this submission was not queued.
class OfflineQueueFullError extends OfflineQueueError {
  const OfflineQueueFullError([
    super.message =
        'The offline queue is full. Connect to the network so pending entries can sync before adding another.',
  ]);
}

/// The account changed between the caller enqueueing and the serialized write.
/// Refusing is safer than labelling one account's payload as another's.
/// A non-public action was queued while signed out. It could never be replayed
/// under a real account and would occupy a queue slot forever.
class OfflineQueueAnonymousError extends OfflineQueueError {
  const OfflineQueueAnonymousError([
    super.message =
        'Sign in to save this action for offline sync. It was not queued.',
  ]);
}

class OfflineQueueOwnerChangedError extends OfflineQueueError {
  const OfflineQueueOwnerChangedError([
    super.message =
        'The signed-in account changed. This entry was not saved to the offline queue.',
  ]);
}

class OfflineQueue extends ChangeNotifier {
  static const String boxName = 'offline_queue';
  static const String _keyName = 'hive_encryption_key';

  /// Owner recorded for requests queued while no account is signed in (e.g.
  /// the public attendance submission flow, which is replayed without a
  /// bearer token).
  static const String anonymousOwnerUid = 'anonymous';

  final _uuid = const Uuid();
  final _secureStorage = const FlutterSecureStorage();

  /// Incremented on every ownership transition so a deferred enqueue can tell
  /// that it was scheduled under a different account.
  int _ownerGeneration = 0;

  /// Account that queued the entries currently in the box. Wired from the auth
  /// session lifecycle. `null` means no account is active; only entries in the
  /// [anonymousOwnerUid] bucket are eligible for replay in that state.
  String? _ownerUid;

  String? get ownerUid => _ownerUid;

  String get _effectiveOwner => _ownerUid ?? anonymousOwnerUid;

  /// Whether [request] may be replayed in the current session.
  ///
  /// Eligible: entries owned by the active account, plus unauthenticated public
  /// attendance submissions. Those carry their own verification proof and are
  /// sent without a bearer token, so keeping them replayable after another
  /// account signs in (NEW-03) both drains them and keeps the account boundary
  /// for real uids intact.
  bool _isReplayable(OfflineRequest request) =>
      request.uid == _effectiveOwner ||
      (request.uid == anonymousOwnerUid && request.isPublicAttendance);

  /// Reads (or creates) the AES key used for the queue box.
  ///
  /// Throws [OfflineQueueUnavailableError] when secure storage is unavailable;
  /// callers must then leave the queue closed. Never returns `null`: an
  /// unencrypted queue is not an acceptable fallback.
  Future<HiveAesCipher> getEncryptionCipher() async {
    try {
      final String? key = await _secureStorage.read(key: _keyName);
      if (key == null) {
        final newKey = Hive.generateSecureKey();
        await _secureStorage.write(
          key: _keyName,
          value: base64UrlEncode(newKey),
        );
        return HiveAesCipher(newKey);
      }
      final decoded = base64Url.decode(key);
      return HiveAesCipher(decoded);
    } catch (error) {
      // Never log the key or the exception message (it can embed storage paths).
      debugPrint(
        'OfflineQueue: secure storage unavailable, refusing to open '
        'unencrypted (${error.runtimeType})',
      );
      throw const OfflineQueueUnavailableError(
        'Offline storage could not be secured. Entries are not saved.',
      );
    }
  }

  /// Opens the queue with its AES cipher. Throws
  /// [OfflineQueueUnavailableError] instead of opening an unencrypted box.
  Future<void> init() async {
    if (isInitialized) return;
    final cipher = await getEncryptionCipher();
    try {
      await Hive.openBox<Map>(boxName, encryptionCipher: cipher);
    } catch (error) {
      debugPrint(
        'OfflineQueue: encrypted box unavailable (${error.runtimeType})',
      );
      throw const OfflineQueueUnavailableError();
    }
  }

  Box<Map> get _box {
    if (!Hive.isBoxOpen(boxName)) {
      throw const OfflineQueueUnavailableError(
        'OfflineQueue not initialized. Call init() first.',
      );
    }
    return Hive.box<Map>(boxName);
  }

  /// Whether the persistent queue has been opened by app bootstrap.
  ///
  /// Widgets can be built while startup is still recovering from a storage
  /// or encryption error. Reading the queue count must not crash the whole
  /// screen in that window; mutating operations still fail loudly until the
  /// queue is initialized.
  bool get isInitialized => Hive.isBoxOpen(boxName);

  int get queueSize => isInitialized ? _box.length : 0;

  static const int maxQueueSize = 100;

  /// Number of entries dropped to honour [maxQueueSize] since this process
  /// started. Eviction is still automatic (rejecting new writes would throw
  /// from 10+ unguarded call sites), but it is now countable and surfaced in
  /// `SyncStatusBadge` instead of being a `debugPrint`-only event.
  int _evictedCount = 0;

  int get evictedCount => _evictedCount;

  DateTime? _lastEvictionAt;

  DateTime? get lastEvictionAt => _lastEvictionAt;

  /// Entries owned by the active account that are eligible for replay.
  int get pendingCount => _countOwned(blocked: false);

  /// Entries owned by the active account that exhausted their retries. They are
  /// kept on disk so no queued work is silently discarded.
  int get blockedCount => _countOwned(blocked: true);

  int _countOwned({required bool blocked}) {
    if (!isInitialized) return 0;
    var count = 0;
    for (final value in _box.values) {
      try {
        final request = OfflineRequest.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (!_isReplayable(request) || request.blocked != blocked) {
          continue;
        }
        count += 1;
      } catch (_) {
        // Corrupted entries are purged by getQueuedRequests/purgeForeignRequests.
      }
    }
    return count;
  }

  /// Synchronously stops replay for the current owner without touching disk.
  ///
  /// Used the moment the Firebase identity changes so a flush that races with
  /// the (asynchronous) purge can never submit the previous account's queued
  /// requests under the new account's token.
  void detachOwner() {
    _ownerUid = null;
    _ownerGeneration += 1;
  }

  /// Adopts [uid] as the active queue owner. Entries belonging to any other
  /// account (or legacy entries with no owner) are purged rather than replayed;
  /// the [anonymousOwnerUid] bucket survives so unauthenticated public
  /// attendance submissions are not lost when an account signs in.
  Future<void> setOwner(String? uid) async {
    if (_ownerUid == uid) return;
    _ownerUid = uid;
    _ownerGeneration += 1;
    if (!isInitialized) return;
    await purgeForeignRequests();
  }

  Future<void> _enqueueTail = Future<void>.value();

  /// Adds an entry, or throws [OfflineQueueFullError] at capacity.
  ///
  /// Enqueues are serialized so two concurrent callers cannot both pass the
  /// capacity check. Existing entries are never deleted to make room.
  Future<void> enqueue({
    required String path,
    required String method,
    required Map<String, dynamic> body,
  }) {
    // Capture identity synchronously; the box write runs later on the
    // serialized tail and must not adopt a different account in the meantime.
    final owner = _effectiveOwner;
    final generation = _ownerGeneration;
    final operation = _enqueueTail.then(
      (_) => _enqueueNow(
        path: path,
        method: method,
        body: body,
        owner: owner,
        generation: generation,
      ),
    );
    // Keep the chain alive after a failed enqueue; the caller still receives
    // the original error through [operation].
    _enqueueTail = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  static bool _isPublicPayload(String path, Map<String, dynamic> body) {
    if (path != '/api/attendance/submit') return false;
    final token = body['attendanceVerificationToken'];
    return token is String && token.trim().isNotEmpty;
  }

  Future<void> _enqueueNow({
    required String path,
    required String method,
    required Map<String, dynamic> body,
    required String owner,
    required int generation,
  }) async {
    if (!isInitialized) {
      throw const OfflineQueueUnavailableError();
    }
    if (generation != _ownerGeneration || _effectiveOwner != owner) {
      throw const OfflineQueueOwnerChangedError();
    }
    if (owner == anonymousOwnerUid && !_isPublicPayload(path, body)) {
      throw const OfflineQueueAnonymousError();
    }
    if (_box.length >= maxQueueSize) {
      throw const OfflineQueueFullError();
    }
    final id = _uuid.v4();
    final request = OfflineRequest(
      id: id,
      path: path,
      method: method,
      body: body,
      createdAt: DateTime.now(),
      uid: owner,
    );
    await _box.put(id, request.toJson());
    notifyListeners();
  }

  /// Requests that may be replayed in the current session, oldest first.
  ///
  /// Foreign/legacy entries are excluded immediately and purged in the
  /// background, so a request queued by account A can never be submitted under
  /// account B's token.
  List<OfflineRequest> getQueuedRequests() {
    if (!isInitialized) return const <OfflineRequest>[];
    final requests = <OfflineRequest>[];
    var purgedAny = false;
    for (final entry in _box.toMap().entries) {
      try {
        final request = OfflineRequest.fromJson(
          Map<String, dynamic>.from(entry.value),
        );
        if (!_isReplayable(request)) {
          purgedAny = true;
          continue;
        }
        requests.add(request);
      } catch (e) {
        purgedAny = true;
        debugPrint('Skipping corrupted offline queue entry (${e.runtimeType})');
      }
    }
    if (purgedAny) {
      unawaited(purgeForeignRequests());
    }
    requests.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return requests;
  }

  /// Deletes every entry that belongs to another identity, including legacy
  /// entries whose uid is absent and corrupted entries.
  ///
  /// The [anonymousOwnerUid] bucket is kept only for replayable public
  /// attendance. A non-public entry that was queued while signed out can never
  /// be replayed under a real account, so it is removed instead of occupying a
  /// slot forever.
  Future<void> purgeForeignRequests() async {
    if (!isInitialized) return;
    final effectiveOwner = _effectiveOwner;
    final toDelete = <dynamic>[];
    for (final entry in _box.toMap().entries) {
      try {
        final request = OfflineRequest.fromJson(
          Map<String, dynamic>.from(entry.value),
        );
        if (request.uid == anonymousOwnerUid) {
          if (!request.isPublicAttendance) toDelete.add(entry.key);
          continue;
        }
        if (request.uid != effectiveOwner) toDelete.add(entry.key);
      } catch (_) {
        toDelete.add(entry.key);
      }
    }
    if (toDelete.isEmpty) return;
    await _box.deleteAll(toDelete);
    debugPrint(
      'OfflineQueue: purged ${toDelete.length} request(s) not owned by the '
      'active session',
    );
    notifyListeners();
  }

  Future<void> removeRequest(String id) async {
    if (!isInitialized) return;
    await _box.delete(id);
    notifyListeners();
  }

  Future<void> updateRequest(OfflineRequest request) async {
    if (!isInitialized) return;
    await _box.put(request.id, request.toJson());
    notifyListeners();
  }

  Future<void> clear() async {
    if (!isInitialized) return;
    await _box.clear();
    // A purge ends the previous account's queue history; do not show its
    // evictions to the next session.
    _evictedCount = 0;
    _lastEvictionAt = null;
    notifyListeners();
  }
}
