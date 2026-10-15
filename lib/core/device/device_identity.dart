import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:hive/hive.dart';

/// Reads the platform's per-install device identifier. Injectable so tests
/// never touch the plugin.
abstract class DeviceIdSource {
  Future<String?> read();
}

class PlatformDeviceIdSource implements DeviceIdSource {
  const PlatformDeviceIdSource();

  @override
  Future<String?> read() async {
    try {
      // The consistent identifier survives app updates; the plain `udid` does
      // not, which would flag every guard as "new device" after each release.
      final id = await FlutterUdid.consistentUdid;
      final trimmed = id.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (error) {
      debugPrint('Device id unavailable: $error');
      return null;
    }
  }
}

/// The app's own identity for this handset.
///
/// The identifier is read once and cached, so a punch is never delayed or
/// blocked by a slow platform read. [recordPunchDevice] also remembers which
/// handset made the last punch, which lets a punch from a different device be
/// reported to the server as a flag on the record rather than as a refusal.
class DeviceIdentity {
  DeviceIdentity({DeviceIdSource? source})
    : _source = source ?? const PlatformDeviceIdSource();

  static const String boxName = 'device_identity';
  static const String idKey = 'udid';
  static const String lastPunchDeviceKey = 'last_punch_device';

  final DeviceIdSource _source;
  String? _cached;

  Future<void> init() async {
    await Hive.openBox<dynamic>(boxName);
    final stored = _read(idKey);
    if (stored != null) _cached = stored;
  }

  /// The identifier, or null when the platform cannot provide one. Never
  /// throws: a device without an id still has to be able to punch.
  Future<String?> id() async {
    final cached = _cached;
    if (cached != null && cached.isNotEmpty) return cached;
    final stored = _read(idKey);
    if (stored != null && stored.isNotEmpty) {
      _cached = stored;
      return stored;
    }
    String? read;
    try {
      read = await _source.read();
    } catch (error) {
      debugPrint('Device id read failed: $error');
      return null;
    }
    final value = read?.trim() ?? '';
    if (value.isEmpty) return null;
    _cached = value;
    await _write(idKey, value);
    return value;
  }

  /// Records [deviceId] as the punch device and reports whether it differs
  /// from the previous punch's device. A changed device is a flag for the
  /// server, never a reason to refuse the punch.
  Future<bool> recordPunchDevice(String? deviceId) async {
    final value = deviceId?.trim() ?? '';
    if (value.isEmpty) return false;
    final previous = _read(lastPunchDeviceKey);
    await _write(lastPunchDeviceKey, value);
    return previous != null && previous.isNotEmpty && previous != value;
  }

  String? _read(String key) {
    if (!Hive.isBoxOpen(boxName)) return null;
    final value = Hive.box<dynamic>(boxName).get(key);
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _write(String key, String value) async {
    if (!Hive.isBoxOpen(boxName)) return;
    try {
      await Hive.box<dynamic>(boxName).put(key, value);
    } catch (error) {
      debugPrint('Device identity write failed: $error');
    }
  }
}

final deviceIdSourceProvider = Provider<DeviceIdSource>(
  (ref) => const PlatformDeviceIdSource(),
);

final deviceIdentityProvider = Provider<DeviceIdentity>(
  (ref) => DeviceIdentity(source: ref.watch(deviceIdSourceProvider)),
);
