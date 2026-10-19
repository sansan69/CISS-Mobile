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
  String? sessionId;
  int _punchRevision = 0;
  bool onBreak = false;
  DateTime? breakStartedAt;
  int totalBreakSeconds = 0;
  bool canCheckOut = true;

  int get punchRevision => _punchRevision;

  /// Apply a successfully accepted punch. IN's log ID is the server's
  /// attendance session ID; an OUT closes and clears the prior session.
  void applyPunch({required String status, required String? responseId}) {
    _punchRevision++;
    if (status == 'In') {
      sessionId = responseId;
      onBreak = false;
      breakStartedAt = null;
      totalBreakSeconds = 0;
      canCheckOut = true;
    } else if (status == 'Out') {
      sessionId = null;
      onBreak = false;
      breakStartedAt = null;
      totalBreakSeconds = 0;
      canCheckOut = true;
    }
  }

  /// Startup status is useful only until a newer punch has been accepted.
  bool applyTrackingStatus(
    Map<String, dynamic> status, {
    required int expectedPunchRevision,
  }) {
    if (_punchRevision != expectedPunchRevision) return false;
    sessionId =
        status['isClockedIn'] == true
            ? status['openSessionId'] as String?
            : null;
    return true;
  }

  void applyBreakResponse(Map<String, dynamic> r) {
    sessionId = r['sessionId'] as String? ?? sessionId;
    onBreak = r['onBreak'] == true;
    totalBreakSeconds =
        (r['breakSeconds'] as num?)?.toInt() ?? totalBreakSeconds;
    canCheckOut = r['canCheckOut'] != false;
    final started = r['breakStartedAt'] as String?;
    breakStartedAt =
        onBreak && started != null ? DateTime.tryParse(started) : null;
  }
}

/// Capture once, and send the identical operation online or from the outbox.
Map<String, dynamic> buildBreakPayload({
  required String action,
  required DateTime capturedAt,
  required String clientRequestId,
  String? sessionId,
  double? lat,
  double? lng,
  double? accuracy,
}) => {
  'action': action,
  'capturedAt': capturedAt.toUtc().toIso8601String(),
  'clientRequestId': clientRequestId,
  if (sessionId != null && sessionId.isNotEmpty) 'sessionId': sessionId,
  if (lat != null) 'lat': lat,
  if (lng != null) 'lng': lng,
  if (accuracy != null) 'accuracy': accuracy,
};

Map<String, dynamic> buildEarlyCheckoutRetryPayload({
  required Map<String, dynamic> originalPayload,
  required String photoUrl,
  required String photoStoragePath,
  required String clientRequestId,
  required String reason,
}) => {
  ...originalPayload,
  'photoUrl': photoUrl,
  'photoStoragePath': photoStoragePath,
  'clientRequestId': clientRequestId,
  'earlyCheckOutReason': reason,
};

Map<String, dynamic> buildAttendanceRetryQueuePayload({
  required Map<String, dynamic> durablePayload,
  required String photoDataUrl,
}) => {
  ...durablePayload,
  if ((durablePayload['photoUrl'] as String?)?.isNotEmpty != true)
    'photoDataUrl': photoDataUrl,
};
