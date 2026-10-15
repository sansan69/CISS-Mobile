import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/haptics.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/permissions/device_readiness.dart';
import '../../core/permissions/oem_autostart.dart';
import '../../shared/widgets/modern_card.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/status_chip.dart';

/// The single readiness checklist.
///
/// First-run onboarding and the in-app "Device setup" screen both render this
/// widget, so a permission is read by one provider, repaired in one place and
/// explained with the same copy. Nothing here blocks sign-in: a guard can walk
/// away with rows outstanding and finish later.
class ReadinessChecklist extends ConsumerStatefulWidget {
  const ReadinessChecklist({
    super.key,
    this.onFinish,
    this.finishLabel,
    this.onLater,
    this.showLater = true,
  });

  /// Primary action once nothing blocks tracking.
  final VoidCallback? onFinish;
  final String? finishLabel;

  /// Leaves the checklist with work outstanding. Onboarding passes the home
  /// route, which is what keeps readiness from gating the app.
  final VoidCallback? onLater;
  final bool showLater;

  @override
  ConsumerState<ReadinessChecklist> createState() => _ReadinessChecklistState();
}

class _ReadinessChecklistState extends ConsumerState<ReadinessChecklist> {
  /// The newest observation. Kept across refreshes so the rows do not blink
  /// out while the platform is re-read.
  ReadinessSnapshot? _last;

  ReadinessItem? _pending;
  bool _granting = false;
  bool _serviceStarted = false;

  @override
  void initState() {
    super.initState();
    // This surface exists to read the device, so it primes the shared cache
    // that the banner and health card render from. Post-frame because the read
    // must not start inside a build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _persist());
  }

  Future<void> _persist() async {
    try {
      final snapshot = await ref.read(readinessProvider.future);
      _last = snapshot;
      if (!mounted) return;
      await ref.read(readinessCacheProvider.notifier).save(snapshot);
    } catch (_) {
      // A failed probe is already visible as a row; nothing to repair here.
    }
  }

  Future<void> _afterChange() async {
    ref.invalidate(readinessProvider);
    await _persist();
    await _startTrackingIfReady();
  }

  /// The tracking service can only post its notification once the guard has
  /// allowed notifications, so it starts after that grant and runs once.
  Future<void> _startTrackingIfReady() async {
    if (_serviceStarted) return;
    final snapshot = _last;
    if (snapshot?.stateOf(ReadinessItem.notifications) !=
        ReadinessState.granted) {
      return;
    }
    _serviceStarted = true;
    try {
      await ref.read(readinessServiceStartProvider)();
    } catch (error) {
      debugPrint('Background service init after permissions failed: $error');
    }
  }

  Future<void> _run(Future<void> Function(ReadinessSource source) action) async {
    Haptics.selection();
    try {
      await action(ref.read(readinessSourceProvider));
    } catch (error) {
      debugPrint('Readiness action failed: $error');
    } finally {
      await _afterChange();
    }
  }

  Future<void> _grant(ReadinessItem item) async {
    if (_pending != null || _granting) return;
    setState(() => _pending = item);
    await _run((source) => source.request(item));
    if (mounted) setState(() => _pending = null);
  }

  /// Walks the outstanding required permissions in the order the plan fixed:
  /// notifications, location, background location, camera, activity.
  /// Battery and auto-start stay on their own rows because they open a
  /// settings app, which would strand a half-finished dialog sequence.
  Future<void> _grantRemaining(List<ReadinessItem> blocking) async {
    if (_granting || blocking.isEmpty) return;
    _granting = true;
    if (mounted) setState(() {});
    Haptics.medium();
    await _run((source) async {
      for (final item in blocking) {
        try {
          await source.request(item);
        } catch (error) {
          debugPrint('Readiness request failed for ${item.name}: $error');
        }
      }
    });
    _granting = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final async = ref.watch(readinessProvider);
    // Riverpod only publishes a new value on completion; remembering it here
    // keeps the previous rows on screen during a refresh.
    final latest = async.valueOrNull;
    if (latest != null) _last = latest;
    final snapshot = _last;

    if (snapshot == null) {
      return _NoticeCard(
        icon:
            async.hasError
                ? Icons.error_outline_rounded
                : Icons.hourglass_top_rounded,
        // The raw exception is a debugging aid, not copy for a guard.
        message:
            async.hasError
                ? strings.readinessBannerBody
                : strings.readinessChecking,
        onRetry: async.hasError ? () => _afterChange() : null,
      );
    }

    final steps = buildReadinessSteps(snapshot, strings);
    final required = steps
        .where((step) => !step.advisory)
        .where((step) => step.state != ReadinessState.notApplicable)
        .toList(growable: false);
    final readyCount = required.where((step) => !step.needsAction).length;
    final blocking = snapshot.blocking;

    final cards = <Widget>[
      _ProgressCard(
        ready: readyCount,
        total: required.length,
        allGood: snapshot.ready,
        strings: strings,
      ),
      for (final step in steps)
        _StepCard(
          step: step,
          pending: _pending == step.item,
          onAllow: () => _grant(step.item),
          onOpenSettings: () => _run((source) => source.openSettings()),
          onOpenBattery: () =>
              _run((source) => source.openBatteryOptimizationSettings()),
          onOpenAutostart: () =>
              _run((source) => source.openAutostartSettings()),
        ),
      if (_showOemGuide(snapshot))
        _OemGuideCard(
          guide: oemGuideForOrGeneric(snapshot.manufacturer),
          strings: strings,
          onOpenBattery: () =>
              _run((source) => source.openBatteryOptimizationSettings()),
          onOpenAutostart:
              snapshot.stateOf(ReadinessItem.autostart) ==
                  ReadinessState.notApplicable
              ? null
              : () => _run((source) => source.openAutostartSettings()),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final card in cards) ...<Widget>[
          card,
          const SizedBox(height: AppSpacing.sm),
        ],
        if (blocking.isNotEmpty)
          _FullWidthButton(
            label: strings.readinessGrantRemaining,
            busy: _granting,
            onPressed: _granting ? null : () => _grantRemaining(blocking),
          )
        else if (widget.onFinish != null)
          _FullWidthButton(
            label: widget.finishLabel ?? strings.readinessContinue,
            filled: false,
            onPressed: _granting ? null : widget.onFinish,
          )
        else
          _FullWidthButton(
            label: strings.readinessRecheck,
            filled: false,
            onPressed: () => _afterChange(),
          ),
        if (blocking.isNotEmpty)
          _FullWidthButton(
            label: strings.readinessRecheck,
            filled: false,
            onPressed: _granting ? null : () => _afterChange(),
          ),
        if (widget.showLater && widget.onLater != null) ...<Widget>[
          TextButton(
            onPressed: _granting ? null : widget.onLater,
            child: Text(strings.readinessLater),
          ),
          Text(
            strings.readinessLaterHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: CissThemeTokens.of(context).inkMuted,
            ),
          ),
        ],
      ],
    );
  }

  /// Battery exemption and auto-start cannot be granted from a dialog, so the
  /// vendor recipe is offered while either is outstanding.
  bool _showOemGuide(ReadinessSnapshot snapshot) {
    final battery = snapshot.stateOf(ReadinessItem.batteryExemption);
    final autostart = snapshot.stateOf(ReadinessItem.autostart);
    return battery != ReadinessState.granted ||
        autostart == ReadinessState.notRequested ||
        autostart == ReadinessState.denied;
  }
}

/// In-app entry point, reachable from the guard and field-officer "More" hubs.
class DeviceReadinessScreen extends StatelessWidget {
  const DeviceReadinessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ScreenScaffold(
      title: strings.readinessTitle,
      subtitle: strings.readinessSubtitle,
      children: <Widget>[
        ReadinessChecklist(
          onFinish: () => Navigator.of(context).maybePop(),
          onLater: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.ready,
    required this.total,
    required this.allGood,
    required this.strings,
  });

  final int ready;
  final int total;
  final bool allGood;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final value = total == 0 ? 1.0 : ready / total;
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.fill(strings.readinessProgress, <String, Object>{
              'ready': ready,
              'total': total,
            }),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: tokens.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: tokens.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(
                allGood ? tokens.success : tokens.warning,
              ),
            ),
          ),
          if (allGood) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              strings.readinessAllGood,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.success,
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              strings.readinessBannerBody,
              style: TextStyle(fontSize: 12, color: tokens.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.pending,
    required this.onAllow,
    required this.onOpenSettings,
    required this.onOpenBattery,
    required this.onOpenAutostart,
  });

  final ReadinessStep step;
  final bool pending;
  final VoidCallback onAllow;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenBattery;
  final VoidCallback onOpenAutostart;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final strings = AppStrings.of(context);
    final cta = _primaryAction(strings);

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(_iconFor(step.item), color: tokens.primaryStrong),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.why,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: tokens.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              StatusChip(
                label: readinessStateLabel(step.state, strings),
                tone: _toneFor(step.state),
                icon: _statusIcon(step.state),
              ),
              if (!step.needsAction && !pending)
                Icon(Icons.check_circle_rounded, size: 18, color: tokens.success),
            ],
          ),
          if (step.item == ReadinessItem.backgroundLocation &&
              step.needsAction) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              strings.readinessTwoStepNote,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: tokens.warning,
              ),
            ),
          ],
          if (cta != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: '${step.title}. ${cta.label}',
              button: true,
              child: ExcludeSemantics(
                child: _FullWidthButton(
                  label: cta.label,
                  busy: pending,
                  filled: false,
                  onPressed: pending ? null : cta.run,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _StepAction? _primaryAction(AppStrings strings) {
    switch (step.item) {
      case ReadinessItem.batteryExemption:
        if (!step.needsAction) return null;
        return _StepAction(strings.readinessOpenBatterySettings, onOpenBattery);
      case ReadinessItem.autostart:
        if (!step.needsAction) return null;
        return _StepAction(strings.readinessOpenAutostart, onOpenAutostart);
      case ReadinessItem.notifications:
      case ReadinessItem.location:
      case ReadinessItem.backgroundLocation:
      case ReadinessItem.camera:
      case ReadinessItem.activityRecognition:
        if (!step.needsAction) return null;
        return step.needsSettings
            ? _StepAction(strings.readinessOpenSettings, onOpenSettings)
            : _StepAction(strings.readinessAllow, onAllow);
    }
  }

  static IconData _iconFor(ReadinessItem item) => switch (item) {
    ReadinessItem.notifications => Icons.notifications_active_rounded,
    ReadinessItem.location => Icons.location_on_rounded,
    ReadinessItem.backgroundLocation => Icons.my_location_rounded,
    ReadinessItem.camera => Icons.camera_alt_rounded,
    ReadinessItem.activityRecognition => Icons.directions_walk_rounded,
    ReadinessItem.batteryExemption => Icons.battery_saver_rounded,
    ReadinessItem.autostart => Icons.bolt_rounded,
  };

  static IconData _statusIcon(ReadinessState state) => switch (state) {
    ReadinessState.granted => Icons.check_circle_outline_rounded,
    ReadinessState.denied || ReadinessState.permanentlyDenied =>
      Icons.error_outline_rounded,
    ReadinessState.notRequested => Icons.schedule_rounded,
    ReadinessState.notApplicable => Icons.remove_circle_outline_rounded,
    ReadinessState.unknown => Icons.help_outline_rounded,
  };

  static StatusChipTone _toneFor(ReadinessState state) => switch (state) {
    ReadinessState.granted => StatusChipTone.success,
    ReadinessState.denied || ReadinessState.permanentlyDenied =>
      StatusChipTone.danger,
    ReadinessState.notRequested => StatusChipTone.warning,
    ReadinessState.notApplicable => StatusChipTone.neutral,
    ReadinessState.unknown => StatusChipTone.neutral,
  };
}

class _StepAction {
  const _StepAction(this.label, this.run);

  final String label;
  final VoidCallback run;
}

class _OemGuideCard extends StatelessWidget {
  const _OemGuideCard({
    required this.guide,
    required this.strings,
    required this.onOpenBattery,
    this.onOpenAutostart,
  });

  final OemGuide guide;
  final AppStrings strings;
  final VoidCallback onOpenBattery;
  final VoidCallback? onOpenAutostart;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final steps = guide.stepKeys;
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.battery_saver_rounded, color: tokens.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  strings.fill(strings.readinessOemTitle, <String, Object>{
                    'brand': guide.brand,
                  }),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: tokens.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            strings.readinessOemBody,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: tokens.inkMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < steps.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${index + 1}.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.inkMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      strings.label(steps[index]),
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: tokens.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            label: '${guide.brand}. ${strings.readinessOpenBatterySettings}',
            button: true,
            child: ExcludeSemantics(
              child: _FullWidthButton(
                label: strings.readinessOpenBatterySettings,
                filled: false,
                onPressed: onOpenBattery,
              ),
            ),
          ),
          if (onOpenAutostart != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: '${guide.brand}. ${strings.readinessOpenAutostart}',
              button: true,
              child: ExcludeSemantics(
                child: _FullWidthButton(
                  label: strings.readinessOpenAutostart,
                  filled: false,
                  onPressed: onOpenAutostart,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: tokens.inkMuted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(fontSize: 13, color: tokens.inkMuted),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _FullWidthButton(
              label: AppStrings.of(context).readinessRecheck,
              filled: false,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-width action. The label wraps, which keeps long Hindi and Malayalam
/// strings inside 320 dp at 1.8 text scale.
class _FullWidthButton extends StatelessWidget {
  const _FullWidthButton({
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label, textAlign: TextAlign.center);
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(Size.fromHeight(48)),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      ),
    );
    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton(onPressed: onPressed, style: style, child: child)
          : FilledButton.tonal(
              onPressed: onPressed,
              style: style,
              child: child,
            ),
    );
  }
}
