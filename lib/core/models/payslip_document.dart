/// A published salary slip (PDF) the signed-in guard can download.
///
/// The document is produced by the admin bulk upload; the app never computes
/// payroll. Fields mirror `GET /api/guard/payslips`:
/// `{id, period, fileName, sizeBytes, createdAt, employeeId}`.
class PayslipDocumentModel {
  const PayslipDocumentModel({
    required this.id,
    required this.period,
    required this.fileName,
    required this.sizeBytes,
    this.createdAt,
    this.employeeId,
  });

  /// Server-side document id, used to fetch the binary.
  final String id;

  /// Human period label, e.g. `2026-09` or `September 2026`.
  final String period;

  /// Original file name as uploaded by the admin.
  final String fileName;

  /// Document size in bytes; `null` when the server did not report it.
  final int? sizeBytes;

  /// Upload/publish timestamp; `null` when absent or unparsable.
  final DateTime? createdAt;

  /// Employee code this slip belongs to, when the server includes it.
  final String? employeeId;

  /// Tolerant parse: the payload is presentation data and a single malformed
  /// field must not blank the whole list.
  factory PayslipDocumentModel.fromJson(Map<String, dynamic> json) {
    final rawSize = json['sizeBytes'];
    final sizeBytes =
        rawSize is num
            ? rawSize.toInt()
            : rawSize is String
            ? int.tryParse(rawSize.trim())
            : null;
    return PayslipDocumentModel(
      id: _asText(json['id']),
      period: _asText(json['period']),
      fileName: _asText(json['fileName']),
      sizeBytes: sizeBytes == null || sizeBytes < 0 ? null : sizeBytes,
      createdAt: _asDate(json['createdAt']),
      employeeId: _asTextOrNull(json['employeeId']),
    );
  }

  /// Title used in the list: the period, falling back to the file name.
  String get title =>
      period.trim().isNotEmpty
          ? period.trim()
          : (fileName.trim().isNotEmpty ? fileName.trim() : 'Salary slip');

  /// File name to save the downloaded PDF as, sanitised for the filesystem.
  String get safeFileName {
    final base =
        fileName.trim().isNotEmpty
            ? fileName.trim()
            : 'payslip-${period.trim().isEmpty ? id : period.trim()}.pdf';
    final sanitized =
        base
            .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
            // No path separators survive above; collapse dot runs anyway so a
            // crafted name can never become a `..` path component.
            .replaceAll(RegExp(r'\.{2,}'), '.')
            .replaceAll(RegExp(r'^[._]+'), '');
    final usable = sanitized.isEmpty ? 'payslip' : sanitized;
    return usable.toLowerCase().endsWith('.pdf')
        ? usable
        : '$usable.pdf';
  }

  /// Compact size label, e.g. `184 KB`. Empty when the size is unknown.
  String get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  static String _asText(Object? value) => _asTextOrNull(value) ?? '';

  static String? _asTextOrNull(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _asDate(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }
}
