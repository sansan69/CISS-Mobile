import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<Uint8List> stampReportPhotoBytes(
  Uint8List sourceBytes, {
  required DateTime timestamp,
  String? title,
}) async {
  final codec = await ui.instantiateImageCodec(sourceBytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint();

  canvas.drawImage(image, Offset.zero, paint);

  final width = image.width.toDouble();
  final height = image.height.toDouble();
  final overlayHeight = (height * 0.18).clamp(84.0, 180.0).toDouble();
  final overlayTop = height - overlayHeight;

  canvas.drawRect(
    Rect.fromLTWH(0, overlayTop, width, overlayHeight),
    Paint()..color = Colors.black.withValues(alpha: 0.58),
  );

  canvas.drawRect(
    Rect.fromLTWH(0, overlayTop, width, 5),
    Paint()..color = const Color(0xFF1B6FAE),
  );

  final timeFormatter = DateFormat('dd MMM yyyy, hh:mm a');
  final headline = (title != null && title.trim().isNotEmpty)
      ? title.trim()
      : 'Captured photo';

  final headlinePainter = TextPainter(
    text: TextSpan(
      text: headline,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    ),
    textDirection: ui.TextDirection.ltr,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: width - 24);

  final timestampPainter = TextPainter(
    text: TextSpan(
      text: timeFormatter.format(timestamp),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.92),
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    ),
    textDirection: ui.TextDirection.ltr,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: width - 24);

  headlinePainter.paint(canvas, Offset(12, overlayTop + 12));
  timestampPainter.paint(
    canvas,
    Offset(12, overlayTop + 12 + headlinePainter.height + 4),
  );

  final subtitlePainter = TextPainter(
    text: TextSpan(
      text: 'CISS Workforce',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.78),
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    ),
    textDirection: ui.TextDirection.ltr,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: width - 24);

  subtitlePainter.paint(
    canvas,
    Offset(
      math.max(12.0, width - subtitlePainter.width - 12),
      overlayTop + overlayHeight - subtitlePainter.height - 10,
    ),
  );

  final picture = recorder.endRecording();
  final output = await picture.toImage(image.width, image.height);
  final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List() ?? sourceBytes;
}

String sanitizeReportFileName(String value) {
  final sanitized = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return sanitized.isEmpty ? 'report_file' : sanitized;
}

String mimeTypeFromFileName(String fileName, {String? fallback}) {
  final extension = fileName.split('.').last.toLowerCase();
  switch (extension) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'heif':
      return 'image/heif';
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'txt':
      return 'text/plain';
    default:
      return (fallback != null && fallback.isNotEmpty)
          ? fallback
          : 'application/octet-stream';
  }
}
