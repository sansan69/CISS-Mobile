import 'package:flutter/foundation.dart';

class OfflineRequest {
  /// Endpoint used by the unauthenticated public attendance flow.
  static const String publicAttendancePath = '/api/attendance/submit';

  const OfflineRequest({
    required this.id,
    required this.path,
    required this.method,
    required this.body,
    required this.createdAt,
    this.uid,
    this.retryCount = 0,
    this.lastError,
    this.nextAttemptAt,
    this.blocked = false,
  });

  factory OfflineRequest.fromJson(Map<String, dynamic> json) {
    final bodyRaw = json['body'];
    final body = bodyRaw is Map
        ? Map<String, dynamic>.from(bodyRaw)
        : <String, dynamic>{};
    final createdAtRaw = json['createdAt'];
    final createdAt = createdAtRaw is String
        ? (DateTime.tryParse(createdAtRaw) ?? (() {
            debugPrint('OfflineRequest: corrupted timestamp — using now');
            return DateTime.now();
          })())
        : DateTime.now();
    final uidRaw = json['uid'];
    final uid = uidRaw is String && uidRaw.trim().isNotEmpty
        ? uidRaw.trim()
        : null;
    final nextAttemptRaw = json['nextAttemptAt'];
    final nextAttemptAt = nextAttemptRaw is String
        ? DateTime.tryParse(nextAttemptRaw)
        : null;
    return OfflineRequest(
      id: json['id']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      method: json['method']?.toString() ?? 'POST',
      body: body,
      createdAt: createdAt,
      uid: uid,
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError']?.toString(),
      nextAttemptAt: nextAttemptAt,
      blocked: json['blocked'] == true,
    );
  }

  final String id;
  final String path;
  final String method;
  final Map<String, dynamic> body;
  final DateTime createdAt;

  /// Firebase uid of the account that queued this request (or
  /// `OfflineQueue.anonymousOwnerUid` for unauthenticated submissions). `null`
  /// only for entries written before ownership existed; those are purged, never
  /// replayed under whichever account is signed in next.
  final String? uid;
  final int retryCount;
  final String? lastError;

  /// Earliest time this entry may be retried, persisted so backoff survives a
  /// process death and never sleeps inside the serial sync loop.
  final DateTime? nextAttemptAt;

  /// Terminal state after [SyncService.maxRetryAttempts] failures. A blocked
  /// entry is kept (never deleted silently), skipped by the sync pass, and
  /// surfaced in the queue-health badge so it can be inspected/supported.
  final bool blocked;

  bool isDue(DateTime now) {
    final next = nextAttemptAt;
    return !blocked && (next == null || !next.isAfter(now));
  }

  /// Whether this entry is an unauthenticated public attendance submission.
  ///
  /// Those entries carry their own short-lived verification proof in the body
  /// and are replayed **without** a bearer token, so they remain eligible for
  /// replay in any session state — signed out included. Everything else is
  /// account-scoped and needs the identity that queued it.
  bool get isPublicAttendance {
    if (path != publicAttendancePath) return false;
    final token = body['attendanceVerificationToken'];
    return token is String && token.trim().isNotEmpty;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'path': path,
      'method': method,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'uid': uid,
      'retryCount': retryCount,
      'lastError': lastError,
      if (nextAttemptAt != null)
        'nextAttemptAt': nextAttemptAt!.toIso8601String(),
      if (blocked) 'blocked': true,
    };
  }

  OfflineRequest copyWith({
    int? retryCount,
    String? lastError,
    Map<String, dynamic>? body,
    String? uid,
    DateTime? nextAttemptAt,
    bool clearNextAttemptAt = false,
    bool? blocked,
  }) {
    return OfflineRequest(
      id: id,
      path: path,
      method: method,
      body: body ?? this.body,
      createdAt: createdAt,
      uid: uid ?? this.uid,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      nextAttemptAt:
          clearNextAttemptAt ? null : (nextAttemptAt ?? this.nextAttemptAt),
      blocked: blocked ?? this.blocked,
    );
  }
}
