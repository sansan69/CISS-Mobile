class IncidentModel {
  const IncidentModel({
    required this.id,
    required this.category,
    required this.severity,
    required this.status,
    required this.siteName,
    required this.reportedAtLabel,
    required this.summary,
    this.district,
    this.photoUrls = const [],
    this.locationText,
  });

  final String id;
  final String category;
  final String severity;
  final String status;
  final String siteName;
  final String reportedAtLabel;
  final String summary;
  final String? district;
  final List<String> photoUrls;
  final String? locationText;

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photoUrls'] ?? json['photos'];
    final photos = <String>[];
    if (rawPhotos is List) {
      for (final p in rawPhotos) {
        if (p is String && p.isNotEmpty) photos.add(p);
      }
    } else if (json['photoUrl'] is String &&
        (json['photoUrl'] as String).isNotEmpty) {
      photos.add(json['photoUrl'] as String);
    }

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
      district: (json['district'] as String?),
      photoUrls: photos,
      locationText: (json['locationText'] as String?),
    );
  }
}
