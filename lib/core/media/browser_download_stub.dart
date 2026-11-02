import 'dart:typed_data';

/// Native stub: browsers own file downloads, so there is nothing to do here.
bool downloadBytes(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) {
  throw UnsupportedError('File downloads are only available in the browser.');
}
