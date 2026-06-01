// Mirrors the QR parsing logic from the CISS web app:
//   src/lib/qr/employee-qr.ts  —  parseEmployeeQrText()
//   src/lib/qr/qr-token.ts     —  parseQrContent()
//
// Expected QR text format (new signed format):
//   CISS-ATTENDANCE
//   Employee ID: CISS/EMP001
//   Name: John Doe
//   Phone: 9876543210
//   Token: abc123...
//
// Legacy format (backward compatible):
//   Employee ID: CISS/EMP001
//   Phone: 9876543210

const _employeeIdLabelRe = r'Employee\s*ID\s*:\s*([^\n\r]+)';
const _nameLabelRe = r'Name\s*:\s*([^\n\r]+)';
const _phoneLabelRe = r'Phone\s*:\s*([^\n\r]+)';
const _tokenLabelRe = r'Token\s*:\s*([^\n\r\s]+)';
const _cissIdRe = r'CISS/[^\s\r\n]+';

String _normalizeQrText(String text) {
  return text.replaceAll('\u0000', '').trim();
}

/// Parsed QR content with all available fields.
({
  String? employeeId,
  String? name,
  String? phoneNumber,
  String? token,
})
parseQrContent(String text) {
  final normalized = _normalizeQrText(text);
  if (normalized.isEmpty) {
    return (employeeId: null, name: null, phoneNumber: null, token: null);
  }

  // Try labeled extraction
  final labeledMatch =
      RegExp(_employeeIdLabelRe, caseSensitive: false).firstMatch(normalized);
  final cissMatch =
      RegExp(_cissIdRe, caseSensitive: false).firstMatch(normalized);
  final employeeId =
      labeledMatch?.group(1)?.trim() ?? cissMatch?.group(0)?.trim();

  final nameMatch =
      RegExp(_nameLabelRe, caseSensitive: false).firstMatch(normalized);
  final name = nameMatch?.group(1)?.trim();

  // Phone number — extract last 10 digits
  final phoneMatch =
      RegExp(_phoneLabelRe, caseSensitive: false).firstMatch(normalized);
  final rawPhone =
      phoneMatch?.group(1)?.replaceAll(RegExp(r'\D'), '').trim() ?? '';
  final last10 =
      rawPhone.length >= 10 ? rawPhone.substring(rawPhone.length - 10) : rawPhone;
  final phoneNumber = RegExp(r'^\d{10}$').hasMatch(last10) ? last10 : null;

  // Token extraction
  final tokenMatch =
      RegExp(_tokenLabelRe, caseSensitive: false).firstMatch(normalized);
  final token = tokenMatch?.group(1)?.trim();

  // Fallback: first line starting with CISS/
  final firstLine = normalized.split(RegExp(r'\r?\n')).first.trim();
  final fallbackEmployeeId =
      (firstLine.isNotEmpty && firstLine.startsWith('CISS/')) ? firstLine : null;

  return (
    employeeId: employeeId ?? fallbackEmployeeId,
    name: name,
    phoneNumber: phoneNumber,
    token: token,
  );
}

({String? employeeId, String? phoneNumber}) parseEmployeeQrText(String text) {
  final parsed = parseQrContent(text);
  return (employeeId: parsed.employeeId, phoneNumber: parsed.phoneNumber);
}

String? parseEmployeeIdFromQrText(String text) {
  return parseEmployeeQrText(text).employeeId;
}
