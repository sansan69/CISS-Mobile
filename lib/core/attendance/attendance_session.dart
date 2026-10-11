// lib/core/attendance/attendance_session.dart

/// Which break transition to request from the server.
enum BreakAction { start, stop }

/// Server-authoritative break state for an open attendance session.
///
/// The backend owns the truth: each `/api/mobile/attendance/break` response is
/// fed to [applyBreakResponse] and the local flags mirror what the server
/// reports, so a guard cannot check out while the server says a reason or a
/// break stop is still required.
class AttendanceSession {
  bool onBreak = false;
  DateTime? breakStartedAt;
  int totalBreakSeconds = 0;
  bool canCheckOut = true;

  void applyBreakResponse(Map<String, dynamic> r) {
    onBreak = r['onBreak'] == true;
    totalBreakSeconds =
        (r['breakSeconds'] as num?)?.toInt() ?? totalBreakSeconds;
    canCheckOut = r['canCheckOut'] != false;
    final started = r['breakStartedAt'] as String?;
    breakStartedAt =
        onBreak && started != null ? DateTime.tryParse(started) : null;
  }
}
