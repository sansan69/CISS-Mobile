import '../../../core/attendance/attendance_pairing.dart';
import '../../../core/attendance/shift_window.dart';
import '../../../core/models/attendance_models.dart';

/// A duty the guard has checked in to and not yet closed.
class OpenDutySession {
  const OpenDutySession({
    required this.checkInAt,
    required this.window,
    required this.siteName,
    required this.dutyPointName,
    required this.shiftLabel,
    required this.status,
  });

  final DateTime checkInAt;
  final ShiftWindow window;
  final String siteName;
  final String dutyPointName;
  final String shiftLabel;
  final OpenDutyStatus status;

  /// True when the check-in happened before the day the guard is reading the
  /// screen on, which is what an overnight duty looks like at 02:00.
  bool startedBefore(DateTime moment) =>
      checkInAt.isBefore(startOfDay(moment));

  bool get isOpen => status == OpenDutyStatus.open;
}

enum OpenDutyStatus {
  /// Still inside the shift window: the guard is on duty.
  open,

  /// The window ended without a check-out, so the tour needs closing out.
  overdue,
}

/// Finds the guard's open duty in their own attendance log.
///
/// The log is a flat list of `In`/`Out` punches, one per record, so this walks
/// them in time order instead of pairing rows: an `In` opens a session, an
/// `Out` closes it, and a second `In` while one is open supersedes it. A
/// session whose window has ended is reported as [OpenDutyStatus.overdue]
/// rather than as on duty, which keeps the dashboard honest at 02:00 and after
/// a missed check-out.
OpenDutySession? openDutySession(
  List<AttendanceRecordModel> records, {
  required DateTime now,
  Duration grace = const Duration(hours: 2),
}) {
  final punches = <_Punch>[];
  for (final record in records) {
    final at = parsePunchTime(
      record.time,
      onDate: parseRowDate(record.dateLabel),
    );
    if (at == null) continue;
    final isIn = record.status.trim().toLowerCase() == 'in';
    if (!isIn && record.status.trim().toLowerCase() != 'out') continue;
    punches.add(_Punch(at: at, isIn: isIn, record: record));
  }
  if (punches.isEmpty) return null;
  punches.sort((a, b) => a.at.compareTo(b.at));

  _Punch? open;
  for (final punch in punches) {
    if (punch.isIn) {
      open = punch;
      continue;
    }
    open = null;
  }
  if (open == null) return null;

  final window = shiftWindowFor(
    businessDate: startOfDay(open.at),
    shiftLabel: open.record.shiftLabel,
    checkIn: open.at,
  );
  return OpenDutySession(
    checkInAt: open.at,
    window: window,
    siteName: open.record.siteName,
    dutyPointName: open.record.dutyPointName,
    shiftLabel: open.record.shiftLabel,
    status:
        window.hasEndedBy(now, grace: grace)
            ? OpenDutyStatus.overdue
            : OpenDutyStatus.open,
  );
}

class _Punch {
  const _Punch({required this.at, required this.isIn, required this.record});

  final DateTime at;
  final bool isIn;
  final AttendanceRecordModel record;
}
