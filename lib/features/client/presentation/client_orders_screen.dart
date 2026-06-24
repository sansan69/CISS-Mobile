import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

/// Client work orders screen — shows work orders for this client.
class ClientOrdersScreen extends ConsumerStatefulWidget {
  const ClientOrdersScreen({super.key});

  @override
  ConsumerState<ClientOrdersScreen> createState() =>
      _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends ConsumerState<ClientOrdersScreen> {
  List<Map<String, dynamic>>? _orders;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = ref.read(authSessionProvider).value;
      final clientId = session?.clientId ?? '';

      final orders = await ref
          .read(mobileRepositoryProvider)
          .fetchClientWorkOrders(clientId);

      if (!mounted) return;

      setState(() {
        _orders = orders;
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
              title: 'Could not load work orders',
              message: _error!,
              action: FilledButton.tonal(
                onPressed: _fetchOrders,
                child: const Text('Try again'),
              ),
            ),
          ),
        ),
      );
    }

    final orders = _orders ?? const <Map<String, dynamic>>[];

    return ScreenScaffold(
      title: 'Work Orders',
      subtitle: 'Staffing and deployments',
      onRefresh: _fetchOrders,
      children: <Widget>[
        if (orders.isEmpty)
          const StateBlock(
            icon: Icons.assignment_turned_in_rounded,
            title: 'No work orders',
            message:
                'Active work orders for your sites will appear here once published.',
          )
        else
          ...orders.map((order) {
            final siteName =
                (order['siteName'] as String?) ?? 'Site';
            final dateLabel =
                (order['date'] as String?) ??
                    (order['dateLabel'] as String?) ??
                    '';
            final assignedCount =
                (order['assignedCount'] as num?)?.toInt() ?? 0;
            final totalManpower =
                (order['totalManpower'] as num?)?.toInt() ?? 0;
            final isCovered =
                totalManpower > 0 && assignedCount >= totalManpower;

            return GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Top row: site name + status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                siteName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.ink,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (dateLabel.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 13,
                                      color: tokens.inkMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dateLabel,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: tokens.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        StatusChip(
                          label: isCovered
                              ? 'COVERED'
                              : 'OPEN',
                          tone: isCovered
                              ? StatusChipTone.success
                              : StatusChipTone.warning,
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Guards assigned progress
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.groups_rounded,
                          size: 16,
                          color: tokens.inkMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$assignedCount / $totalManpower guards assigned',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tokens.inkMuted,
                          ),
                        ),
                      ],
                    ),

                    if (totalManpower > 0) ...[
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: assignedCount / totalManpower,
                          minHeight: 6,
                          backgroundColor:
                              tokens.surfaceMuted,
                          color: isCovered
                              ? tokens.success
                              : tokens.warning,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
