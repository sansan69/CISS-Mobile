import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Bytes for photos captured in this browser tab, keyed by the object URL that
/// `image_picker` returns on web.
///
/// Native builds read photos straight from the file system, so this map stays
/// empty there and no image data is duplicated in memory.
final Map<String, Uint8List> _sessionPhotoBytes = <String, Uint8List>{};

/// Caches the picked image's bytes when running on web.
///
/// Web builds have no file system: `XFile.path` is a `blob:` URL and
/// `dart:io`'s `File` cannot read it. Returning the bytes lets the same pick
/// feed both the preview and the upload without re-reading the picker.
Future<Uint8List?> rememberPickedPhoto(XFile picked) async {
  if (!kIsWeb) return null;
  final bytes = await picked.readAsBytes();
  _sessionPhotoBytes[picked.path] = bytes;
  return bytes;
}

/// Reads a captured photo's bytes on any platform.
Future<Uint8List> readPhotoBytes(String path) async {
  final cached = _sessionPhotoBytes[path];
  if (cached != null) return cached;
  if (kIsWeb) {
    throw StateError(
      'The captured photo is no longer available. Please capture it again.',
    );
  }
  return File(path).readAsBytes();
}

/// Whether [path] still resolves to readable bytes on this platform.
bool hasPhotoBytes(String path) =>
    !kIsWeb || _sessionPhotoBytes.containsKey(path);

/// Renders a captured photo on any platform without touching `dart:io` on web.
Widget photoImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  final cached = _sessionPhotoBytes[path];
  if (cached != null) {
    return Image.memory(
      cached,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
    );
  }
  if (kIsWeb) {
    return const Center(child: Icon(Icons.broken_image_outlined));
  }
  return Image.file(File(path), fit: fit, width: width, height: height);
}

/// Picks a photo and caches its bytes for web preview and upload.
Future<XFile?> pickPhoto({
  ImageSource source = ImageSource.camera,
  int imageQuality = 80,
  double? maxWidth = 1920,
  double? maxHeight = 1920,
}) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
  );
  if (picked != null) await rememberPickedPhoto(picked);
  return picked;
}
