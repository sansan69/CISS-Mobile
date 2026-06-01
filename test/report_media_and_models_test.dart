import 'package:ciss_mobile/core/models/report_models.dart';
import 'package:ciss_mobile/shared/utils/report_media_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('report media helpers', () {
    test('sanitizeReportFileName keeps storage-safe characters', () {
      expect(
        sanitizeReportFileName('  training report (final).pdf  '),
        'training_report_final_.pdf',
      );
    });

    test('mimeTypeFromFileName maps common report uploads', () {
      expect(mimeTypeFromFileName('minutes.pdf'), 'application/pdf');
      expect(
        mimeTypeFromFileName('briefing.docx'),
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      expect(mimeTypeFromFileName('photo.png'), 'image/png');
    });
  });

  group('TrainingReportModel', () {
    test('parses attachment urls from backend payload', () {
      final model = TrainingReportModel.fromJson(<String, dynamic>{
        'id': 'training-1',
        'siteName': 'Site A',
        'clientName': 'Client X',
        'district': 'Kochi',
        'trainingDate': '2026-05-25',
        'topic': 'Safety briefing',
        'description': 'Briefing notes',
        'attendeeCount': 8,
        'durationMinutes': 45,
        'status': 'submitted',
        'photoUrls': <String>['https://example.com/photo.png'],
        'attachmentUrls': <String>['https://example.com/report.pdf'],
      });

      expect(model.photoUrls, hasLength(1));
      expect(model.attachmentUrls, hasLength(1));
      expect(model.attachmentUrls.single, contains('report.pdf'));
    });
  });
}
