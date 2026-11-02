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
