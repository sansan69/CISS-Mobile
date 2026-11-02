/// Allowlist policy for server-supplied update URLs (F-08 / P-04).
///
/// The update manifest is fetched from the region API and carries both
/// `apkUrl` and `sha256`. Both values come from the same untrusted document, so
/// the digest alone cannot prove where the APK came from. Every outbound
/// action that uses `apkUrl` — the in-app download and the browser fallback —
/// must first be constrained to:
///
/// * `https` only (no cleartext downgrade, no `intent://` / `file://`),
/// * the production host (`cisskerala.site`) or one of its subdomains,
/// * a path below `/downloads/`,
/// * no `user:password@` user-info component and no explicit port.
///
/// The policy is intentionally a pure function so it can be unit tested and
/// reused by the downloader, the update gate and the browser fallback without
/// pulling in Flutter, Dio or platform channels.
library;

/// Why [UpdateUrlPolicy.check] rejected a URL. Stable identifiers so tests and
/// logs can assert on the exact rejection reason.
enum UpdateUrlRejection {
  /// No URL was supplied at all.
  empty,

  /// The string is not a parseable absolute URL.
  malformed,

  /// The scheme is missing or is not `https`.
  schemeNotHttps,

  /// The URL embeds `user:password@host` (a classic phishing/spoofing vector).
  userInfo,

  /// The URL pins an explicit port (for example `:8443`).
  port,

  /// The host is neither `cisskerala.site` nor a subdomain of it.
  hostNotAllowed,

  /// The path is not below `/downloads/` or tries to traverse out of it.
  pathNotAllowed,
}

/// Result of [UpdateUrlPolicy.check].
class UpdateUrlCheck {
  const UpdateUrlCheck.allowed(Uri this.uri) : rejection = null;
  const UpdateUrlCheck.rejected(UpdateUrlRejection this.rejection) : uri = null;

  /// The normalised, allowlisted URI when [isAllowed], otherwise `null`.
  final Uri? uri;

  /// The first rule that rejected the URL, or `null` when allowed.
  final UpdateUrlRejection? rejection;

  bool get isAllowed => uri != null && rejection == null;
}

/// Stateless URL allowlist for the self-update channel.
abstract final class UpdateUrlPolicy {
  /// Only TLS is acceptable for an installable payload.
  static const String requiredScheme = 'https';

  /// Production apex domain. Subdomains are accepted as well.
  static const String allowedHost = 'cisskerala.site';

  /// Update artifacts must live under this path on the trusted host.
  static const String requiredPathPrefix = '/downloads/';

  /// The only path characters that can climb out of `/downloads/`.
  static final RegExp _dotSegment = RegExp(r'(^|/)\.{1,2}(/|$)');

  /// Validates [raw] and returns the URI plus the rejection reason.
  static UpdateUrlCheck check(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return const UpdateUrlCheck.rejected(UpdateUrlRejection.empty);
    }

    final Uri uri;
    try {
      uri = Uri.parse(value);
    } on FormatException {
      return const UpdateUrlCheck.rejected(UpdateUrlRejection.malformed);
    }

    if (!uri.hasScheme || uri.scheme.toLowerCase() != requiredScheme) {
      return const UpdateUrlCheck.rejected(UpdateUrlRejection.schemeNotHttps);
    }
    if (uri.userInfo.isNotEmpty) {
      return const UpdateUrlCheck.rejected(UpdateUrlRejection.userInfo);
    }
    // `Uri.hasPort` is true only when the authority contains an explicit port,
    // so an explicit `:443` is rejected too ("no ports" per the update policy).
    if (uri.hasPort) {
      return const UpdateUrlCheck.rejected(UpdateUrlRejection.port);
    }
    if (!isAllowedHost(uri.host)) {
      return const UpdateUrlCheck.rejected(UpdateUrlRejection.hostNotAllowed);
    }

    final rawPath = uri.path;
    if (_dotSegment.hasMatch(rawPath)) {
      return const UpdateUrlCheck.rejected(UpdateUrlRejection.pathNotAllowed);
    }
    final normalisedPath = uri.normalizePath().path;
    if (_dotSegment.hasMatch(normalisedPath) ||
        !normalisedPath.startsWith(requiredPathPrefix)) {
      return const UpdateUrlCheck.rejected(UpdateUrlRejection.pathNotAllowed);
    }
    if (normalisedPath.length <= requiredPathPrefix.length) {
      // `/downloads/` alone names a directory, not an artifact.
      return const UpdateUrlCheck.rejected(UpdateUrlRejection.pathNotAllowed);
    }

    return UpdateUrlCheck.allowed(uri);
  }

  /// True when [host] is [allowedHost] or a subdomain of it.
  ///
  /// The comparison is exact for the apex and suffix-anchored for subdomains,
  /// so lookalikes such as `evilcisskerala.site` or `cisskerala.site.evil.test`
  /// are rejected.
  static bool isAllowedHost(String host) {
    final normalised = host.toLowerCase();
    if (normalised.isEmpty) return false;
    return normalised == allowedHost || normalised.endsWith('.$allowedHost');
  }

  /// Convenience predicate for call sites that only need a yes/no answer.
  static bool allows(String? raw) => check(raw).isAllowed;

  /// The allowlisted URI, or `null` when [raw] is not acceptable.
  static Uri? allowedUri(String? raw) => check(raw).uri;
}
