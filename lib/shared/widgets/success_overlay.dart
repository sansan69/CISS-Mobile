import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Full-screen success confirmation overlay with an animated checkmark.
///
/// Used to confirm important actions (attendance check-in/out, report
/// submission) with a brief, native-feeling confirmation before dismissing.
class SuccessOverlay extends StatefulWidget {
  const SuccessOverlay({
    super.key,
    required this.title,
    this.message,
    this.duration = const Duration(milliseconds: 1400),
    this.onComplete,
  });

  final String title;
  final String? message;
  final Duration duration;
  final VoidCallback? onComplete;

  /// Shows the overlay on top of [context] and awaits dismissal.
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? message,
    VoidCallback? onComplete,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: title,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SuccessOverlay(
          title: title,
          message: message,
          onComplete: () {
            Navigator.of(context).pop();
            onComplete?.call();
          },
        );
      },
    );
  }

  @override
  State<SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<SuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    Future<void>.delayed(widget.duration, () {
      if (mounted) widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    final fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    return Center(
      child: FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: tokens.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: tokens.successSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: tokens.success,
                    size: 40,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: tokens.ink,
                  ),
                ),
                if (widget.message != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.inkMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
