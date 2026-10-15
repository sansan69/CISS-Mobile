import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_fonts.dart';

/// One guard row of the muster roll.
class MusterRollRow {
  const MusterRollRow({
    required this.name,
    required this.employeeId,
    required this.site,
    required this.checkIn,
    required this.checkOut,
    required this.status,
  });

  final String name;
  final String employeeId;
  final String site;
  final String checkIn;
  final String checkOut;
  final String status;
}

class MusterRollData {
  const MusterRollData({
    required this.dateLabel,
    required this.totalForce,
    required this.onDuty,
    required this.checkedOut,
    required this.siteOnDuty,
    required this.rows,
    required this.generatedAt,
    this.carriedOver = const <MusterRollRow>[],
  });

  final String dateLabel;
  final int totalForce;
  final int onDuty;
  final int checkedOut;
  final Map<String, int> siteOnDuty;
  final List<MusterRollRow> rows;
  final String generatedAt;

  /// Guards whose shift began before [dateLabel] and has not closed yet. They
  /// are on duty now, but they are not this date's check-ins, so the client
  /// sees where the overnight strength comes from.
  final List<MusterRollRow> carriedOver;
}

/// Builds the printable muster roll the field officer hands to a client.
///
/// Equivalent to the CISS-AMS `api/pdf_api.dart` report path, but generated
/// on-device so it works with no connectivity.
Future<Uint8List> buildMusterRollPdf(MusterRollData data) async {
  // Embed a font that can actually print the em dash and bullet this report
  // uses, instead of silently dropping them from the officer's copy.
  final theme = await PdfFonts.theme();
  final document = pw.Document(
    title: 'CISS Muster Roll',
    author: 'CISS Workforce',
    theme: theme,
  );
  final sites =
      data.siteOnDuty.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build:
          (pw.Context context) => <pw.Widget>[
            pw.Header(
              level: 0,
              text: 'CISS Workforce Services',
              textStyle: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Muster Roll — ${data.dateLabel}',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: const <String>['Total force', 'On duty', 'Checked out'],
              data: <List<String>>[
                <String>[
                  '${data.totalForce}',
                  '${data.onDuty}',
                  '${data.checkedOut}',
                ],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.center,
              cellStyle: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Site deployment',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            if (sites.isEmpty)
              pw.Text(
                'No active check-ins recorded for this date.',
                style: const pw.TextStyle(fontSize: 10),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: const <String>['Site', 'Guards on duty'],
                data:
                    sites
                        .map(
                          (MapEntry<String, int> site) => <String>[
                            site.key,
                            '${site.value}',
                          ],
                        )
                        .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
              ),
            if (data.rows.isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 14),
              pw.Text(
                'Attendance records',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: const <String>[
                  'Guard',
                  'Employee ID',
                  'Site',
                  'Check in',
                  'Check out',
                  'Status',
                ],
                data:
                    data.rows
                        .map(
                          (MusterRollRow row) => <String>[
                            row.name,
                            row.employeeId,
                            row.site,
                            row.checkIn,
                            row.checkOut,
                            row.status,
                          ],
                        )
                        .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
            ],
            if (data.carriedOver.isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 14),
              pw.Text(
                'Carried over from the previous day',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: const <String>[
                  'Guard',
                  'Employee ID',
                  'Site',
                  'Check in',
                  'Check out',
                  'Status',
                ],
                data:
                    data.carriedOver
                        .map(
                          (MusterRollRow row) => <String>[
                            row.name,
                            row.employeeId,
                            row.site,
                            row.checkIn,
                            row.checkOut,
                            row.status,
                          ],
                        )
                        .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
            ],
            pw.SizedBox(height: 16),
            pw.Text(
              'Generated ${data.generatedAt} • CISS Mobile Field Operations',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
    ),
  );

  return document.save();
}
