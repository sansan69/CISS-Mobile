import 'package:flutter/foundation.dart';

/// API endpoint configuration.
///
/// Native builds compile in `CISS_API_BASE_URL` (see `mobile.env`). Web builds
/// are served from the same origin as the API (for example
/// `https://cisskerala.site/app`), so the browser origin is used instead: that
/// keeps every request same-origin and avoids relying on CORS on the API host.
class ApiConfig {
  const ApiConfig._();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'CISS_API_BASE_URL',
    defaultValue: '',
  );

  static const String _defaultBaseUrl = 'https://cisskerala.site';

  /// Absolute API base URL with no trailing slash.
  ///
  /// An explicit `--dart-define=CISS_API_BASE_URL=...` always wins, which lets
  /// a web deployment target a different API host when that host allows the
  /// deployment origin through CORS.
  static String get baseUrl {
    if (_configuredBaseUrl.trim().isNotEmpty) {
      return _withoutTrailingSlash(_configuredBaseUrl.trim());
    }
    if (kIsWeb) {
      final origin = Uri.base.origin;
      // `Uri.base.origin` is the literal string "null" for file:// and
      // opaque origins, which is never a usable API host.
      if (origin.isNotEmpty && origin != 'null') {
        return _withoutTrailingSlash(origin);
      }
    }
    return _defaultBaseUrl;
  }

  static String _withoutTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
