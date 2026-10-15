// Shared date/time formatting utilities used across attendance screens.

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatAttendanceDateTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final am = dt.hour < 12 ? 'AM' : 'PM';
  final min = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${_months[dt.month - 1]} ${dt.year}, $h:$min $am';
}

/// Formats a known duty date while preserving non-ISO server display labels.
String formatDutyDate(String? value) {
  final label = value?.trim() ?? '';
  if (label.isEmpty) return '';
  final parsed = DateTime.tryParse(label);
  if (parsed == null) return label;
  final local = parsed.toLocal();
  if (label.contains('T')) return formatAttendanceDateTime(local);
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}
