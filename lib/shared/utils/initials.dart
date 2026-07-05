/// Extracts up to 2 initials from a name string.
/// Returns [fallback] if no valid initials can be extracted.
String initials(String name, {String fallback = ''}) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final result = parts.map((p) => p[0]).take(2).join().toUpperCase();
  return result.isNotEmpty ? result : fallback;
}
