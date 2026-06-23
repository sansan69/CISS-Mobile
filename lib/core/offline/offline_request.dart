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
  });

  factory OfflineRequest.fromJson(Map<String, dynamic> json) {
    final bodyRaw = json['body'];
    final body = bodyRaw is Map
        ? Map<String, dynamic>.from(bodyRaw)
        : <String, dynamic>{};
    final createdAtRaw = json['createdAt'];
    final createdAt = createdAtRaw is String
        ? (DateTime.tryParse(createdAtRaw) ?? (() {
            debugPrint('OfflineRequest: corrupted timestamp "$createdAtRaw" — using now');
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
    );
  }

  final String id;
  final String path;
  final String method;
  final Map<String, dynamic> body;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'path': path,
      'method': method,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'lastError': lastError,
    };
  }

  OfflineRequest copyWith({
    int? retryCount,
    String? lastError,
    Map<String, dynamic>? body,
  }) {
    return OfflineRequest(
      id: id,
      path: path,
      method: method,
      body: body ?? this.body,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}
