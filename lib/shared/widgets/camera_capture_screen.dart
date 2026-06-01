import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Full-screen in-app camera capture. Returns the captured file path via
/// Navigator.pop. Does NOT use the OS camera picker — this is a native
/// camera preview embedded directly in the app.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isCapturing = false;
  bool _initialized = false;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      _initialized = false;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) Navigator.of(context).pop(null);
        return;
      }

      // Prefer back camera
      final backIndex =
          _cameras!.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _selectedCameraIndex = backIndex >= 0 ? backIndex : 0;

      await _setupController();
    } catch (_) {
      if (mounted) Navigator.of(context).pop(null);
    }
  }

  Future<void> _setupController() async {
    _controller?.dispose();

    _controller = CameraController(
      _cameras![_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
    await _controller!.setFlashMode(_flashMode);

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await _setupController();
  }

  Future<void> _toggleFlash() async {
    _flashMode =
        _flashMode == FlashMode.off ? FlashMode.always : FlashMode.off;
    await _controller?.setFlashMode(_flashMode);
    setState(() {});
  }

  Future<void> _capture() async {
    if (_isCapturing || !_initialized) return;
    setState(() => _isCapturing = true);

    try {
      final file = await _controller!.takePicture();
      if (mounted) Navigator.of(context).pop(file.path);
    } catch (_) {
      setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final previewSize = _controller!.value.previewSize!;
    final scale = size.width / previewSize.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview — rotated 90° since camera sensor is landscape
          Center(
            child: SizedBox(
              width: size.width,
              height: previewSize.width * scale,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: previewSize.height,
                      height: previewSize.width,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _IconButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(null),
                    ),
                    const Spacer(),
                    if (_cameras != null && _cameras!.length > 1)
                      _IconButton(
                        icon: Icons.flip_camera_android_rounded,
                        onTap: _switchCamera,
                      ),
                    const SizedBox(width: 8),
                    _IconButton(
                      icon: _flashMode == FlashMode.off
                          ? Icons.flash_off_rounded
                          : Icons.flash_on_rounded,
                      onTap: _toggleFlash,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Capture button
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _isCapturing ? null : _capture,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _isCapturing ? 64 : 72,
                  height: _isCapturing ? 64 : 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: _isCapturing
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                  child: _isCapturing
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      : Center(
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),

          // Hint text
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Text(
              'Tap to capture',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
