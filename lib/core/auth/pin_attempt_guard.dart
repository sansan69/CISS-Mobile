import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Client-side throttle for guard PIN sign-in.
///
/// This is defence in depth, not the authoritative control: the backend must
/// still rate-limit and lock out per employee and per IP. The local guard
/// prevents a lost/stolen phone from being used as an offline PIN oracle and
/// makes scripted attempts from the UI slow.
///
/// The identifier is hashed before it is persisted, so the cooldown store does
/// not become a list of employee IDs. Storage failures fail open (sign-in is
/// allowed) to avoid bricking the app; the server remains the source of truth.
class PinAttemptGuard {
  PinAttemptGuard({
    PinAttemptStore? store,
    DateTime Function()? now,
  }) : _store = store ?? const SecurePinAttemptStore(),
       _now = now ?? DateTime.now;

  final PinAttemptStore _store;
  final DateTime Function() _now;

  static const int _freeAttempts = 4;
  static const Duration _stateLifetime = Duration(hours: 24);

  Future<Duration> remainingCooldown(String loginId) async {
    final state = await _read(loginId);
    if (state == null || state.lockedUntil == null) {
      return Duration.zero;
    }
    final now = _now();
    if (!state.lockedUntil!.isAfter(now)) return Duration.zero;
    return state.lockedUntil!.difference(now);
  }

  /// Records a failed credential attempt and returns the cooldown now applied.
  Future<Duration> recordFailure(String loginId) async {
    final now = _now();
    final previous = await _read(loginId);
    var failures = previous?.failures ?? 0;
    final lastFailureAt = previous?.lastFailureAt;
    if (lastFailureAt == null ||
        now.difference(lastFailureAt) > _stateLifetime) {
      failures = 0;
    }
    failures += 1;
    final cooldown = cooldownForFailures(failures);
    final state = _PinAttemptState(
      failures: failures,
      lastFailureAt: now,
      lockedUntil: cooldown > Duration.zero ? now.add(cooldown) : null,
    );
    await _write(loginId, state);
    return cooldown;
  }

  Future<void> reset(String loginId) async {
    try {
      await _store.delete(_storageKey(loginId));
    } catch (error) {
      debugPrint('PinAttemptGuard: could not reset local attempt state: $error');
    }
  }

  Future<int> failuresFor(String loginId) async =>
      (await _read(loginId))?.failures ?? 0;

  /// 5th failure: 30 s, 6th: 1 min, 7th: 5 min, 8th: 15 min, 9+: 30 min.
  static Duration cooldownForFailures(int failures) {
    if (failures <= _freeAttempts) return Duration.zero;
    return switch (failures) {
      5 => const Duration(seconds: 30),
      6 => const Duration(minutes: 1),
      7 => const Duration(minutes: 5),
      8 => const Duration(minutes: 15),
      _ => const Duration(minutes: 30),
    };
  }

  static String formatCooldown(Duration duration) {
    final seconds = duration.inSeconds.clamp(1, 24 * 60 * 60);
    if (seconds < 60) return '$seconds second${seconds == 1 ? '' : 's'}';
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '$minutes minute${minutes == 1 ? '' : 's'}';
    final hours = (minutes / 60).ceil();
    return '$hours hour${hours == 1 ? '' : 's'}';
  }

  Future<_PinAttemptState?> _read(String loginId) async {
    try {
      final raw = await _store.read(_storageKey(loginId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return _PinAttemptState.fromJson(Map<String, dynamic>.from(decoded));
    } catch (error) {
      debugPrint('PinAttemptGuard: could not read local attempt state: $error');
      return null;
    }
  }

  Future<void> _write(String loginId, _PinAttemptState state) async {
    try {
      await _store.write(_storageKey(loginId), jsonEncode(state.toJson()));
    } catch (error) {
      debugPrint('PinAttemptGuard: could not persist local attempt state: $error');
    }
  }

  String _storageKey(String loginId) {
    final normalized = loginId.trim().toLowerCase();
    final digest = sha256.convert(utf8.encode('guard:$normalized')).toString();
    return 'ciss_pin_attempt_$digest';
  }
}

class _PinAttemptState {
  const _PinAttemptState({
    required this.failures,
    required this.lastFailureAt,
    required this.lockedUntil,
  });

  final int failures;
  final DateTime lastFailureAt;
  final DateTime? lockedUntil;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'failures': failures,
    'lastFailureAt': lastFailureAt.toUtc().toIso8601String(),
    if (lockedUntil != null) 'lockedUntil': lockedUntil!.toUtc().toIso8601String(),
  };

  factory _PinAttemptState.fromJson(Map<String, dynamic> json) {
    return _PinAttemptState(
      failures: (json['failures'] as num?)?.toInt() ?? 0,
      lastFailureAt:
          DateTime.tryParse(json['lastFailureAt'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lockedUntil:
          DateTime.tryParse(json['lockedUntil'] as String? ?? '')?.toLocal(),
    );
  }
}

abstract interface class PinAttemptStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class SecurePinAttemptStore implements PinAttemptStore {
  const SecurePinAttemptStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final pinAttemptGuardProvider = Provider<PinAttemptGuard>(
  (ref) => PinAttemptGuard(),
);
