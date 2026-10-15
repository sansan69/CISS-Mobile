/// The span of time one duty covers.
///
/// Attendance is stored against a calendar date, but a 20:00→06:00 duty spans
/// two of them: the check-out lands on the next date, so a reader that only
/// looks at one date sees an unpaired punch and reports the guard as off duty
/// at midnight. This model keeps the *business date* (the day the shift
/// belongs to) separate from the calendar dates the window touches.
class ShiftWindow {
  const ShiftWindow({
    required this.businessDate,
    required this.start,
    required this.end,
  });

  /// Midnight of the day this shift belongs to.
  final DateTime businessDate;
  final DateTime start;
  final DateTime end;

  /// True when the window touches two calendar dates.
  bool get crossesMidnight =>
      start.year != end.year ||
      start.month != end.month ||
      start.day != end.day;

  Duration get length => end.difference(start);

  bool contains(DateTime moment) =>
      !moment.isBefore(start) && !moment.isAfter(end);

  /// True once [moment] is past the end of the shift by more than [grace].
  bool hasEndedBy(DateTime moment, {Duration grace = Duration.zero}) =>
      moment.isAfter(end.add(grace));

  @override
  String toString() =>
      'ShiftWindow($businessDate → $start..$end, crosses=$crossesMidnight)';
}

/// A duty that names no hours runs this long from its check-in.
const Duration defaultShiftLength = Duration(hours: 12);

/// Night duties run 20:00 → 06:00 when the roster names a shift but no hours.
const Duration nightShiftStart = Duration(hours: 20);
const Duration nightShiftEnd = Duration(hours: 6);

/// Midnight of [moment], keeping the local zone.
DateTime startOfDay(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// Builds the window a punch belongs to.
///
/// [businessDate] is the date the roster assigned the duty to. The hours come
/// from [shiftLabel] when it names them (`20:00-06:00`, `20:00 – 06:00`,
/// `8 PM to 6 AM`) or names a night duty; otherwise the window runs
/// [defaultShiftLength] from [checkIn], which is the best available evidence
/// when the roster says only "Morning".
ShiftWindow shiftWindowFor({
  required DateTime businessDate,
  String? shiftLabel,
  required DateTime checkIn,
  DateTime? shiftStartsAt,
  DateTime? shiftEndsAt,
}) {
  final day = startOfDay(businessDate);
  if (shiftStartsAt != null &&
      shiftEndsAt != null &&
      shiftEndsAt.isAfter(shiftStartsAt)) {
    return ShiftWindow(
      businessDate: day,
      start: shiftStartsAt,
      end: shiftEndsAt,
    );
  }
  final clock = shiftClockFrom(shiftLabel);
  if (clock != null) {
    final start = day.add(clock.start);
    var end = day.add(clock.end);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    return ShiftWindow(businessDate: day, start: start, end: end);
  }
  final start = checkIn;
  return ShiftWindow(
    businessDate: day,
    start: start,
    end: start.add(defaultShiftLength),
  );
}

/// The start and end offsets from midnight a roster label names, or null when
/// it names neither hours nor a night duty.
({Duration start, Duration end})? shiftClockFrom(String? shiftLabel) {
  final label = shiftLabel?.trim().toLowerCase() ?? '';
  if (label.isEmpty) return null;

  final clocks = _clockMatches(label);
  if (clocks.length >= 2) {
    return (start: clocks[0], end: clocks[1]);
  }
  if (label.contains('night')) {
    return (start: nightShiftStart, end: nightShiftEnd);
  }
  return null;
}

/// Every `HH:mm`, `H.mm` or `H am/pm` in the label, as an offset from
/// midnight. A trailing period is ignored so "8 PM." still parses.
final RegExp _clockPattern = RegExp(
  r'(\d{1,2}):(\d{2})\s*(am|pm)?|(\d{1,2})\s*(am|pm)',
  caseSensitive: false,
);

List<Duration> _clockMatches(String label) {
  final matches = <Duration>[];
  for (final match in _clockPattern.allMatches(label)) {
    final colonHour = match.group(1);
    if (colonHour != null) {
      final hour = int.parse(colonHour);
      final minute = int.parse(match.group(2)!);
      final meridiem = match.group(3);
      final offset = _offsetOf(hour, minute, meridiem, requireMeridiem: false);
      if (offset != null) matches.add(offset);
      continue;
    }
    final bareHour = int.parse(match.group(4)!);
    final offset = _offsetOf(
      bareHour,
      0,
      match.group(5),
      requireMeridiem: true,
    );
    if (offset != null) matches.add(offset);
  }
  return matches;
}

Duration? _offsetOf(
  int hour,
  int minute,
  String? meridiem, {
  required bool requireMeridiem,
}) {
  if (minute > 59) return null;
  if (meridiem == null) {
    // Without a meridiem the only unambiguous reading is 24-hour time.
    if (requireMeridiem || hour > 23) return null;
    return Duration(hours: hour, minutes: minute);
  }
  if (hour > 12) return null;
  final normalised = hour % 12 + (meridiem.toLowerCase() == 'pm' ? 12 : 0);
  return Duration(hours: normalised, minutes: minute);
}
