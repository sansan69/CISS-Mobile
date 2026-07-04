import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  List<Map<String, dynamic>> _orders = const <Map<String, dynamic>>[];
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
      final orders =
          await ref.read(mobileRepositoryProvider).fetchAdminWorkOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StateBlock(
              icon: Icons.cloud_off_rounded,
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

    final openOrders = _orders.where((order) {
      final assigned = _number(order['assignedCount']);
      final total = _number(order['totalManpower']);
      return total <= 0 || assigned < total;
    }).length;

    return ScreenScaffold(
      title: 'Work Orders',
      subtitle: '${_orders.length} orders, $openOrders open',
      onRefresh: _fetchOrders,
      children: <Widget>[
        if (_orders.isEmpty)
          const StateBlock(
            icon: Icons.assignment_turned_in_rounded,
            title: 'No work orders',
            message: 'Deployment requirements will appear here after creation.',
          )
        else
          ..._orders.map((order) {
            final siteName = _text(order['siteName']).isNotEmpty ? _text(order['siteName']) : 'Site';
            final clientName = _text(order['clientName']);
            final district = _text(order['district']);
            final dateLabel = _text(order['dateLabel']).isNotEmpty
                ? _text(order['dateLabel'])
                : _formatDate(_text(order['date']));
            final assignedCount = _number(order['assignedCount']);
            final totalManpower = _number(order['totalManpower']);
            final isCovered = totalManpower > 0 && assignedCount >= totalManpower;
            final progress = totalManpower > 0
                ? (assignedCount / totalManpower).clamp(0.0, 1.0).toDouble()
                : 0.0;

            return GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              siteName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (clientName.isNotEmpty) _MetaLine(Icons.business_rounded, clientName),
                            if (district.isNotEmpty) _MetaLine(Icons.place_rounded, district),
                            if (dateLabel.isNotEmpty) _MetaLine(Icons.calendar_today_rounded, dateLabel),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      StatusChip(
                        label: isCovered ? 'Covered' : 'Open',
                        tone: isCovered ? StatusChipTone.success : StatusChipTone.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Icon(Icons.groups_rounded, size: 16, color: tokens.inkMuted),
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
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: tokens.surfaceMuted,
                      color: isCovered ? tokens.success : tokens.warning,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  String _text(Object? value) => (value as String?)?.trim() ?? '';

  int _number(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_text(value)) ?? 0;
  }

  String _formatDate(String value) {
    if (value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 13, color: tokens.inkMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: tokens.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
