import 'package:flutter/foundation.dart';

class OfflineRequest {
  const OfflineRequest({
    required this.id,
    required this.path,
    required this.method,
    required this.body,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
    this.sequence = 0,
    this.state = 'pending',
    this.nextAttemptAt,
    this.ownerUid,
    this.origin,
    this.streamKey,
  });

  factory OfflineRequest.fromJson(Map<String, dynamic> json) {
    final bodyRaw = json['body'];
    final body =
        bodyRaw is Map
            ? Map<String, dynamic>.from(bodyRaw)
            : <String, dynamic>{};
    final createdAtRaw = json['createdAt'];
    final createdAt =
        createdAtRaw is String
            ? (DateTime.tryParse(createdAtRaw) ??
                (() {
                  debugPrint(
                    'OfflineRequest: corrupted timestamp "$createdAtRaw" — using now',
                  );
                  return DateTime.now();
                })())
            : DateTime.now();
    return OfflineRequest(
      id: json['id']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      method: json['method']?.toString() ?? 'POST',
      body: body,
      createdAt: createdAt,
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError']?.toString(),
      sequence: json['sequence'] as int? ?? 0,
      state: json['state'] as String? ?? 'pending',
      nextAttemptAt: DateTime.tryParse(json['nextAttemptAt']?.toString() ?? ''),
      ownerUid: json['ownerUid']?.toString(),
      origin: json['origin']?.toString(),
      streamKey: json['streamKey']?.toString(),
    );
  }

  final String id;
  final String path;
  final String method;
  final Map<String, dynamic> body;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;
  final int sequence;
  final String state;
  final DateTime? nextAttemptAt;
  final String? ownerUid;
  final String? origin;
  final String? streamKey;
  String get conflictPolicy =>
      path == '/api/attendance/submit'
          ? 'server-authoritative'
          : 'server-validated';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'path': path,
      'method': method,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'lastError': lastError,
      'sequence': sequence,
      'state': state,
      'nextAttemptAt': nextAttemptAt?.toIso8601String(),
      'ownerUid': ownerUid,
      'origin': origin,
      'streamKey': streamKey,
      'conflictPolicy': conflictPolicy,
    };
  }

  OfflineRequest copyWith({
    int? retryCount,
    String? lastError,
    Map<String, dynamic>? body,
    int? sequence,
    String? state,
    DateTime? nextAttemptAt,
    String? ownerUid,
    String? origin,
    bool clearOwner = false,
    bool clearOrigin = false,
    String? streamKey,
  }) {
    return OfflineRequest(
      id: id,
      path: path,
      method: method,
      body: body ?? this.body,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      sequence: sequence ?? this.sequence,
      state: state ?? this.state,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      ownerUid: clearOwner ? null : ownerUid ?? this.ownerUid,
      origin: clearOrigin ? null : origin ?? this.origin,
      streamKey: streamKey ?? this.streamKey,
    );
  }
}
