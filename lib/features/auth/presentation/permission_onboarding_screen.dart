import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/location/background_tracking_service.dart';
import '../../../core/location/device_compat_service.dart';
import '../../../shared/widgets/brand_banner.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

/// Comprehensive permission onboarding for first install.
///
/// Requests all permissions required for complete guard geo tracking,
/// attendance proof, and movement monitoring across all site types
/// (buildings, offices, yards, godowns, warehouses, factories, vast land).
class PermissionOnboardingScreen extends ConsumerStatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  ConsumerState<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionResult {
  const _PermissionResult({
    required this.permission,
    required this.label,
    required this.granted,
  });

  final Permission permission;
  final String label;
  final bool granted;
}

class _PermissionOnboardingScreenState
    extends ConsumerState<PermissionOnboardingScreen> {
  bool _isProcessing = false;
  List<_PermissionResult> _results = <_PermissionResult>[];

  // Background-running compatibility (battery optimization + OEM auto-start).
  final DeviceCompatService _deviceCompat = DeviceCompatService();
  bool _checkingCompat = true;
  bool _batteryExempt = true;
  bool _aggressiveOem = false;

  @override
  void initState() {
    super.initState();
    _loadCompatState();
  }

  Future<void> _loadCompatState() async {
    final exempt = await _deviceCompat.isIgnoringBatteryOptimizations();
    final aggressive = await _deviceCompat.isAggressiveOem();
    if (!mounted) return;
    setState(() {
      _batteryExempt = exempt;
      _aggressiveOem = aggressive;
      _checkingCompat = false;
    });
  }

  Future<void> _openBatterySettings() async {
    await _deviceCompat.openBatteryOptimizationSettings();
    final exempt = await _deviceCompat.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() => _batteryExempt = exempt);
  }

  Future<void> _openBrandAutostart() async {
    await _deviceCompat.openBrandAutostartSettings();
  }

  static const List<_PermissionItem> _permissionItems = <_PermissionItem>[
    _PermissionItem(
      icon: Icons.location_on_rounded,
      title: 'Location services',
      description:
          'Required for site attendance and geofencing during duty hours.',
      permission: Permission.location,
    ),
    _PermissionItem(
      icon: Icons.camera_alt_rounded,
      title: 'Camera access',
      description:
          'Used for photo proof during check-in and incident reporting.',
      permission: Permission.camera,
    ),
    _PermissionItem(
      icon: Icons.notifications_active_rounded,
      title: 'Push notifications',
      description:
          'Receive shift updates, site alerts, and emergency escalations.',
      permission: Permission.notification,
    ),
  ];

  Future<void> _requestPermissions() async {
    setState(() => _isProcessing = true);

    final List<_PermissionResult> results = <_PermissionResult>[];

    // Request location first (coarse + fine)
    final locationStatus = await Permission.location.request();
    results.add(
      _PermissionResult(
        permission: Permission.location,
        label: 'Location',
        granted: locationStatus.isGranted,
      ),
    );

    // Camera
    final cameraStatus = await Permission.camera.request();
    results.add(
      _PermissionResult(
        permission: Permission.camera,
        label: 'Camera',
        granted: cameraStatus.isGranted,
      ),
    );

    // Notifications
    final notifStatus = await Permission.notification.request();
    results.add(
      _PermissionResult(
        permission: Permission.notification,
        label: 'Notifications',
        granted: notifStatus.isGranted,
      ),
    );

    // Initialize background tracking service now that POST_NOTIFICATIONS
    // (and other permissions) have been requested.
    try {
      await BackgroundTrackingService.initialize();
    } catch (e) {
      debugPrint('Background service init after permissions: $e');
    }

    setState(() {
      _isProcessing = false;
      _results = results;
    });

    // Check if any critical permission was denied
    final criticalDenied =
        results.where((r) => !r.granted).map((r) => r.label).toList();

    if (criticalDenied.isNotEmpty && mounted) {
      _showCriticalDeniedDialog(criticalDenied);
      return;
    }

    if (mounted) {
      context.go('/');
    }
  }

  void _showCriticalDeniedDialog(List<String> denied) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Permissions Required'),
            content: Text(
              'The following permissions are required to use CISS Workforce:\n\n'
              '${denied.map((d) => '• $d').join('\n')}\n\n'
              'Please grant them in Settings to continue.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Retry'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Guard setup',
      subtitle: 'Enable the required permissions before starting duty',
      children: <Widget>[
        const BrandBanner(
          showBackButton: true,
          title: 'Prepare this device for duty',
          subtitle:
              'Attendance proof, geofencing, and live updates depend on a small set of permissions.',
        ),
        const StateBlock(
          icon: Icons.verified_user_rounded,
          title: 'Why this matters',
          message:
              'These permissions help confirm site presence, capture attendance evidence, and keep field alerts flowing during duty hours.',
        ),
        ..._permissionItems.map(
          (item) => _PermissionTile(
            icon: item.icon,
            title: item.title,
            description: item.description,
            status: _statusFor(item.permission),
          ),
        ),
        if (!_checkingCompat && (!_batteryExempt || _aggressiveOem))
          _BackgroundCompatCard(
            batteryExempt: _batteryExempt,
            aggressiveOem: _aggressiveOem,
            onOpenBattery: _openBatterySettings,
            onOpenAutostart: _openBrandAutostart,
          ),
        if (_results.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _ResultsSummary(results: _results),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _isProcessing ? null : _requestPermissions,
          child:
              _isProcessing
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : Text(
                    _results.isEmpty
                        ? 'Grant required permissions'
                        : 'Retry permissions',
                  ),
        ),
        if (_results.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Skip for now'),
          ),
        ],
      ],
    );
  }

  _PermissionStatus _statusFor(Permission perm) {
    final result = _results.firstWhere(
      (r) => r.permission == perm,
      orElse:
          () => const _PermissionResult(
            permission: Permission.location,
            label: '',
            granted: false,
          ),
    );
    if (result.label.isEmpty) return _PermissionStatus.pending;
    return result.granted
        ? _PermissionStatus.granted
        : _PermissionStatus.denied;
  }
}

enum _PermissionStatus { pending, granted, denied }

/// Battery-optimization + OEM auto-start guidance. Some manufacturers
/// (Xiaomi, Oppo, Vivo, Realme, OnePlus, Huawei) kill background services by
/// default; the guard needs to exempt the app so duty tracking keeps running.
class _BackgroundCompatCard extends StatelessWidget {
  const _BackgroundCompatCard({
    required this.batteryExempt,
    required this.aggressiveOem,
    required this.onOpenBattery,
    required this.onOpenAutostart,
  });

  final bool batteryExempt;
  final bool aggressiveOem;
  final VoidCallback onOpenBattery;
  final VoidCallback onOpenAutostart;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: tokens.warningSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: tokens.warning.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.battery_saver_rounded,
                  color: tokens.warning,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Background running',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: tokens.ink,
                    ),
                  ),
                ),
                if (batteryExempt && !aggressiveOem)
                  StatusChip(
                    label: 'ALLOWED',
                    tone: StatusChipTone.success,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              batteryExempt
                  ? aggressiveOem
                        ? 'Your device restricts background apps. Enable '
                            'auto-start so duty tracking keeps running after '
                            'you leave this screen.'
                        : 'Background running is already allowed.'
                  : 'Allow CISS to run in the background so duty tracking '
                      'continues while the screen is off. Without this, '
                      'location updates stop and the site may think you '
                      'left the zone.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: tokens.inkMuted,
              ),
            ),
            if (!batteryExempt) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenBattery,
                  icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                  label: const Text('OPEN BATTERY SETTINGS'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: tokens.warning,
                    side: BorderSide(
                      color: tokens.warning.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Set CISS Workforce to "Don\'t optimize" in the list that '
                'opens. Tracking pauses when the OS restricts it.',
                style: TextStyle(fontSize: 12, color: tokens.inkMuted),
              ),
            ],
            if (aggressiveOem) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenAutostart,
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('OPEN AUTO-START SETTINGS'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PermissionItem {
  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.permission,
  });

  final IconData icon;
  final String title;
  final String description;
  final Permission permission;
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String description;
  final _PermissionStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: tokens.primaryStrong),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatusIcon(status: status),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final _PermissionStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    switch (status) {
      case _PermissionStatus.granted:
        return Icon(Icons.check_circle_rounded, color: tokens.success);
      case _PermissionStatus.denied:
        return Icon(Icons.cancel_rounded, color: tokens.danger);
      case _PermissionStatus.pending:
        return Icon(
          Icons.pending_rounded,
          color: tokens.inkMuted.withValues(alpha: 0.5),
        );
    }
  }
}

class _ResultsSummary extends StatelessWidget {
  const _ResultsSummary({required this.results});

  final List<_PermissionResult> results;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final granted = results.where((r) => r.granted).length;
    final total = results.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.successSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.check_circle_rounded, color: tokens.success),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '$granted of $total permissions granted. '
              '${granted == total ? 'You are ready for duty.' : 'Some optional features may be limited.'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
