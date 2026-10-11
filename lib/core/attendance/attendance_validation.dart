import '../settings/module_flags.dart';

/// Whether the client should run the server-authoritative attendance
/// pre-check before check-in/out.
///
/// Per the controller ruling (2026-10-11) the **entire** pre-check is opt-in
/// behind `ipAttendance` (default OFF). `geoFence` — which defaults ON — must
/// not enable it on its own, so the check-in/out critical path stays unchanged
/// (no `fetchPublicIp()` + `/attendance/validate` round trip) by default; the
/// server still enforces geo + IP on submit.
bool shouldRunAttendancePreCheck(ModuleFlags flags) => flags.ipAttendance;

/// Outcome of the server-authoritative attendance pre-check.
///
/// The server owns the geofence math and the client-IP/network decision, so
/// this result is only a convenience for instant UX. The attendance submit
/// endpoint re-enforces the same checks, so never treat an absent or failed
/// pre-check as permission to bypass them.
class AttendanceValidationResult {
  AttendanceValidationResult({
    required this.canSubmit,
    this.reason,
    this.checks = const {},
  });

  /// The server's authoritative flag. The live contract returns `canSubmit`;
  /// a legacy `allowed` key is also honoured for backward compatibility.
  final bool canSubmit;
  final String? reason;
  final Map<String, dynamic> checks;

  /// Whether the client should abort the submit because the server said no.
  bool get blocksSubmit => !canSubmit;

  factory AttendanceValidationResult.fromJson(Map<String, dynamic> j) =>
      AttendanceValidationResult(
        canSubmit: (j['canSubmit'] ?? j['allowed']) == true,
        reason: j['reason'] as String?,
        checks: (j['checks'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}
