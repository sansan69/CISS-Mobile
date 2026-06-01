import 'dart:math' as math;

// Shared date/time formatting utilities used across attendance screens.

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatAttendanceDateTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final am = dt.hour < 12 ? 'AM' : 'PM';
  final min = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${_months[dt.month - 1]} ${dt.year}, $h:$min $am';
}

/// Returns a human-readable relative time string (e.g. "5m ago", "2h ago").
String formatTimeSince(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Calculates distance in meters between two GPS coordinates using Haversine.
double calculateDistanceMeters(
    double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * 3.141592653589793 / 180;
  final dLng = (lng2 - lng1) * 3.141592653589793 / 180;
  final a =
      (1 - math.cos(dLat)) / 2 +
      math.cos(lat1 * 3.141592653589793 / 180) *
          math.cos(lat2 * 3.141592653589793 / 180) *
          (1 - math.cos(dLng)) / 2;
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
