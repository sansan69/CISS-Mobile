import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

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
  String _searchQuery = '';
  String _selectedFilter = 'All';

  static const _filters = ['All', 'Covered', 'Open'];

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

  List<Map<String, dynamic>> get _filteredOrders {
    final orders = _orders ?? const <Map<String, dynamic>>[];
    var filtered = orders;

    if (_selectedFilter == 'Covered') {
      filtered = filtered.where((o) {
        final assigned = (o['assignedCount'] as num?)?.toInt() ?? 0;
        final total = (o['totalManpower'] as num?)?.toInt() ?? 0;
        return total > 0 && assigned >= total;
      }).toList();
    } else if (_selectedFilter == 'Open') {
      filtered = filtered.where((o) {
        final assigned = (o['assignedCount'] as num?)?.toInt() ?? 0;
        final total = (o['totalManpower'] as num?)?.toInt() ?? 0;
        return total == 0 || assigned < total;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((o) {
        final site = o['siteName']?.toString() ?? '';
        return site.toLowerCase().contains(q);
      }).toList();
    }

    return filtered;
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

    final allOrders = _orders ?? const <Map<String, dynamic>>[];
    final totalOrders = allOrders.length;
    final coveredOrders = allOrders.where((o) {
      final assigned = (o['assignedCount'] as num?)?.toInt() ?? 0;
      final total = (o['totalManpower'] as num?)?.toInt() ?? 0;
      return total > 0 && assigned >= total;
    }).length;

    final filtered = _filteredOrders;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchOrders,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: MetricCard(
                      label: 'Total Orders',
                      value: '$totalOrders',
                      color: tokens.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      label: 'Covered',
                      value: '$coveredOrders',
                      color: tokens.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search sites...',
                  hintStyle: TextStyle(color: tokens.inkMuted, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: tokens.inkMuted, size: 20),
                  filled: true,
                  fillColor: tokens.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((filter) {
                    final isSelected = filter == _selectedFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedFilter = filter);
                        },
                        selectedColor: tokens.primarySoft,
                        checkmarkColor: tokens.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              isSelected ? tokens.primary : tokens.inkMuted,
                        ),
                        side: BorderSide(
                          color: isSelected ? tokens.primary : tokens.border,
                        ),
                        backgroundColor: tokens.surface,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const StateBlock(
                  icon: Icons.assignment_turned_in_rounded,
                  title: 'No work orders',
                  message:
                      'Active work orders for your sites will appear here once published.',
                )
              else
                ...filtered.map((order) {
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

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ModernCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
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
                                label: isCovered ? 'COVERED' : 'OPEN',
                                tone: isCovered
                                    ? StatusChipTone.success
                                    : StatusChipTone.warning,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: assignedCount / totalManpower,
                                minHeight: 6,
                                backgroundColor: tokens.surfaceMuted,
                                color:
                                    isCovered ? tokens.success : tokens.warning,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
