/// Redaction helpers for diagnostics that may reach platform logs.
///
/// Flutter's `debugPrint` is **not** stripped from release builds, and logcat /
/// device console logs are readable by bug-report tooling. Call sites must not
/// log session payloads, response bodies, Firebase uids, tokens, email
/// addresses or GPS coordinates; [redactForLog] is a last line of defence for
/// free-form error messages that may embed them.
class PrivacyLog {
  const PrivacyLog._();

  static final RegExp _bearer = RegExp(
    r'bearer\s+[A-Za-z0-9._~+/=-]+',
    caseSensitive: false,
  );
  static final RegExp _jwt = RegExp(
    r'eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}',
  );
  static final RegExp _email = RegExp(
    r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
  );

  /// `12.971612, 77.594562` and similar coordinate pairs.
  static final RegExp _coordinatePair = RegExp(
    r'-?\d{1,3}\.\d{4,}\s*[,;]\s*-?\d{1,3}\.\d{4,}',
  );

  /// `latitude: 12.971612`, `lng=77.594562`.
  static final RegExp _labelledCoordinate = RegExp(
    r'\b(?:lat|latitude|lng|lon|longitude)\b\s*[:=]\s*-?\d{1,3}\.\d+',
    caseSensitive: false,
  );

  /// Returns [message] with common PII patterns replaced by placeholders.
  ///
  /// Pass the session's uid(s) in [uids] so exact identifier occurrences are
  /// removed even when they do not match a generic pattern. Endpoint paths,
  /// HTTP status codes and error class names are preserved because those are
  /// the diagnostics worth keeping.
  static String redactForLog(
    String message, {
    Iterable<String?> uids = const <String?>[],
  }) {
    var out = message;
    for (final uid in uids) {
      if (uid == null || uid.isEmpty) continue;
      out = out.replaceAll(uid, '<uid>');
    }
    out = out.replaceAllMapped(_bearer, (_) => 'Bearer <redacted>');
    out = out.replaceAllMapped(_jwt, (_) => '<token>');
    out = out.replaceAllMapped(_email, (_) => '<email>');
    out = out.replaceAllMapped(_coordinatePair, (_) => '<coordinates>');
    out = out.replaceAllMapped(_labelledCoordinate, (_) => '<coordinate>');
    return out;
  }

  /// Encodes an identifier for a coarse diagnostic (e.g. "did uid change?")
  /// without exposing the identifier itself.
  static String describeUidPresence(String? uid) =>
      uid == null || uid.isEmpty ? 'uid:none' : 'uid:present';
}
