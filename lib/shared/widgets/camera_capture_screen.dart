import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/media/photo_store.dart';

class CameraCaptureScreen extends StatelessWidget {
  const CameraCaptureScreen({super.key});

  /// Picks or captures a photo and returns its path.
  ///
  /// On web the picked bytes are cached for the session because `blob:` paths
  /// cannot be read back through `dart:io`.
  static Future<String?> capture({
    ImageSource source = ImageSource.camera,
  }) async {
    final picked = await pickPhoto(source: source);
    return picked?.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Capture Photo'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_rounded, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'Camera screen',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () async {
                final path = await capture();
                if (path != null && context.mounted) {
                  Navigator.of(context).pop(path);
                }
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 52),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final path = await capture(source: ImageSource.gallery);
                if (path != null && context.mounted) {
                  Navigator.of(context).pop(path);
                }
              },
              icon: const Icon(Icons.photo_library, color: Colors.white),
              label: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(200, 52),
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
