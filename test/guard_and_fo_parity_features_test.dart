import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/app/theme/app_tokens.dart';
import 'package:ciss_mobile/shared/widgets/time_counter_chip.dart';
import 'package:ciss_mobile/shared/widgets/compliance_tag.dart';
import 'package:ciss_mobile/core/models/leave_models.dart';
import 'package:ciss_mobile/core/models/incident_models.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      extensions: <ThemeExtension<dynamic>>[
        CissThemeTokens.light(),
      ],
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('TimeCounterChip widget tests', () {
    testWidgets('displays remaining hours and minutes when target is in the future', (tester) async {
      final futureTime = DateTime.now().add(const Duration(hours: 1, minutes: 25, seconds: 5));

      await tester.pumpWidget(createTestApp(
        TimeCounterChip(targetTime: futureTime),
      ));
      await tester.pump();

      expect(find.byType(TimeCounterChip), findsOneWidget);
      expect(find.textContaining('1h 25m'), findsOneWidget);
    });

    testWidgets('displays imminent warning when under 15 minutes', (tester) async {
      final imminentTime = DateTime.now().add(const Duration(minutes: 8, seconds: 30));

      await tester.pumpWidget(createTestApp(
        TimeCounterChip(targetTime: imminentTime),
      ));
      await tester.pump();

      expect(find.textContaining('08m'), findsOneWidget);
    });

    testWidgets('displays overdue status when target is in past', (tester) async {
      final pastTime = DateTime.now().subtract(const Duration(minutes: 12, seconds: 5));

      await tester.pumpWidget(createTestApp(
        TimeCounterChip(targetTime: pastTime),
      ));
      await tester.pump();

      expect(find.textContaining('Overdue by 12m'), findsOneWidget);
    });
  });

  group('ComplianceTag widget tests', () {
    testWidgets('renders verified badge with check icon', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ComplianceTag(
          label: 'Aadhaar Card',
          status: ComplianceStatus.verified,
        ),
      ));
      await tester.pump();

      expect(find.text('Aadhaar Card: Verified'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('renders pending badge with hourglass icon', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ComplianceTag(
          label: 'Identity Proof',
          status: ComplianceStatus.pending,
        ),
      ));
      await tester.pump();

      expect(find.text('Identity Proof: Pending'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    });

    testWidgets('renders missing badge with info icon', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ComplianceTag(
          label: 'Bank Details',
          status: ComplianceStatus.missing,
        ),
      ));
      await tester.pump();

      expect(find.text('Bank Details: Missing'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });
  });

  group('Expanded Read Caching Contract', () {
    test('MobileRepository includes core Guard and FO GET endpoints in _cacheableReadPaths', () {
      final repoSource = File('lib/core/network/mobile_repository.dart').readAsStringSync();
      final expectedEndpoints = [
        "'/api/guard/dashboard'",
        "'/api/guard/training'",
        "'/api/guard/evaluations'",
        "'/api/guard/payslips'",
        "'/api/guard/leave'",
        "'/api/guard/incidents'",
        "'/api/guard/leaderboard'",
        "'/api/field-officer/dashboard'",
        "'/api/field-officer/work-orders'",
        "'/api/field-officer/sites'",
        "'/api/field-officer/guards'",
        "'/api/field-officer/incidents'",
        "'/api/field-officer/visit-reports'",
        "'/api/field-officer/training-reports'",
      ];

      for (final ep in expectedEndpoints) {
        expect(repoSource, contains(ep), reason: 'Expected $ep to be in _cacheableReadPaths');
      }
    });
  });

  group('Guard & FO Parity Models', () {
    test('LeaveRequestModel parses attachmentUrl and documentUrl fallback', () {
      final modelWithAttachment = LeaveRequestModel.fromJson({
        'id': 'leave-1',
        'type': 'sick',
        'fromDate': '2026-09-01',
        'toDate': '2026-09-02',
        'days': 2,
        'reason': 'High fever',
        'status': 'pending',
        'attachmentUrl': 'https://ciss.app/uploads/med-cert.jpg',
      });
      expect(modelWithAttachment.attachmentUrl, 'https://ciss.app/uploads/med-cert.jpg');

      final modelWithDocFallback = LeaveRequestModel.fromJson({
        'id': 'leave-2',
        'type': 'casual',
        'fromDate': '2026-09-05',
        'toDate': '2026-09-05',
        'days': 1,
        'reason': 'Personal work',
        'status': 'approved',
        'documentUrl': 'https://ciss.app/uploads/doc.pdf',
      });
      expect(modelWithDocFallback.attachmentUrl, 'https://ciss.app/uploads/doc.pdf');
    });

    test('IncidentModel parses district, locationText, and photo arrays', () {
      final incident = IncidentModel.fromJson({
        'id': 'inc-101',
        'category': 'security_breach',
        'severity': 'critical',
        'status': 'investigating',
        'siteName': 'Kochi Yard 4',
        'reportedAt': '2026-09-06T10:00:00Z',
        'description': 'Perimeter sensor tripped',
        'district': 'Ernakulam',
        'locationText': 'Gate 3 Outer Fence',
        'photoUrls': ['https://ciss.app/photos/p1.jpg', 'https://ciss.app/photos/p2.jpg'],
      });

      expect(incident.district, 'Ernakulam');
      expect(incident.locationText, 'Gate 3 Outer Fence');
      expect(incident.photoUrls.length, 2);
      expect(incident.photoUrls.first, 'https://ciss.app/photos/p1.jpg');

      // Fallback single photoUrl
      final singlePhotoIncident = IncidentModel.fromJson({
        'id': 'inc-102',
        'category': 'trespass',
        'severity': 'low',
        'status': 'closed',
        'siteName': 'North Depot',
        'photoUrl': 'https://ciss.app/photos/single.jpg',
      });
      expect(singlePhotoIncident.photoUrls, ['https://ciss.app/photos/single.jpg']);
    });
  });
}
