import '../models/mobile_dashboard_models.dart';
import 'shift_window.dart';

/// Two check-ins this close together are a double tap on the same duty.
/// Further apart, the first duty went off shift without punching, so it is a
/// forgotten check-out rather than a duplicate — the office can tune this.
const Duration duplicateCheckInTolerance = Duration(hours: 1);

enum PunchKind { checkIn, checkOut }

/// How a check-in and its check-out line up.
enum PunchPairStatus {
  /// Both punches recorded.
  closed,

  /// The guard is still on duty: no check-out yet and the shift has not run
  /// past its end.
  open,

  /// A punch without its counterpart: either a check-out that never came
  /// (once the shift is past its end) or a check-out whose check-in was not
  /// returned by the fetch.
  missedCheckOut,

  /// A second check-in arrived while the shift was still open. The earlier
  /// pair is incomplete and must stop counting as on duty.
  duplicateCheckIn,
}

/// One duty attempt for a guard: a check-in, its check-out when it happened,
/// and the shift window that decides whether the pair is complete.
class PunchPair {
  const PunchPair({
    required this.guardKey,
    required this.businessDate,
    required this.window,
    required this.status,
    this.checkInEntry,
    this.checkOutEntry,
    this.checkIn,
    this.checkOut,
  });

  final String guardKey;

  /// The date this duty belongs to — the check-in's date for a night shift,
  /// so a 05:40 check-out is reported under the previous day.
  final DateTime businessDate;

  /// Null when only a check-out was observed.
  final ShiftWindow? window;
  final PunchPairStatus status;
  final FieldOfficerAttendanceEntry? checkInEntry;
  final FieldOfficerAttendanceEntry? checkOutEntry;
  final DateTime? checkIn;
  final DateTime? checkOut;

  /// T2.4 counts only [`PunchPairStatus.open`] pairs as on duty, so a shift
  /// that never closed, or one that was abandoned for a second check-in,
  /// cannot inflate the muster roll.
  bool get isOnDuty => status == PunchPairStatus.open;

  /// True when a check-out is genuinely missing and someone should review it.
  bool get needsCheckOutReview =>
      status == PunchPairStatus.missedCheckOut && checkIn != null;

  /// True when this shift never closed and its window has *just* ended — the
  /// morning after an overnight tour, say — rather than a historical gap the
  /// office has already dealt with.
  ///
  /// This is what keeps a night guard who forgot to check out visible on the
  /// next day's feed: their shift belongs to yesterday's business date, so a
  /// filter that keys on the business date alone would hide exactly the case a
  /// supervisor needs to chase.
  bool needsReviewWithin(
    DateTime now, {
    Duration lookback = const Duration(days: 1),
  }) {
    if (!needsCheckOutReview) return false;
    final end = window?.end;
    if (end == null || end.isAfter(now)) return false;
    return now.difference(end) <= lookback;
  }

  /// The row a list should render for this pair: the shift start when it was
  /// observed, otherwise the only punch there is.
  FieldOfficerAttendanceEntry get entry => checkInEntry ?? checkOutEntry!;

  @override
  String toString() =>
      'PunchPair($guardKey, $status, $checkIn..$checkOut, date=$businessDate)';
}

/// Stable identity for a guard across rows. Employee id is the roster's key;
/// the app falls back to the guard id and then the name so rows from a
/// degraded payload still pair instead of silently disappearing.
String attendanceGuardKey(FieldOfficerAttendanceEntry row) {
  final employee = row.employeeId.trim();
  if (employee.isNotEmpty) return 'emp:$employee';
  final guard = row.guardId.trim();
  if (guard.isNotEmpty) return 'guard:$guard';
  final name = row.guardName.trim().toLowerCase();
  return name.isEmpty ? '' : 'name:$name';
}

/// Identity for one attendance row, used to de-duplicate overlapping fetches.
String attendanceRowKey(FieldOfficerAttendanceEntry row) {
  final id = row.id.trim();
  if (id.isNotEmpty) return 'id:$id';
  return <String>[
    attendanceGuardKey(row),
    row.dateLabel,
    row.checkIn ?? '',
    row.checkOut ?? '',
    row.dutyPointName,
  ].join('|');
}

/// Merges overlapping fetches into one row set, keeping the first occurrence
/// of every row.
List<FieldOfficerAttendanceEntry> mergeAttendanceRows(
  Iterable<Iterable<FieldOfficerAttendanceEntry>> batches,
) {
  final seen = <String>{};
  final merged = <FieldOfficerAttendanceEntry>[];
  for (final batch in batches) {
    for (final row in batch) {
      if (!seen.add(attendanceRowKey(row))) continue;
      merged.add(row);
    }
  }
  return merged;
}

/// Pairs every row's punches into closed, open or incomplete duties.
///
/// A check-out pairs with the latest open check-in **regardless of calendar
/// date**, as long as it lands within the shift window plus [grace]; that is
/// what makes a 20:00 → 06:10 night duty one pair instead of two orphans.
/// [now] decides whether an unclosed check-in is still on duty or has become a
/// missed check-out, so callers must pass a fixed clock in tests.
List<PunchPair> pairPunches(
  List<FieldOfficerAttendanceEntry> rows, {
  required DateTime now,
  Duration grace = const Duration(hours: 2),
  DateTime? fallbackDate,
}) {
  final byGuard = <String, List<_Punch>>{};
  for (final row in rows) {
    final key = attendanceGuardKey(row);
    if (key.isEmpty) continue;
    // A row whose date cannot be parsed still happened. Attaching it to the
    // business date being viewed keeps the punch visible instead of dropping
    // it silently from every surface.
    final rowDate = parseRowDate(row.dateLabel) ?? fallbackDate;
    final checkIn = parsePunchTime(row.checkIn, onDate: rowDate);
    var checkOut = parsePunchTime(row.checkOut, onDate: rowDate);
    // A row that carries both clock times walked past midnight: the server
    // sent 20:05 and 06:10 under one date.
    if (checkIn != null && checkOut != null && !checkOut.isAfter(checkIn)) {
      checkOut = checkOut.add(const Duration(days: 1));
    }
    final punches = byGuard.putIfAbsent(key, () => <_Punch>[]);
    if (checkIn != null) {
      punches.add(
        _Punch(
          at: checkIn,
          kind: PunchKind.checkIn,
          row: row,
          rowDate: rowDate ?? startOfDay(checkIn),
        ),
      );
    }
    if (checkOut != null) {
      punches.add(
        _Punch(
          at: checkOut,
          kind: PunchKind.checkOut,
          row: row,
          rowDate: rowDate ?? startOfDay(checkOut),
        ),
      );
    }
  }

  final pairs = <PunchPair>[];
  for (final entry in byGuard.entries) {
    pairs.addAll(_pairGuard(entry.key, entry.value, now: now, grace: grace));
  }
  pairs.sort(_byPunchTime);
  return pairs;
}

/// Pairs grouped under the business date they belong to, oldest first.
Map<DateTime, List<PunchPair>> groupByBusinessDate(List<PunchPair> pairs) {
  final grouped = <DateTime, List<PunchPair>>{};
  for (final pair in pairs) {
    grouped.putIfAbsent(pair.businessDate, () => <PunchPair>[]).add(pair);
  }
  final dates = grouped.keys.toList()..sort();
  return <DateTime, List<PunchPair>>{
    for (final date in dates)
      date: grouped[date]!..sort(_byPunchTime),
  };
}

/// Parses the date a row is filed under. The backend sends either an ISO date
/// (`2026-10-14`, sometimes with a time) or a display label (`14 Oct 2026`,
/// `14-Oct-2026`). Returns null when neither parses.
DateTime? parseRowDate(String? raw) {
  final label = raw?.trim() ?? '';
  if (label.isEmpty) return null;
  final iso = DateTime.tryParse(label);
  if (iso != null) return startOfDay(iso.toLocal());
  // The app's own display format is dd/MM/yyyy, so accept it back.
  final numeric = _dayMonthYearNumeric.firstMatch(label);
  if (numeric != null) {
    final day = int.tryParse(numeric.group(1)!);
    final month = int.tryParse(numeric.group(2)!);
    final year = int.tryParse(numeric.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (day < 1 || day > 31 || month < 1 || month > 12) return null;
    return DateTime(year, month, day);
  }
  final match = _dayMonthYear.firstMatch(label);
  if (match == null) return null;
  final day = int.tryParse(match.group(1)!);
  final month = _monthIndex(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  if (day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

/// Parses one punch. Accepts an ISO timestamp, `HH:mm`, `HH:mm:ss`, `H.mm` and
/// `H:mm am/pm`. A bare clock time needs [onDate] to pick a calendar date.
DateTime? parsePunchTime(String? raw, {DateTime? onDate}) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso.toLocal();

  final match = _punchClock.firstMatch(value);
  if (match == null || onDate == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final second = int.tryParse(match.group(3) ?? '') ?? 0;
  final meridiem = match.group(4);
  if (minute > 59 || second > 59) return null;
  int normalised;
  if (meridiem == null) {
    if (hour > 23) return null;
    normalised = hour;
  } else {
    if (hour > 12) return null;
    normalised = hour % 12 + (meridiem.toLowerCase() == 'pm' ? 12 : 0);
  }
  return DateTime(
    onDate.year,
    onDate.month,
    onDate.day,
    normalised,
    minute,
    second,
  );
}

List<PunchPair> _pairGuard(
  String guardKey,
  List<_Punch> punches, {
  required DateTime now,
  required Duration grace,
}) {
  punches.sort((a, b) {
    final byTime = a.at.compareTo(b.at);
    if (byTime != 0) return byTime;
    // Two punches at the same instant cannot be ordered by time; open the pair
    // with the check-in so the check-out can close it.
    if (a.kind == b.kind) return 0;
    return a.kind == PunchKind.checkIn ? -1 : 1;
  });

  final pairs = <PunchPair>[];
  _Punch? open;
  for (final punch in punches) {
    if (punch.kind == PunchKind.checkIn) {
      if (open != null) {
        // A second check-in while one is open is either a duplicate tap or a
        // forgotten check-out. The gap settles it: seconds apart is a retry,
        // hours apart means the guard went off duty without punching, and the
        // earlier duty has to be reviewed rather than filed as a double tap.
        final forgotten =
            punch.at.difference(open.at) > duplicateCheckInTolerance;
        pairs.add(
          _pair(
            guardKey,
            open,
            null,
            forgotten
                ? PunchPairStatus.missedCheckOut
                : PunchPairStatus.duplicateCheckIn,
          ),
        );
      }
      open = punch;
      continue;
    }
    if (open == null) {
      // The shift started before the fetched window, so there is nothing to
      // close against.
      pairs.add(_pair(guardKey, null, punch, PunchPairStatus.missedCheckOut));
      continue;
    }
    final window = _windowFor(open);
    final span = punch.at.difference(open.at);
    if (span.isNegative || span > window.length + grace) {
      pairs.add(_pair(guardKey, open, null, PunchPairStatus.missedCheckOut));
      pairs.add(_pair(guardKey, null, punch, PunchPairStatus.missedCheckOut));
      open = null;
      continue;
    }
    pairs.add(_pair(guardKey, open, punch, PunchPairStatus.closed));
    open = null;
  }

  if (open != null) {
    final window = _windowFor(open);
    pairs.add(
      _pair(
        guardKey,
        open,
        null,
        window.hasEndedBy(now, grace: grace)
            ? PunchPairStatus.missedCheckOut
            : PunchPairStatus.open,
      ),
    );
  }
  return pairs;
}

ShiftWindow _windowFor(_Punch punch) => shiftWindowFor(
  businessDate: punch.rowDate,
  shiftLabel: punch.row.shiftLabel,
  checkIn: punch.at,
);

PunchPair _pair(
  String guardKey,
  _Punch? checkIn,
  _Punch? checkOut,
  PunchPairStatus status,
) {
  final anchor = checkIn ?? checkOut!;
  final window = checkIn == null ? null : _windowFor(checkIn);
  return PunchPair(
    guardKey: guardKey,
    businessDate: checkIn?.rowDate ?? anchor.rowDate,
    window: window,
    status: status,
    checkInEntry: checkIn?.row,
    checkOutEntry: checkOut?.row,
    checkIn: checkIn?.at,
    checkOut: checkOut?.at,
  );
}

int _byPunchTime(PunchPair a, PunchPair b) =>
    (a.checkIn ?? a.checkOut!).compareTo(b.checkIn ?? b.checkOut!);

class _Punch {
  const _Punch({
    required this.at,
    required this.kind,
    required this.row,
    required this.rowDate,
  });

  final DateTime at;
  final PunchKind kind;
  final FieldOfficerAttendanceEntry row;
  final DateTime rowDate;
}

final RegExp _dayMonthYear = RegExp(
  r'(\d{1,2})[\s,/-]+([A-Za-z]{3,})[\s,/-]+(\d{4})',
);

final RegExp _dayMonthYearNumeric = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$');

final RegExp _punchClock = RegExp(
  r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm)?$',
  caseSensitive: false,
);

const List<String> _monthNames = <String>[
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

int? _monthIndex(String name) {
  final key = name.length >= 3
      ? name.substring(0, 3).toLowerCase()
      : name.toLowerCase();
  final index = _monthNames.indexOf(key);
  return index == -1 ? null : index + 1;
}
