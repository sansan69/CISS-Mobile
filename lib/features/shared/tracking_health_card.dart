import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/haptics.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/location/tracking_health.dart';
import '../../core/permissions/device_readiness.dart';
import '../../shared/widgets/modern_card.dart';

/// Device-state checklist for reliable background duty tracking, with one-tap
/// repairs.
///
/// Permission rows come from the shared readiness provider, so the app reads a
/// permission once and repairs it here or on the readiness screen with the same
/// logic. The device is only read after the guard taps "Check": the app issues
/// no permission traffic while other screens build, which keeps the app-lock
/// contract in `test/sol_final_auth_edges_test.dart` intact.
class TrackingHealthCard extends ConsumerStatefulWidget {
  const TrackingHealthCard({super.key});

  @override
  ConsumerState<TrackingHealthCard> createState() => _TrackingHealthCardState();
}

class _TrackingHealthCardState extends ConsumerState<TrackingHealthCard> {
  bool _expanded = false;
  ReadinessSnapshot? _last;

  Future<void> _read() async {
    ref.invalidate(trackingServiceStateProvider);
    try {
      final snapshot = await ref.read(readinessProvider.future);
      _last = snapshot;
      if (!mounted) return;
      await ref.read(readinessCacheProvider.notifier).save(snapshot);
    } catch (error) {
      debugPrint('Tracking health read failed: $error');
    }
  }

  Future<void> _repair(ReadinessItem item, ReadinessState state) async {
    Haptics.selection();
    final source = ref.read(readinessSourceProvider);
    try {
      if (state == ReadinessState.permanentlyDenied) {
        // A permanently denied permission only changes in app settings.
        await source.openSettings();
      } else {
        await source.request(item);
      }
    } catch (error) {
      debugPrint('Tracking health repair failed for ${item.name}: $error');
    }
    ref.invalidate(readinessProvider);
    await _read();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final strings = AppStrings.of(context);

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.sensors_rounded, size: 20, color: tokens.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.trackingHealth,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: tokens.ink,
                      ),
                    ),
                    Text(
                      strings.trackingHealthSubtitle,
                      style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: strings.readinessRecheck,
                onPressed: () async {
                  setState(() => _expanded = true);
                  ref.invalidate(readinessProvider);
                  await _read();
                  if (mounted) setState(() {});
                },
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: tokens.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_expanded)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: () async {
                  setState(() => _expanded = true);
                  await _read();
                  if (mounted) setState(() {});
                },
                child: Text(strings.check),
              ),
            )
          else
            _rows(tokens, strings),
        ],
      ),
    );
  }

  Widget _rows(CissThemeTokens tokens, AppStrings strings) {
    // Riverpod only republishes on completion; remembering the value keeps the
    // previous rows visible while the platform is re-read.
    final latest = ref.watch(readinessProvider).valueOrNull;
    if (latest != null) _last = latest;
    final snapshot = _last;
    final service = ref.watch(trackingServiceStateProvider);

    if (snapshot == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Icon(Icons.hourglass_top_rounded, size: 18, color: tokens.inkMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                strings.readinessChecking,
                style: TextStyle(fontSize: 13, color: tokens.inkMuted),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        for (final item in trackingHealthItems)
          _HealthRow(
            label: _labelFor(item, strings),
            state: trackingHealthFor(snapshot.stateOf(item)),
            onFix: () => _repair(item, snapshot.stateOf(item)),
          ),
        _HealthRow(
          label: strings.trackingRunning,
          state: switch (service.valueOrNull) {
            TrackingServiceState.running => TrackingHealthState.ok,
            TrackingServiceState.stopped => TrackingHealthState.actionNeeded,
            _ => TrackingHealthState.unknown,
          },
          okLabel: strings.trackingRunningYes,
          issueLabel: strings.trackingRunningNo,
        ),
      ],
    );
  }

  static String _labelFor(ReadinessItem item, AppStrings strings) =>
      switch (item) {
        ReadinessItem.location => strings.backgroundLocation,
        ReadinessItem.backgroundLocation => strings.readinessBackgroundItem,
        ReadinessItem.notifications => strings.notificationsAllowed,
        ReadinessItem.batteryExemption => strings.batteryUnrestricted,
        ReadinessItem.camera => strings.readinessCameraItem,
        ReadinessItem.activityRecognition => strings.readinessActivityItem,
        ReadinessItem.autostart => strings.readinessAutostart,
      };
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.label,
    required this.state,
    this.onFix,
    this.okLabel,
    this.issueLabel,
  });

  final String label;
  final TrackingHealthState state;
  final VoidCallback? onFix;
  final String? okLabel;
  final String? issueLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final strings = AppStrings.of(context);
    final needsAction = state == TrackingHealthState.actionNeeded;
    final unknown = state == TrackingHealthState.unknown;
    final color = unknown
        ? tokens.inkMuted
        : needsAction
        ? tokens.danger
        : tokens.success;
    final statusText = unknown
        ? (issueLabel ?? strings.readinessStateUnknown)
        : needsAction
        ? (issueLabel ?? strings.actionNeeded)
        : (okLabel ?? strings.ok);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(
            unknown
                ? Icons.help_outline_rounded
                : needsAction
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
            ),
          ),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (needsAction && onFix != null) ...<Widget>[
            const SizedBox(width: 8),
            // Bounded so the compact button never asks for an unbounded width
            // when the card is laid out outside a scroll view.
            SizedBox(
              width: 78,
              child: FilledButton.tonal(
                onPressed: onFix,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(strings.fix),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
