class VisitReportModel {
  const VisitReportModel({
    required this.id,
    required this.siteName,
    required this.clientName,
    required this.district,
    required this.dateLabel,
    required this.summary,
    required this.issuesFound,
    required this.guardsPresentCount,
    required this.guardsAbsentCount,
    required this.status,
    this.photoUrls = const <String>[],
  });

  final String id;
  final String siteName;
  final String clientName;
  final String district;
  final String dateLabel;
  final String summary;
  final String issuesFound;
  final int guardsPresentCount;
  final int guardsAbsentCount;

  /// "draft" | "submitted" | "reviewed"
  final String status;

  /// Firebase Storage URLs for visit photos
  final List<String> photoUrls;

  factory VisitReportModel.fromJson(Map<String, dynamic> json) {
    return VisitReportModel(
      id: (json['id'] as String?) ?? '',
      siteName: (json['siteName'] as String?) ?? '',
      clientName: (json['clientName'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      dateLabel:
          (json['visitDate'] as String?) ??
          (json['createdAt'] as String?) ??
          '',
      summary: (json['summary'] as String?) ?? '',
      issuesFound: (json['issuesFound'] as String?) ?? '',
      guardsPresentCount: (json['guardsPresentCount'] as num?)?.toInt() ?? 0,
      guardsAbsentCount: (json['guardsAbsentCount'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'submitted',
      photoUrls:
          (json['photoUrls'] as List<dynamic>?)?.whereType<String>().toList() ??
          const <String>[],
    );
  }
}

class TrainingReportModel {
  const TrainingReportModel({
    required this.id,
    required this.siteName,
    required this.clientName,
    required this.district,
    required this.dateLabel,
    required this.topic,
    required this.description,
    required this.attendeeCount,
    required this.durationMinutes,
    required this.status,
    this.photoUrls = const <String>[],
    this.attachmentUrls = const <String>[],
  });

  final String id;
  final String siteName;
  final String clientName;
  final String district;
  final String dateLabel;
  final String topic;
  final String description;
  final int attendeeCount;
  final int durationMinutes;

  /// "submitted" | "acknowledged"
  final String status;

  /// Firebase Storage URLs for training photos
  final List<String> photoUrls;

  /// Firebase Storage URLs for training report uploads
  final List<String> attachmentUrls;

  factory TrainingReportModel.fromJson(Map<String, dynamic> json) {
    return TrainingReportModel(
      id: (json['id'] as String?) ?? '',
      siteName: (json['siteName'] as String?) ?? '',
      clientName: (json['clientName'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      dateLabel:
          (json['trainingDate'] as String?) ??
          (json['createdAt'] as String?) ??
          '',
      topic: (json['topic'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      attendeeCount: (json['attendeeCount'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'submitted',
      photoUrls:
          (json['photoUrls'] as List<dynamic>?)?.whereType<String>().toList() ??
          const <String>[],
      attachmentUrls:
          (json['attachmentUrls'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
    );
  }
}

class WorkOrderModel {
  const WorkOrderModel({
    required this.id,
    required this.siteId,
    required this.siteName,
    required this.clientId,
    required this.clientName,
    required this.district,
    required this.examName,
    required this.examCode,
    required this.dateLabel,
    required this.totalManpowerLabel,
    required this.totalManpower,
    required this.assignedCount,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String siteId;
  final String siteName;
  final String clientId;
  final String clientName;
  final String district;
  final String examName;
  final String examCode;
  final String dateLabel;
  final String totalManpowerLabel;
  final int totalManpower;
  final int assignedCount;
  final double? latitude;
  final double? longitude;

  factory WorkOrderModel.fromJson(Map<String, dynamic> json) {
    final male = json['maleGuardsRequired'];
    final female = json['femaleGuardsRequired'];
    final total = json['totalManpower'];
    return WorkOrderModel(
      id: (json['id'] as String?) ?? '',
      siteId: (json['siteId'] as String?) ?? '',
      siteName: (json['siteName'] as String?) ?? '',
      clientId: (json['clientId'] as String?) ?? '',
      clientName: (json['clientName'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      examName:
          (json['examName'] as String?) ??
          (json['examCode'] as String?) ??
          'Duty',
      examCode: (json['examCode'] as String?) ?? '',
      dateLabel: (json['date'] as String?) ?? '',
      totalManpowerLabel: total is num
          ? total.toString()
          : '${male is num ? male : 0}M · ${female is num ? female : 0}F',
      totalManpower: total is num
          ? total.toInt()
          : ((male is num ? male.toInt() : 0) +
                (female is num ? female.toInt() : 0)),
      assignedCount: (json['assignedCount'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class FieldOfficerSiteOption {
  const FieldOfficerSiteOption({
    required this.siteId,
    required this.siteName,
    required this.clientId,
    required this.clientName,
    required this.district,
    this.latitude,
    this.longitude,
  });

  final String siteId;
  final String siteName;
  final String clientId;
  final String clientName;
  final String district;
  final double? latitude;
  final double? longitude;

  factory FieldOfficerSiteOption.fromJson(Map<String, dynamic> json) {
    return FieldOfficerSiteOption(
      siteId: (json['siteId'] as String?) ?? '',
      siteName: (json['siteName'] as String?) ?? '',
      clientId: (json['clientId'] as String?) ?? '',
      clientName: (json['clientName'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}
