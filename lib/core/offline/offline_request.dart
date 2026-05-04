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
    return OfflineRequest(
      id: json['id'] as String,
      path: json['path'] as String,
      method: json['method'] as String,
      body: Map<String, dynamic>.from(json['body'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
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
