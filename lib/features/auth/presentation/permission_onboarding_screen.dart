import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/location/background_tracking_service.dart';
import '../../../shared/widgets/brand_banner.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../shared/widgets/state_block.dart';

class PermissionOnboardingScreen extends StatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  State<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends State<PermissionOnboardingScreen> {
  bool _isProcessing = false;
  String? _warning;

  Future<void> _requestPermissions() async {
    setState(() {
      _isProcessing = true;
      _warning = null;
    });

    final locationStatus = await Permission.location.request();
    await Permission.locationAlways.request();
    final cameraStatus = await Permission.camera.request();
    await Permission.notification.request();

    // Initialize background tracking after notification permission.
    try {
      await BackgroundTrackingService.initialize();
    } catch (e) {
      debugPrint('Background service init after permissions: $e');
    }

    if (mounted) {
      setState(() => _isProcessing = false);

      // Check if critical permissions were permanently denied.
      if (locationStatus.isPermanentlyDenied || cameraStatus.isPermanentlyDenied) {
        setState(() {
          _warning = 'Some permissions were denied. Please enable Location and '
              'Camera in app settings for attendance to work.';
        });
        return;
      }

      // Check if critical permissions are still denied (not permanently).
      if (locationStatus.isDenied) {
        setState(() {
          _warning = 'Location permission is required for attendance. '
              'Please grant it to continue.';
        });
        return;
      }

      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return ScreenScaffold(
      title: 'Guard setup',
      subtitle: 'Enable the required permissions before starting duty',
      children: <Widget>[
        const BrandBanner(
          title: 'Prepare this device for duty',
          subtitle:
              'Attendance proof, geofencing, and live updates depend on a small set of permissions.',
        ),
        const StateBlock(
          icon: Icons.verified_user_outlined,
          title: 'Why this matters',
          message:
              'These permissions help confirm site presence, capture attendance evidence, and keep field alerts flowing during duty hours.',
        ),
        const _PermissionTile(
          icon: Icons.location_on_rounded,
          title: 'Location services',
          description:
              'Required for site attendance and geofencing during duty hours.',
        ),
        const _PermissionTile(
          icon: Icons.running_with_errors_rounded,
          title: 'Background tracking',
          description:
              'Allows the system to verify you remain at the assigned site while on duty.',
        ),
        const _PermissionTile(
          icon: Icons.camera_alt_rounded,
          title: 'Camera access',
          description:
              'Used for photo proof during check-in and incident reporting.',
        ),
        const _PermissionTile(
          icon: Icons.notifications_active_rounded,
          title: 'Push notifications',
          description:
              'Receive shift updates, site alerts, and emergency escalations.',
        ),
        if (_warning != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.warningSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: tokens.warning, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _warning!,
                    style: TextStyle(color: tokens.warning, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => openAppSettings(),
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Open App Settings'),
          ),
        ],
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _isProcessing ? null : _requestPermissions,
          child: _isProcessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Grant required permissions'),
        ),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Container(
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
        ],
      ),
    );
  }
}
