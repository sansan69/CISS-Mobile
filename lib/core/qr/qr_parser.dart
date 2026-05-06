// Mirrors the QR parsing logic from the CISS web app:
//   src/lib/qr/employee-qr.ts  —  parseEmployeeQrText()
//
// Expected QR text format:
//   Employee ID: CISS/EMP001
//   Phone: 9876543210

const _employeeIdLabelRe = r'Employee\s*ID\s*:\s*([^\n\r]+)';
const _phoneLabelRe = r'Phone\s*:\s*([^\n\r]+)';
const _cissIdRe = r'CISS/[^\s\r\n]+';

String _normalizeQrText(String text) {
  return text.replaceAll('\u0000', '').trim();
}

({String? employeeId, String? phoneNumber}) parseEmployeeQrText(String text) {
  final normalized = _normalizeQrText(text);
  if (normalized.isEmpty) {
    return (employeeId: null, phoneNumber: null);
  }

  // Try labeled extraction
  final labeledMatch =
      RegExp(_employeeIdLabelRe, caseSensitive: false).firstMatch(normalized);
  final cissMatch =
      RegExp(_cissIdRe, caseSensitive: false).firstMatch(normalized);
  final employeeId =
      labeledMatch?.group(1)?.trim() ?? cissMatch?.group(0)?.trim();

  // Phone number — extract last 10 digits
  final phoneMatch =
      RegExp(_phoneLabelRe, caseSensitive: false).firstMatch(normalized);
  final rawPhone =
      phoneMatch?.group(1)?.replaceAll(RegExp(r'\D'), '').trim() ?? '';
  final last10 =
      rawPhone.length >= 10 ? rawPhone.substring(rawPhone.length - 10) : rawPhone;
  final phoneNumber = RegExp(r'^\d{10}$').hasMatch(last10) ? last10 : null;

  // Fallback: first line starting with CISS/
  final firstLine = normalized.split(RegExp(r'\r?\n')).first.trim();
  final fallbackEmployeeId =
      (firstLine.isNotEmpty && firstLine.startsWith('CISS/')) ? firstLine : null;

  return (
    employeeId: employeeId ?? fallbackEmployeeId,
    phoneNumber: phoneNumber,
  );
}

String? parseEmployeeIdFromQrText(String text) {
  return parseEmployeeQrText(text).employeeId;
}
