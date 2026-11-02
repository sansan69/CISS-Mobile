import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/auth/pin_attempt_guard.dart';

void main() {
  group('PinAttemptGuard', () {
    late _MemoryPinAttemptStore store;
    late DateTime now;
    late PinAttemptGuard guard;

    setUp(() {
      store = _MemoryPinAttemptStore();
      now = DateTime(2026, 10, 22, 9);
      guard = PinAttemptGuard(store: store, now: () => now);
    });

    test('does not cooldown the first four failures', () async {
      for (var i = 0; i < 4; i++) {
        expect(await guard.recordFailure('CISS/2026/001'), Duration.zero);
      }
      expect(await guard.failuresFor('CISS/2026/001'), 4);
      expect(await guard.remainingCooldown('CISS/2026/001'), Duration.zero);
    });

    test('applies escalating cooldowns from the fifth failure', () async {
      for (var i = 0; i < 4; i++) {
        await guard.recordFailure('EMP-1');
      }
      expect(
        await guard.recordFailure('EMP-1'),
        const Duration(seconds: 30),
      );
      expect(
        await guard.remainingCooldown('EMP-1'),
        const Duration(seconds: 30),
      );

      now = now.add(const Duration(seconds: 31));
      expect(await guard.remainingCooldown('EMP-1'), Duration.zero);
      expect(
        await guard.recordFailure('EMP-1'),
        const Duration(minutes: 1),
      );
    });

    test('reset clears the failure budget after a successful login', () async {
      for (var i = 0; i < 6; i++) {
        await guard.recordFailure('EMP-1');
      }
      await guard.reset('EMP-1');
      expect(await guard.failuresFor('EMP-1'), 0);
      expect(await guard.remainingCooldown('EMP-1'), Duration.zero);
    });

    test('keeps identifiers independent', () async {
      for (var i = 0; i < 6; i++) {
        await guard.recordFailure('EMP-1');
      }
      expect(await guard.failuresFor('EMP-1'), 6);
      expect(await guard.failuresFor('EMP-2'), 0);
      expect(await guard.remainingCooldown('EMP-2'), Duration.zero);
    });

    test('expires stale failure state after 24 hours', () async {
      for (var i = 0; i < 4; i++) {
        await guard.recordFailure('EMP-1');
      }
      now = now.add(const Duration(hours: 25));
      expect(
        await guard.recordFailure('EMP-1'),
        Duration.zero,
        reason: 'a new failure after 24h starts a fresh budget',
      );
      expect(await guard.failuresFor('EMP-1'), 1);
    });

    test('does not persist the raw login identifier', () async {
      await guard.recordFailure('CISS/TCS/2025-26/871');
      expect(store.keys, hasLength(1));
      expect(store.keys.single, isNot(contains('CISS')));
      expect(store.keys.single, startsWith('ciss_pin_attempt_'));
    });

    test('formats cooldowns for user-facing copy', () {
      expect(PinAttemptGuard.formatCooldown(const Duration(seconds: 1)), '1 second');
      expect(PinAttemptGuard.formatCooldown(const Duration(seconds: 30)), '30 seconds');
      expect(PinAttemptGuard.formatCooldown(const Duration(minutes: 1)), '1 minute');
      expect(PinAttemptGuard.formatCooldown(const Duration(minutes: 5)), '5 minutes');
      expect(PinAttemptGuard.formatCooldown(const Duration(minutes: 61)), '2 hours');
    });
  });
}

class _MemoryPinAttemptStore implements PinAttemptStore {
  final Map<String, String> _values = <String, String>{};

  Set<String> get keys => _values.keys.toSet();

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
