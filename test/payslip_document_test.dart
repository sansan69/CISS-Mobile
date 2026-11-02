import 'package:ciss_mobile/core/models/payslip_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PayslipDocumentModel.fromJson', () {
    test('parses the documented GET /api/guard/payslips payload', () {
      final payslip = PayslipDocumentModel.fromJson(<String, dynamic>{
        'id': 'slip_2026_09',
        'period': '2026-09',
        'fileName': 'CISS-Sep-2026.pdf',
        'sizeBytes': 188416,
        'createdAt': '2026-10-02T09:15:00.000Z',
        'employeeId': 'CISS/TCS/2025-26/871',
      });

      expect(payslip.id, 'slip_2026_09');
      expect(payslip.period, '2026-09');
      expect(payslip.fileName, 'CISS-Sep-2026.pdf');
      expect(payslip.sizeBytes, 188416);
      expect(payslip.createdAt?.toUtc().toIso8601String(), '2026-10-02T09:15:00.000Z');
      expect(payslip.employeeId, 'CISS/TCS/2025-26/871');
      expect(payslip.title, '2026-09');
      expect(payslip.safeFileName, 'CISS-Sep-2026.pdf');
    });

    test('tolerates missing, null and mistyped fields', () {
      final payslip = PayslipDocumentModel.fromJson(<String, dynamic>{
        'id': 42,
        'period': null,
        'fileName': '   ',
        'sizeBytes': '2048',
        'createdAt': 'not-a-date',
        'employeeId': '',
      });

      expect(payslip.id, '42');
      expect(payslip.period, '');
      expect(payslip.fileName, '');
      expect(payslip.sizeBytes, 2048, reason: 'numeric strings are accepted');
      expect(payslip.createdAt, isNull, reason: 'unparsable dates are dropped');
      expect(payslip.employeeId, isNull);
      expect(payslip.title, isNot(isEmpty));
      expect(payslip.safeFileName, endsWith('.pdf'));
    });

    test('accepts a numeric size as double and rejects negatives', () {
      expect(
        PayslipDocumentModel.fromJson(<String, dynamic>{
          'id': 'a',
          'sizeBytes': 1024.0,
        }).sizeBytes,
        1024,
      );
      expect(
        PayslipDocumentModel.fromJson(<String, dynamic>{
          'id': 'a',
          'sizeBytes': -5,
        }).sizeBytes,
        isNull,
      );
      expect(
        PayslipDocumentModel.fromJson(<String, dynamic>{'id': 'a'}).sizeBytes,
        isNull,
      );
    });

    test('accepts an already-parsed DateTime', () {
      final created = DateTime(2026, 10, 2, 9, 15);
      expect(
        PayslipDocumentModel.fromJson(<String, dynamic>{
          'id': 'a',
          'createdAt': created,
        }).createdAt,
        created,
      );
    });
  });

  group('presentation helpers', () {
    test('sizeLabel renders B, KB and MB', () {
      String label(int bytes) =>
          PayslipDocumentModel(
            id: 'a',
            period: '2026-09',
            fileName: 'a.pdf',
            sizeBytes: bytes,
          ).sizeLabel;

      expect(label(512), '512 B');
      expect(label(2048), '2.0 KB');
      expect(label(188416), '184 KB');
      expect(label(3 * 1024 * 1024), '3.0 MB');
      expect(
        const PayslipDocumentModel(
          id: 'a',
          period: '2026-09',
          fileName: 'a.pdf',
          sizeBytes: null,
        ).sizeLabel,
        isEmpty,
      );
    });

    test('safeFileName strips path separators and enforces a .pdf suffix', () {
      const payslip = PayslipDocumentModel(
        id: 'slip id/1',
        period: '09 2026',
        fileName: '../../etc/passwd',
        sizeBytes: 10,
      );
      expect(payslip.safeFileName, isNot(contains('/')));
      expect(payslip.safeFileName, isNot(contains('..')));
      expect(payslip.safeFileName, endsWith('.pdf'));

      const noName = PayslipDocumentModel(
        id: 'slip-1',
        period: '2026-09',
        fileName: '',
        sizeBytes: 10,
      );
      expect(noName.safeFileName, 'payslip-2026-09.pdf');
    });

    test('title falls back to the file name and then a generic label', () {
      expect(
        const PayslipDocumentModel(
          id: 'a',
          period: '',
          fileName: 'slip.pdf',
          sizeBytes: null,
        ).title,
        'slip.pdf',
      );
      expect(
        const PayslipDocumentModel(
          id: 'a',
          period: '',
          fileName: '',
          sizeBytes: null,
        ).title,
        'Salary slip',
      );
    });
  });
}
