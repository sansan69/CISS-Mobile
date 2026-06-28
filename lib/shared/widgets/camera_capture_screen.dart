import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraCaptureScreen extends StatelessWidget {
  const CameraCaptureScreen({super.key});

  static Future<File?> capture({ImageSource source = ImageSource.camera}) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked == null) return null;
    return File(picked.path);
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
                final file = await capture();
                if (file != null && context.mounted) {
                  Navigator.of(context).pop(file.path);
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
                final file = await capture(source: ImageSource.gallery);
                if (file != null && context.mounted) {
                  Navigator.of(context).pop(file.path);
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
