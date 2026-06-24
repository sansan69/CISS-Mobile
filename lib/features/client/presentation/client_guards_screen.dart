import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

/// Client guards screen — shows all guards assigned to this client.
class ClientGuardsScreen extends ConsumerStatefulWidget {
  const ClientGuardsScreen({super.key});

  @override
  ConsumerState<ClientGuardsScreen> createState() =>
      _ClientGuardsScreenState();
}

class _ClientGuardsScreenState extends ConsumerState<ClientGuardsScreen> {
  List<Map<String, dynamic>>? _guards;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchGuards();
  }

  Future<void> _fetchGuards() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = ref.read(authSessionProvider).value;
      final clientId = session?.clientId ?? '';

      final guards = await ref
          .read(mobileRepositoryProvider)
          .fetchClientGuards(clientId);

      if (!mounted) return;

      setState(() {
        _guards = guards;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StateBlock(
              icon: Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
              title: 'Could not load guards',
              message: _error!,
              action: FilledButton.tonal(
                onPressed: _fetchGuards,
                child: const Text('Try again'),
              ),
            ),
          ),
        ),
      );
    }

    final guards = _guards ?? const <Map<String, dynamic>>[];

    return ScreenScaffold(
      title: 'Guards',
      subtitle: 'Your security personnel',
      onRefresh: _fetchGuards,
      children: <Widget>[
        if (guards.isEmpty)
          const StateBlock(
            icon: Icons.person_off_rounded,
            title: 'No guards assigned',
            message:
                'Guards assigned to your sites will appear here once deployed.',
          )
        else
          ...guards.map((guard) {
            final name =
                (guard['fullName'] as String?) ?? (guard['name'] as String?) ?? 'Guard';
            final phone =
                (guard['phoneNumber'] as String?) ?? (guard['phone'] as String?) ?? '';
            final status =
                (guard['status'] as String?) ?? 'active';
            final isActive = status.toLowerCase() == 'active';

            return GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: <Widget>[
                    // Avatar with initial
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: tokens.primarySoft,
                      child: Text(
                        _initials(name),
                        style: TextStyle(
                          color: tokens.primaryStrong,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Name and phone
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: tokens.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              phone,
                              style: TextStyle(
                                fontSize: 13,
                                color: tokens.inkMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Status chip
                    StatusChip(
                      label: isActive ? 'Active' : 'Inactive',
                      tone: isActive
                          ? StatusChipTone.success
                          : StatusChipTone.neutral,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.map((p) => p[0]).take(2).join().toUpperCase();
    if (initials.isNotEmpty) return initials;
    return 'G';
  }
}
