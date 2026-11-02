import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Method channel implemented by `MainActivity.kt`.
///
/// Android is the only shipping target today; on every other platform the
/// channel simply has no handler and all calls degrade to a safe no-op.
const String secureWindowChannelName = 'co.in.ciss.ciss_mobile/secure_window';

/// Reference-counted owner of Android's `FLAG_SECURE` window flag.
///
/// Sensitive content can be on screen from more than one source at a time — for
/// example a profile route with a document-upload route pushed on top of it.
/// A single boolean
/// would let whichever surface leaves first clear the flag while another is
/// still visible, so the flag is driven by a set of holders and is only cleared
/// when the last holder releases it.
class ScreenSecurity {
  ScreenSecurity({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel(secureWindowChannelName),
      _supported =
          supported ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  final MethodChannel _channel;

  /// Whether the native side can actually honour this request. Desktop, web
  /// and test bindings keep tracking holders but never talk to the platform.
  final bool _supported;

  final Set<String> _holders = <String>{};

  /// The flag state most recently pushed to the platform.
  bool _applied = false;

  /// Whether at least one surface currently requires `FLAG_SECURE`.
  bool get isSecure => _holders.isNotEmpty;

  /// Registers [holder] as a surface that must not be captured.
  Future<void> acquire(String holder) {
    if (!_holders.add(holder)) return Future<void>.value();
    return _sync();
  }

  /// Drops [holder]'s requirement; the flag is cleared only when it was the
  /// last one.
  Future<void> release(String holder) {
    if (!_holders.remove(holder)) return Future<void>.value();
    return _sync();
  }

  /// Drops every holder (used when the session itself goes away).
  Future<void> releaseAll() {
    if (_holders.isEmpty) return Future<void>.value();
    _holders.clear();
    return _sync();
  }

  Future<void> _sync() async {
    final desired = _holders.isNotEmpty;
    if (desired == _applied) return;
    _applied = desired;
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('setSecure', <String, Object?>{
        'secure': desired,
      });
    } on MissingPluginException {
      // No native handler on this platform/build — the no-op is expected.
    } catch (error) {
      debugPrint('ScreenSecurity: could not apply FLAG_SECURE: $error');
    }
  }
}

final screenSecurityProvider = Provider<ScreenSecurity>((ref) {
  final security = ScreenSecurity();
  ref.onDispose(() {
    unawaited(security.releaseAll());
  });
  return security;
});

/// Keeps `FLAG_SECURE` set for as long as [child] is mounted.
///
/// Use it on screens that show identity documents, salary data or other
/// sensitive personal information so the Android recents thumbnail and
/// screenshots/screen recording do not capture them.
class SecureScreen extends ConsumerStatefulWidget {
  const SecureScreen({required this.child, super.key, this.holder});

  final Widget child;

  /// Optional stable holder name, useful when a screen wants to identify its
  /// own contribution in diagnostics. Defaults to a per-instance key.
  final String? holder;

  @override
  ConsumerState<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends ConsumerState<SecureScreen> {
  late final String _holder;
  late final ScreenSecurity _security;

  @override
  void initState() {
    super.initState();
    _holder = widget.holder ?? 'secure_screen#${identityHashCode(this)}';
    _security = ref.read(screenSecurityProvider);
    unawaited(_security.acquire(_holder));
  }

  @override
  void dispose() {
    unawaited(_security.release(_holder));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
