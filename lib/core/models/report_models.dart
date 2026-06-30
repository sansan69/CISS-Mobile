class VisitReportModel {
  const VisitReportModel({
    required this.id,
    required this.fieldOfficerName,
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
    this.visitLocation,
  });

  final String id;
  final String fieldOfficerName;
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

  /// GPS location where the report was filed
  final Map<String, double>? visitLocation;

  factory VisitReportModel.fromJson(Map<String, dynamic> json) {
    Map<String, double>? location;
    if (json['visitLocation'] is Map) {
      final raw = Map<String, dynamic>.from(json['visitLocation'] as Map);
      location = {
        'lat': (raw['lat'] as num?)?.toDouble() ?? 0,
        'lng': (raw['lng'] as num?)?.toDouble() ?? 0,
      };
    }
    return VisitReportModel(
      id: (json['id'] as String?) ?? '',
      fieldOfficerName: (json['fieldOfficerName'] as String?) ?? '',
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
      photoUrls: (json['photoUrls'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      visitLocation: location,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fieldOfficerName': fieldOfficerName,
    'siteName': siteName,
    'clientName': clientName,
    'district': district,
    'visitDate': dateLabel,
    'summary': summary,
    'issuesFound': issuesFound,
    'guardsPresentCount': guardsPresentCount,
    'guardsAbsentCount': guardsAbsentCount,
    'status': status,
    'photoUrls': photoUrls,
    if (visitLocation != null) 'visitLocation': visitLocation,
  };
}

class TrainingAttendee {
  const TrainingAttendee({
    required this.userId,
    required this.name,
  });

  final String userId;
  final String name;

  factory TrainingAttendee.fromJson(Map<String, dynamic> json) {
    return TrainingAttendee(
      userId: (json['userId'] as String?) ?? (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? (json['fullName'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
  };
}

class TrainingReportModel {
  const TrainingReportModel({
    required this.id,
    required this.fieldOfficerName,
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
    this.clientReportUrl,
    this.visitLocation,
    this.attendeeNames = const <String>[],
    this.attendees = const <TrainingAttendee>[],
  });

  final String id;
  final String fieldOfficerName;
  final String siteName;
  final String clientName;
  final String district;
  final String dateLabel;
  final String topic;
  final String description;
  final int attendeeCount;
  final int durationMinutes;

  /// "draft" | "submitted" | "acknowledged"
  final String status;

  /// Firebase Storage URLs for training photos
  final List<String> photoUrls;

  /// Additional file attachments (PDFs, docs)
  final List<String> attachmentUrls;

  /// Client-signed training report/certificate URL
  final String? clientReportUrl;

  /// GPS location where the training was conducted
  final Map<String, double>? visitLocation;

  /// Names of guards who attended the training
  final List<String> attendeeNames;

  /// Detailed attendee list with IDs and names
  final List<TrainingAttendee> attendees;

  factory TrainingReportModel.fromJson(Map<String, dynamic> json) {
    Map<String, double>? location;
    if (json['visitLocation'] is Map) {
      final raw = Map<String, dynamic>.from(json['visitLocation'] as Map);
      location = {
        'lat': (raw['lat'] as num?)?.toDouble() ?? 0,
        'lng': (raw['lng'] as num?)?.toDouble() ?? 0,
      };
    }
    return TrainingReportModel(
      id: (json['id'] as String?) ?? '',
      fieldOfficerName: (json['fieldOfficerName'] as String?) ?? '',
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
      photoUrls: (json['photoUrls'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      attachmentUrls: (json['attachmentUrls'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      clientReportUrl: json['clientReportUrl'] as String?,
      visitLocation: location,
      attendeeNames: (json['attendeeNames'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      attendees: (json['attendees'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(TrainingAttendee.fromJson)
              .toList() ??
          const <TrainingAttendee>[],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fieldOfficerName': fieldOfficerName,
    'siteName': siteName,
    'clientName': clientName,
    'district': district,
    'trainingDate': dateLabel,
    'topic': topic,
    'description': description,
    'attendeeCount': attendeeCount,
    'durationMinutes': durationMinutes,
    'status': status,
    'photoUrls': photoUrls,
    'attachmentUrls': attachmentUrls,
    if (clientReportUrl != null) 'clientReportUrl': clientReportUrl,
    if (visitLocation != null) 'visitLocation': visitLocation,
    'attendeeNames': attendeeNames,
    'attendees': attendees.map((a) => a.toJson()).toList(),
  };
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
          : '${male is num ? male : 0}M \u00b7 ${female is num ? female : 0}F',
      totalManpower: total is num
          ? total.toInt()
          : ((male is num ? male.toInt() : 0) +
                (female is num ? female.toInt() : 0)),
      assignedCount: (json['assignedCount'] as num?)?.toInt() ?? 0,
    );
  }
}
