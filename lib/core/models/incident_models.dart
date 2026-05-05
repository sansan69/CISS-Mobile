class IncidentModel {
  const IncidentModel({
    required this.id,
    required this.category,
    required this.severity,
    required this.status,
    required this.siteName,
    required this.reportedAtLabel,
    required this.summary,
  });

  final String id;
  final String category;
  final String severity;
  final String status;
  final String siteName;
  final String reportedAtLabel;
  final String summary;

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: (json['id'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      severity: (json['severity'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      siteName: (json['siteName'] as String?) ?? '',
      reportedAtLabel:
          (json['reportedAt'] as String?) ??
          (json['createdAt'] as String?) ??
          '',
      summary:
          (json['description'] as String?) ??
          (json['summary'] as String?) ??
          '',
    );
  }
}
