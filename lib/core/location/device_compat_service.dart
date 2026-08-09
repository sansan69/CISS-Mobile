import 'package:flutter/services.dart';

/// Bridge to the native [DeviceCompatPlugin] — battery-optimization exemption
/// and OEM auto-start settings for Chinese manufacturers (Xiaomi, Oppo, Vivo,
/// Realme, OnePlus, Huawei) that aggressively kill background services.
class DeviceCompatService {
  DeviceCompatService([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'co.in.ciss.ciss_mobile/device_compat';

  final MethodChannel _channel;

  /// True when the app is exempt from battery optimization (always true on
  /// Android < 6.0, where the API does not exist).
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
    } on PlatformException {
      return true; // Fail open: never block tracking on a probe failure.
    }
  }

  /// Opens the battery-optimization list where the user sets CISS to
  /// "Don't optimize". The direct exemption dialog is deliberately not used:
  /// it needs the Play-restricted REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
  /// permission, which the app's Android tracking contract bans.
  Future<bool> openBatteryOptimizationSettings() async {
    try {
      return await _channel.invokeMethod<bool>(
            'openBatteryOptimizationSettings',
          ) ??
          true;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the brand-specific auto-start settings page (Xiaomi/Oppo/Vivo/...),
  /// falling back to the app detail settings on other devices.
  Future<bool> openBrandAutostartSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openBrandAutostartSettings') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the OS fingerprint enrollment screen (falls back to biometric
  /// enrollment, then security settings). Used when the device has a scanner
  /// but no fingerprint registered yet.
  Future<bool> openFingerprintEnrollSettings() async {
    try {
      return await _channel.invokeMethod<bool>(
            'openFingerprintEnrollSettings',
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Build.MANUFACTURER, e.g. "Xiaomi", "vivo", "google".
  Future<String> getManufacturer() async {
    try {
      return await _channel.invokeMethod<String>('getManufacturer') ??
          'unknown';
    } on PlatformException {
      return 'unknown';
    }
  }

  /// True when this device is from a Chinese OEM known for aggressive
  /// background-process management (auto-start usually disabled by default).
  Future<bool> isAggressiveOem() async {
    final manufacturer = (await getManufacturer()).toLowerCase();
    return manufacturer.contains('xiaomi') ||
        manufacturer.contains('redmi') ||
        manufacturer.contains('poco') ||
        manufacturer.contains('oppo') ||
        manufacturer.contains('realme') ||
        manufacturer.contains('vivo') ||
        manufacturer.contains('iqoo') ||
        manufacturer.contains('huawei') ||
        manufacturer.contains('honor') ||
        manufacturer.contains('oneplus');
  }
}
