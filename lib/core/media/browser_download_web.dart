import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Saves [bytes] through the browser's download mechanism.
///
/// Returns `true` when a download was started.
bool downloadBytes(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // Revoking immediately can cancel the download in some browsers; the next
  // macrotask is enough for the navigation to start.
  web.window.setTimeout(
    (() {
      web.URL.revokeObjectURL(url);
    }).toJS,
    1000.toJS,
  );
  return true;
}
