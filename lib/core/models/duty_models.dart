/// A duty shown to a guard: either an FO-assigned shift, or an upcoming
/// adhoc exam duty the guard may express willingness for.
///
/// Assignment is informational only — it is never a precondition for
/// marking attendance.
enum DutyKind {
  /// A shift assigned by the field officer (informational, future reference).
  assigned,

  /// An upcoming adhoc exam duty open to willingness.
  exam,
}

/// A guard's willingness response to an exam duty.
enum WillingnessStatus { willing, unavailable }

class GuardDuty {
  const GuardDuty({
    required this.id,
    required this.kind,
    required this.clientName,
    required this.siteName,
    required this.date,
    this.shiftLabel,
    this.relieving = false,
    this.examName,
    this.willingness,
    this.siteId = '',
    this.district = '',
    this.status = 'assigned',
    this.startsAt,
    this.endsAt,
    this.workOrderId,
    this.examCode,
    this.maleGuardsRequired,
    this.femaleGuardsRequired,
    this.willingnessVersion = 0,
    this.canRespond = false,
    this.respondBy,
    this.ineligibilityReason,
  });

  final String id;
  final DutyKind kind;
  final String clientName;
  final String siteName;

  /// Display date label, as provided by the server.
  final String date;

  final String? shiftLabel;

  /// True when this is cover at another site rather than the home site.
  final bool relieving;

  /// Exam name, for [DutyKind.exam] duties.
  final String? examName;

  /// The guard's response to an exam duty, or null when unanswered / not
  /// applicable to an assigned duty.
  final WillingnessStatus? willingness;

  final String siteId, district, status;
  final String? startsAt,
      endsAt,
      workOrderId,
      examCode,
      respondBy,
      ineligibilityReason;
  final int? maleGuardsRequired, femaleGuardsRequired;
  final int willingnessVersion;
  final bool canRespond;

  bool get isExam => kind == DutyKind.exam;

  GuardDuty withWillingness(WillingnessStatus? value) => GuardDuty(
    id: id,
    kind: kind,
    clientName: clientName,
    siteName: siteName,
    date: date,
    shiftLabel: shiftLabel,
    relieving: relieving,
    examName: examName,
    willingness: value,
    siteId: siteId,
    district: district,
    status: status,
    startsAt: startsAt,
    endsAt: endsAt,
    workOrderId: workOrderId,
    examCode: examCode,
    maleGuardsRequired: maleGuardsRequired,
    femaleGuardsRequired: femaleGuardsRequired,
    willingnessVersion: willingnessVersion,
    canRespond: canRespond,
    respondBy: respondBy,
    ineligibilityReason: ineligibilityReason,
  );

  factory GuardDuty.fromJson(Map<String, dynamic> json) {
    return GuardDuty(
      id: (json['id'] as String?) ?? '',
      kind:
          (json['kind'] as String?) == 'exam'
              ? DutyKind.exam
              : DutyKind.assigned,
      clientName: (json['clientName'] as String?) ?? '',
      siteName: (json['siteName'] as String?) ?? '',
      date: (json['date'] as String?) ?? (json['dateLabel'] as String?) ?? '',
      shiftLabel: json['shiftLabel'] as String?,
      relieving:
          json['relieving'] == true || (json['type'] as String?) == 'relieving',
      examName: json['examName'] as String?,
      willingness: _willingnessFrom(json['willingness']),
      siteId: json['siteId'] as String? ?? '',
      district: json['district'] as String? ?? '',
      status: json['status'] as String? ?? 'assigned',
      startsAt: json['startsAt'] as String?,
      endsAt: json['endsAt'] as String?,
      workOrderId: json['workOrderId'] as String?,
      examCode: json['examCode'] as String?,
      maleGuardsRequired: (json['maleGuardsRequired'] as num?)?.toInt(),
      femaleGuardsRequired: (json['femaleGuardsRequired'] as num?)?.toInt(),
      willingnessVersion: (json['willingnessVersion'] as num?)?.toInt() ?? 0,
      canRespond:
          json['canRespond'] == true &&
          json['kind'] == 'exam' &&
          json['status'] == 'open',
      respondBy: json['respondBy'] as String?,
      ineligibilityReason: json['ineligibilityReason'] as String?,
    );
  }
}

WillingnessStatus? _willingnessFrom(Object? value) {
  switch (value?.toString()) {
    case 'willing':
      return WillingnessStatus.willing;
    case 'unavailable':
      return WillingnessStatus.unavailable;
    default:
      return null;
  }
}

class WillingnessReceipt {
  const WillingnessReceipt({
    required this.response,
    required this.version,
    this.respondedAt,
    this.replayed = false,
  });
  final WillingnessStatus response;
  final int version;
  final String? respondedAt;
  final bool replayed;
  factory WillingnessReceipt.fromJson(Map<String, dynamic> json) {
    final value = json['willingness'];
    if (json['success'] != true ||
        value is! Map ||
        _willingnessFrom(value['response']) == null ||
        value['version'] is! int) {
      throw const FormatException('Invalid willingness receipt');
    }
    return WillingnessReceipt(
      response: _willingnessFrom(value['response'])!,
      version: value['version'] as int,
      respondedAt: value['respondedAt'] as String?,
      replayed: json['replayed'] == true,
    );
  }
}

class WorkOrderWillingness {
  const WorkOrderWillingness({
    required this.workOrderId,
    required this.willingCount,
    required this.unavailableCount,
    required this.responses,
  });
  final String workOrderId;
  final int willingCount, unavailableCount;
  final List<Map<String, dynamic>> responses;
  factory WorkOrderWillingness.fromJson(Map<String, dynamic> json) =>
      WorkOrderWillingness(
        workOrderId: json['workOrderId'] as String? ?? '',
        willingCount: (json['willingCount'] as num?)?.toInt() ?? 0,
        unavailableCount: (json['unavailableCount'] as num?)?.toInt() ?? 0,
        responses:
            (json['responses'] as List? ?? [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
      );
}

class GuardAssignment {
  GuardAssignment(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  int get version => (data['version'] as num).toInt();
  String get status => data['status'] as String? ?? 'assigned';
  String get guardName => data['guardName'] as String? ?? '';
  String get siteName => data['siteName'] as String? ?? '';
  String get date => data['date'] as String? ?? '';
}
