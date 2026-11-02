import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_session.dart';

/// A persisted, uid-bound copy of the last authoritative mobile session.
class SessionSnapshot {
  const SessionSnapshot({required this.session, required this.savedAt});

  final AuthSession session;
  final DateTime savedAt;
}

/// Minimal key/value contract so the snapshot store can be unit-tested without
/// a platform channel.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Keychain/Keystore-backed implementation.
///
/// `first_unlock_this_device` is required so the snapshot can be read by the
/// app while the device is locked after a reboot (unattended flush) but is
/// never synced or migrated to another device.
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const IOSOptions _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key, iOptions: _iosOptions);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value, iOptions: _iosOptions);

  @override
  Future<void> delete(String key) =>
      _storage.delete(key: key, iOptions: _iosOptions);
}

/// Stores the last authoritative [AuthSession] in platform secure storage.
///
/// The snapshot is a bounded offline grace credential for *display and
/// navigation only*: it is written after a successful
/// `GET /api/mobile/session`, bound to the Firebase uid that resolved it, and
/// expires after [maxAge]. It is never used to re-authorize writes — those
/// still go through the backend.
///
/// Every storage operation is best-effort: an unavailable keychain must not
/// break sign-in, session refresh, or sign-out. Corrupt, expired, foreign and
/// timestamp-in-the-future entries are deleted on read and reported as `null`.
class SessionSnapshotStore {
  SessionSnapshotStore({
    SecureKeyValueStore? storage,
    DateTime Function()? now,
  }) : _storage = storage ?? const FlutterSecureKeyValueStore(),
       _now = now ?? DateTime.now;

  static const String storageKey = 'ciss_session_snapshot_v1';
  static const Duration maxAge = Duration(hours: 24);

  /// Tolerance for small clock skew when validating `savedAt`.
  static const Duration _futureTolerance = Duration(minutes: 5);

  final SecureKeyValueStore _storage;
  final DateTime Function() _now;

  Future<void> save(AuthSession session) async {
    if (session.uid.trim().isEmpty || session.offline) return;
    try {
      final payload = <String, dynamic>{
        'session': session.toJson(),
        'savedAt': _now().toUtc().toIso8601String(),
      };
      await _storage.write(storageKey, jsonEncode(payload));
    } catch (error) {
      debugPrint(
        'SessionSnapshotStore: save failed (${error.runtimeType})',
      );
    }
  }

  /// Returns the snapshot when it is unexpired and belongs to [uid].
  Future<SessionSnapshot?> load(String uid) async {
    final expectedUid = uid.trim();
    if (expectedUid.isEmpty) return null;

    String? raw;
    try {
      raw = await _storage.read(storageKey);
    } catch (error) {
      debugPrint(
        'SessionSnapshotStore: read failed (${error.runtimeType})',
      );
      return null;
    }
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await clear();
        return null;
      }
      final payload = Map<String, dynamic>.from(decoded);
      final sessionRaw = payload['session'];
      final savedAtRaw = payload['savedAt'];
      if (sessionRaw is! Map || savedAtRaw is! String) {
        await clear();
        return null;
      }
      final session = AuthSession.fromJson(
        Map<String, dynamic>.from(sessionRaw),
      );
      final savedAt = DateTime.tryParse(savedAtRaw);
      if (session == null || savedAt == null) {
        await clear();
        return null;
      }
      final nowUtc = _now().toUtc();
      final savedAtUtc = savedAt.toUtc();
      // A snapshot bound to another account is not this account's grace state.
      if (session.uid != expectedUid) {
        await clear();
        return null;
      }
      if (savedAtUtc.isAfter(nowUtc.add(_futureTolerance)) ||
          nowUtc.difference(savedAtUtc) > maxAge) {
        await clear();
        return null;
      }
      return SessionSnapshot(session: session, savedAt: savedAtUtc);
    } catch (error) {
      debugPrint(
        'SessionSnapshotStore: corrupt snapshot discarded '
        '(${error.runtimeType})',
      );
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(storageKey);
    } catch (error) {
      debugPrint(
        'SessionSnapshotStore: clear failed (${error.runtimeType})',
      );
    }
  }
}

final Provider<SessionSnapshotStore> sessionSnapshotStoreProvider =
    Provider<SessionSnapshotStore>((Ref ref) => SessionSnapshotStore());
