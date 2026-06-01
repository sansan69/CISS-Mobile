import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/location/background_tracking_service.dart';
import '../../../shared/widgets/brand_banner.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../shared/widgets/state_block.dart';

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
    this.isOptional = false,
  });

  final Permission permission;
  final String label;
  final bool granted;
  final bool isOptional;
}

class _PermissionOnboardingScreenState
    extends ConsumerState<PermissionOnboardingScreen> {
  bool _isProcessing = false;
  List<_PermissionResult> _results = <_PermissionResult>[];
  bool _showBatteryOptimization = false;

  static const List<_PermissionItem> _permissionItems = <_PermissionItem>[
    _PermissionItem(
      icon: Icons.location_on_rounded,
      title: 'Location services',
      description:
          'Required for site attendance and geofencing during duty hours.',
      permission: Permission.location,
      critical: true,
    ),
    _PermissionItem(
      icon: Icons.gps_fixed_rounded,
      title: 'Background location',
      description:
          'Allows the system to verify you remain at the assigned site while on duty, even when the app is closed.',
      permission: Permission.locationAlways,
      critical: true,
    ),
    _PermissionItem(
      icon: Icons.camera_alt_rounded,
      title: 'Camera access',
      description:
          'Used for photo proof during check-in and incident reporting.',
      permission: Permission.camera,
      critical: true,
    ),
    _PermissionItem(
      icon: Icons.notifications_active_rounded,
      title: 'Push notifications',
      description:
          'Receive shift updates, site alerts, and emergency escalations.',
      permission: Permission.notification,
      critical: true,
    ),
    _PermissionItem(
      icon: Icons.directions_walk_rounded,
      title: 'Activity recognition',
      description:
          'Detects movement patterns (walking, still) to confirm patrol routes and guard presence.',
      permission: Permission.activityRecognition,
      critical: false,
    ),
    _PermissionItem(
      icon: Icons.wifi_rounded,
      title: 'WiFi state',
      description:
          'Helps locate guards inside buildings, warehouses, and factories where GPS signals are weak.',
      permission: Permission.location, // WiFi state is covered by location on Android
      critical: false,
      request: false,
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

    // Request background location — Android requires this as a separate step
    // and may show a system dialog redirecting to settings.
    final bgStatus = await Permission.locationAlways.request();
    results.add(
      _PermissionResult(
        permission: Permission.locationAlways,
        label: 'Background location',
        granted: bgStatus.isGranted,
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

    // Activity recognition (optional)
    final activityStatus = await Permission.activityRecognition.request();
    results.add(
      _PermissionResult(
        permission: Permission.activityRecognition,
        label: 'Activity recognition',
        granted: activityStatus.isGranted,
        isOptional: true,
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
    final criticalDenied = results
        .where((r) => !r.isOptional && !r.granted)
        .map((r) => r.label)
        .toList();

    if (criticalDenied.isNotEmpty && mounted) {
      _showCriticalDeniedDialog(criticalDenied);
      return;
    }

    // Check battery optimization on Android
    if (Platform.isAndroid) {
      final isIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;
      if (!isIgnoring && mounted) {
        setState(() => _showBatteryOptimization = true);
        return;
      }
    }

    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _requestBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (status.isGranted && mounted) {
      setState(() => _showBatteryOptimization = false);
      context.go('/');
    }
  }

  void _showCriticalDeniedDialog(List<String> denied) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
        if (_showBatteryOptimization) ...<Widget>[
          _PermissionTile(
            icon: Icons.battery_charging_full_rounded,
            title: 'Battery optimization',
            description:
                'Allow CISS to run in the background so duty tracking is not interrupted by battery saving.',
            status: _PermissionStatus.pending,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _requestBatteryOptimization,
            icon: const Icon(Icons.battery_saver_rounded),
            label: const Text('Allow background operation'),
          ),
        ],
        if (_results.isNotEmpty && !_showBatteryOptimization) ...<Widget>[
          const SizedBox(height: 12),
          _ResultsSummary(results: _results),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _isProcessing || _showBatteryOptimization
              ? null
              : _requestPermissions,
          child: _isProcessing
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
        if (_results.isNotEmpty && !_showBatteryOptimization) ...<Widget>[
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
      orElse: () => const _PermissionResult(
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

class _PermissionItem {
  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.permission,
    required this.critical,
    this.request = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final Permission permission;
  final bool critical;
  final bool request;
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.inkMuted,
                  ),
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
