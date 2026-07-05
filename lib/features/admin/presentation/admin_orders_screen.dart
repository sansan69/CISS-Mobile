import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';
import 'admin_work_order_detail_screen.dart';
import 'admin_work_order_import_screen.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  List<Map<String, dynamic>> _orders = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  bool _showOnlyOpen = false;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
      orders.sort((a, b) {
        final aDate = _text(a['date']);
        final bDate = _text(b['date']);
        return bDate.compareTo(aDate);
      });
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

  List<Map<String, dynamic>> get _filteredOrders {
    var list = _orders;

    if (_showOnlyOpen) {
      list = list.where((order) {
        final assigned = _number(order['assignedCount']);
        final total = _number(order['totalManpower']);
        return total <= 0 || assigned < total;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((o) {
        return _text(o['siteName']).toLowerCase().contains(q) ||
            _text(o['clientName']).toLowerCase().contains(q) ||
            _text(o['district']).toLowerCase().contains(q) ||
            _text(o['dateLabel']).toLowerCase().contains(q);
      }).toList();
    }

    return list;
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
    final coveredOrders = _orders.length - openOrders;
    final filtered = _filteredOrders;

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Work Orders'),
        backgroundColor: tokens.canvas,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Import work orders',
            onPressed: () {
              Haptics.light();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminWorkOrderImportScreen(),
                ),
              ).then((_) => _fetchOrders());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${_orders.length} orders · $openOrders open',
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_orders.length} orders, $openOrders open',
                    style: TextStyle(fontSize: 13, color: tokens.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: MetricCard(
                          label: 'Total',
                          value: '${_orders.length}',
                          color: tokens.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MetricCard(
                          label: 'Open',
                          value: '$openOrders',
                          color: tokens.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  _buildSearchBar(tokens),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchOrders,
                child: filtered.isEmpty
                    ? ListView(
                        children: <Widget>[
                          const SizedBox(height: 60),
                          StateBlock(
                            icon: Icons.assignment_turned_in_rounded,
                            title: 'No work orders',
                            message: _searchQuery.isNotEmpty
                                ? 'No orders match your search.'
                                : 'Deployment requirements will appear here.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final order = filtered[index];
                          final siteName = _text(order['siteName']).isNotEmpty
                              ? _text(order['siteName'])
                              : 'Site';
                          final clientName = _text(order['clientName']);
                          final district = _text(order['district']);
                          final dateLabel = _text(order['dateLabel']).isNotEmpty
                              ? _text(order['dateLabel'])
                              : _formatDate(_text(order['date']));
                          final assignedCount =
                              _number(order['assignedCount']);
                          final totalManpower =
                              _number(order['totalManpower']);
                          final isCovered = totalManpower > 0 &&
                              assignedCount >= totalManpower;
                          final progress = totalManpower > 0
                              ? (assignedCount / totalManpower)
                                  .clamp(0.0, 1.0)
                                  .toDouble()
                              : 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ModernCard(
                              onTap: () {
                                final orderId = order['id']?.toString();
                                if (orderId != null && orderId.isNotEmpty) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AdminWorkOrderDetailScreen(
                                        workOrderId: orderId,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                            const SizedBox(height: 4),
                                            if (clientName.isNotEmpty)
                                              _metaLine(
                                                  tokens,
                                                  Icons.business_rounded,
                                                  clientName),
                                            if (district.isNotEmpty)
                                              _metaLine(
                                                  tokens,
                                                  Icons.place_rounded,
                                                  district),
                                            if (dateLabel.isNotEmpty)
                                              _metaLine(
                                                  tokens,
                                                  Icons.calendar_today_rounded,
                                                  dateLabel),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StatusChip(
                                        label: isCovered ? 'Covered' : 'Open',
                                        tone: isCovered
                                            ? StatusChipTone.success
                                            : StatusChipTone.warning,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: <Widget>[
                                      Icon(Icons.groups_rounded,
                                          size: 16, color: tokens.inkMuted),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '$assignedCount / $totalManpower guards assigned',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: tokens.inkMuted,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${(progress * 100).round()}%',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isCovered
                                              ? tokens.success
                                              : tokens.warning,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor: tokens.surfaceMuted,
                                      color: isCovered
                                          ? tokens.success
                                          : tokens.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(CissThemeTokens tokens) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: tokens.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(fontSize: 14, color: tokens.ink),
              decoration: InputDecoration(
                hintText: 'Search orders...',
                hintStyle: TextStyle(fontSize: 14, color: tokens.inkMuted),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 20, color: tokens.inkMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ActionChip(
          onPressed: () => setState(() => _showOnlyOpen = !_showOnlyOpen),
          label: Text(
            'Open only',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _showOnlyOpen ? tokens.warning : tokens.inkMuted,
            ),
          ),
          backgroundColor:
              _showOnlyOpen ? tokens.warningSoft : tokens.surface,
          side: BorderSide(
            color: _showOnlyOpen ? tokens.warning : tokens.border,
          ),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ],
    );
  }

  Widget _metaLine(CissThemeTokens tokens, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: tokens.inkMuted),
          const SizedBox(width: 4),
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
