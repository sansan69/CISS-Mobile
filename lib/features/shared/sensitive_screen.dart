import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

/// Reference counted because sensitive routes and sheets can overlap.
class SensitiveScreen extends StatefulWidget {
  const SensitiveScreen({super.key, required this.child});
  final Widget child;
  @override
  State<SensitiveScreen> createState() => _SensitiveScreenState();
}

class _SensitiveScreenState extends State<SensitiveScreen> {
  static int _users = 0;
  static Future<void> _pending = Future.value();
  void _toggle(bool enabled) {
    _pending = _pending.then((_) async {
      try {
        if (enabled) {
          await ScreenProtector.preventScreenshotOn();
        } else {
          await ScreenProtector.preventScreenshotOff();
        }
      } catch (_) {
        /* Unsupported platform must not hide the employee's records. */
      }
    });
    unawaited(_pending);
  }

  @override
  void initState() {
    super.initState();
    if (_users++ == 0) _toggle(true);
  }

  @override
  void dispose() {
    if (--_users == 0) _toggle(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
