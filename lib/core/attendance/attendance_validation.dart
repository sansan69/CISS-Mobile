/// Outcome of the server-authoritative attendance pre-check.
///
/// The server owns the geofence math and the client-IP/network decision, so
/// this result is only a convenience for instant UX. The attendance submit
/// endpoint re-enforces the same checks, so never treat an absent or failed
/// pre-check as permission to bypass them.
class AttendanceValidationResult {
  AttendanceValidationResult({
    required this.allowed,
    this.reason,
    this.checks = const {},
  });

  final bool allowed;
  final String? reason;
  final Map<String, dynamic> checks;

  /// Whether the client should abort the submit because the server said no.
  bool get blocksSubmit => !allowed;

  factory AttendanceValidationResult.fromJson(Map<String, dynamic> j) =>
      AttendanceValidationResult(
        allowed: j['allowed'] == true,
        reason: j['reason'] as String?,
        checks: (j['checks'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}
