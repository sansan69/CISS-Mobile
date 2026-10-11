import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// A live-updating chip that displays a countdown until [targetTime],
/// or indicates overdue time once passed.
class TimeCounterChip extends StatefulWidget {
  const TimeCounterChip({
    super.key,
    required this.targetTime,
    this.prefix = '',
    this.dueLabel = 'Due now',
    this.overduePrefix = 'Overdue by ',
    this.compact = false,
  });

  final DateTime? targetTime;
  final String prefix;
  final String dueLabel;
  final String overduePrefix;
  final bool compact;

  @override
  State<TimeCounterChip> createState() => _TimeCounterChipState();
}

class _TimeCounterChipState extends State<TimeCounterChip> {
  Timer? _timer;
  Duration _difference = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  @override
  void didUpdateWidget(covariant TimeCounterChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetTime != widget.targetTime) {
      _update();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _update() {
    if (widget.targetTime == null) {
      if (mounted) setState(() => _difference = Duration.zero);
      return;
    }
    final now = DateTime.now();
    final diff = widget.targetTime!.difference(now);
    if (mounted) {
      setState(() => _difference = diff);
    }
  }

  String _formatDuration(Duration d) {
    final abs = d.abs();
    final hours = abs.inHours;
    final minutes = abs.inMinutes % 60;
    final seconds = abs.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    if (widget.targetTime == null) {
      return const SizedBox.shrink();
    }

    final isOverdue = _difference.isNegative;
    final isImminent = !isOverdue && _difference.inMinutes < 15;

    final Color bgColor;
    final Color textColor;
    final IconData icon;
    final String label;

    if (isOverdue) {
      bgColor = tokens.dangerSoft;
      textColor = tokens.danger;
      icon = Icons.warning_amber_rounded;
      final diffSeconds = _difference.inSeconds.abs();
      if (diffSeconds < 60) {
        label = widget.dueLabel;
      } else {
        label = '${widget.overduePrefix}${_formatDuration(_difference)}';
      }
    } else if (isImminent) {
      bgColor = tokens.warningSoft;
      textColor = tokens.warning;
      icon = Icons.alarm_rounded;
      label = '${widget.prefix}${_formatDuration(_difference)}';
    } else {
      bgColor = tokens.successSoft;
      textColor = tokens.success;
      icon = Icons.schedule_rounded;
      label = '${widget.prefix}${_formatDuration(_difference)}';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 8 : 12,
        vertical: widget.compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: widget.compact ? 13 : 15, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: widget.compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: textColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
