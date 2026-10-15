import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/device/device_identity.dart';
import '../../core/i18n/app_strings.dart';
import '../../shared/widgets/modern_card.dart';

/// Shows the handset identifier the office sees on attendance records.
///
/// Support asks a guard for "this device" when a punch is queried, and a guard
/// who has changed phones can confirm the id changed rather than being told
/// their record does not exist.
class DeviceIdentityRow extends ConsumerStatefulWidget {
  const DeviceIdentityRow({super.key});

  @override
  ConsumerState<DeviceIdentityRow> createState() => _DeviceIdentityRowState();
}

class _DeviceIdentityRowState extends ConsumerState<DeviceIdentityRow> {
  String? _id;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = await ref.read(deviceIdentityProvider).id();
    if (!mounted) return;
    setState(() {
      _id = id;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final strings = AppStrings.of(context);
    final id = _id;
    return ModernCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.phone_iphone_rounded, size: 20, color: tokens.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.deviceThisDevice,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _loading
                      ? strings.readinessChecking
                      : (id == null || id.isEmpty
                          ? strings.deviceIdUnavailable
                          : id),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
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
