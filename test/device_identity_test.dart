import 'dart:io';

import 'package:ciss_mobile/core/device/device_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FakeDeviceId implements DeviceIdSource {
  _FakeDeviceId([this.value = 'udid-alpha']);

  String? value;
  bool throwOnRead = false;
  int reads = 0;

  @override
  Future<String?> read() async {
    reads++;
    if (throwOnRead) throw StateError('keystore unavailable');
    return value;
  }
}

void main() {
  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('ciss-device-').path);
  });
  tearDownAll(() async => Hive.close());

  group('device identity', () {
    late Box<dynamic> box;

    setUp(() async {
      box = await Hive.openBox<dynamic>(DeviceIdentity.boxName);
      await box.clear();
    });

    tearDown(() async {
      await box.deleteFromDisk();
    });

    test('reads the platform id once and serves the rest from the cache', () async {
      final source = _FakeDeviceId();
      final identity = DeviceIdentity(source: source);
      await identity.init();

      expect(await identity.id(), 'udid-alpha');
      expect(await identity.id(), 'udid-alpha');
      expect(source.reads, 1);
    });

    test('keeps the identifier across a restart', () async {
      final first = DeviceIdentity(source: _FakeDeviceId());
      await first.init();
      expect(await first.id(), 'udid-alpha');

      // A fresh instance (new launch) reads the stored value, so the id does
      // not change every time the app starts.
      final source = _FakeDeviceId('udid-beta');
      final second = DeviceIdentity(source: source);
      await second.init();
      expect(await second.id(), 'udid-alpha');
      expect(source.reads, 0);
    });

    test('a failing platform read yields no id instead of an exception', () async {
      final source = _FakeDeviceId()..throwOnRead = true;
      final identity = DeviceIdentity(source: source);
      await identity.init();
      expect(await identity.id(), isNull);
    });

    test('an empty id is treated as no id', () async {
      final identity = DeviceIdentity(source: _FakeDeviceId('   '));
      await identity.init();
      expect(await identity.id(), isNull);
    });

    test('flags a punch from a different device without blocking it', () async {
      final identity = DeviceIdentity(source: _FakeDeviceId());
      await identity.init();

      // First punch on this phone: nothing to compare against.
      expect(await identity.recordPunchDevice('udid-alpha'), isFalse);
      // Same phone: still no flag.
      expect(await identity.recordPunchDevice('udid-alpha'), isFalse);
      // A different handset: flagged, and the flag is sticky for that change
      // only.
      expect(await identity.recordPunchDevice('udid-gamma'), isTrue);
      expect(await identity.recordPunchDevice('udid-gamma'), isFalse);
    });

    test('ignores an empty id when recording the punch device', () async {
      final identity = DeviceIdentity(source: _FakeDeviceId());
      await identity.init();
      expect(await identity.recordPunchDevice(null), isFalse);
      expect(await identity.recordPunchDevice('  '), isFalse);
      expect(await identity.recordPunchDevice('udid-alpha'), isFalse);
    });
  });
}
