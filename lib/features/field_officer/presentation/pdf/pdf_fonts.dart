import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Fonts embedded in generated PDFs.
///
/// The app's UI face is Inter, but those assets are CFF-flavoured OpenType,
/// which the PDF writer cannot embed. Left on its default Helvetica, the muster
/// roll silently dropped the em dash used for a missing check-out and the
/// bullet in the footer, and would have dropped any non-Latin name too. Roboto
/// is the Apache-2.0 face Flutter itself ships, so it is bundled for PDFs only
/// and keeps the printed report faithful to what the officer sees.
class PdfFonts {
  PdfFonts._();

  static const String regularAsset = 'assets/fonts/pdf/Roboto-Regular.ttf';
  static const String boldAsset = 'assets/fonts/pdf/Roboto-Bold.ttf';

  static pw.ThemeData? _cached;
  static bool _loadAttempted = false;

  /// Theme wiring [regularAsset]/[boldAsset] in as the document's base and bold
  /// faces. Returns null when the assets cannot be read, so a report still
  /// renders on the writer's built-in font instead of failing outright.
  static Future<pw.ThemeData?> theme() async {
    if (_loadAttempted) return _cached;
    _loadAttempted = true;
    try {
      final regular = pw.Font.ttf(await _load(regularAsset));
      final bold = pw.Font.ttf(await _load(boldAsset));
      _cached = pw.ThemeData.withFont(base: regular, bold: bold);
    } catch (_) {
      _cached = null;
    }
    return _cached;
  }

  static Future<ByteData> _load(String asset) async {
    final data = await rootBundle.load(asset);
    return ByteData.view(data.buffer, data.offsetInBytes, data.lengthInBytes);
  }
}
