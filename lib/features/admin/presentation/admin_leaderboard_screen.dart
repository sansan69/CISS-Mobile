import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';

class AdminLeaderboardScreen extends ConsumerStatefulWidget {
  const AdminLeaderboardScreen({super.key});

  @override
  ConsumerState<AdminLeaderboardScreen> createState() =>
      _AdminLeaderboardScreenState();
}

class _AdminLeaderboardScreenState
    extends ConsumerState<AdminLeaderboardScreen> {
  List<LeaderboardEntryModel> _leaders = const [];
  List<LeaderboardEntryModel> _filteredLeaders = const [];
  bool _loading = true;
  String? _error;
  String _districtFilter = 'all';
  String _clientFilter = 'all';
  List<ClientModel> _clients = const [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final leaders = await repo.fetchLeaderboard();
      final clients = await repo.fetchAdminClients();
      if (!mounted) return;
      setState(() {
        _leaders = leaders;
        _clients = clients;
        _applyFilters();
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

  void _applyFilters() {
    setState(() {
      _filteredLeaders = _leaders.where((entry) {
        if (_districtFilter != 'all' && entry.district != _districtFilter) {
          return false;
        }
        if (_clientFilter != 'all' && entry.clientId != _clientFilter) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  List<String> get _distinctDistricts =>
      _leaders.map((e) => e.district).toSet().where((d) => d.isNotEmpty).toList()..sort();

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchData,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: StateBlock(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load leaderboard',
                        message: _error!,
                        action: FilledButton.tonal(
                          onPressed: _fetchData,
                          child: const Text('Try again'),
                        ),
                      ),
                    )
                  : CustomScrollView(
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: ModernHero(
                            eyebrow: 'Performance',
                            title: 'Leaderboard',
                            subtitle: 'Guard scores, rankings & awards',
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: _FilterChip(
                                    label: _districtFilter == 'all'
                                        ? 'All Districts'
                                        : _districtFilter,
                                    items: _distinctDistricts,
                                    selected: _districtFilter,
                                    onSelected: (v) {
                                      setState(() => _districtFilter = v ?? 'all');
                                      _applyFilters();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _FilterChip(
                                    label: _clientFilter == 'all'
                                        ? 'All Clients'
                                        : _clients
                                            .where((c) => c.id == _clientFilter)
                                            .map((c) => c.name)
                                            .firstOrNull ??
                                            'Client',
                                    items: _clients.map((c) => c.name).toList(),
                                    values: _clients
                                        .where((c) => c.name.isNotEmpty)
                                        .map((c) => c.id)
                                        .toList(),
                                    selected: _clientFilter,
                                    onSelected: (v) {
                                      // v is client name; find id
                                      final match = _clients.where((c) => c.name == v).firstOrNull;
                                      setState(() =>
                                          _clientFilter = match?.id ?? (v == null ? 'all' : _clientFilter));
                                      _applyFilters();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_filteredLeaders.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: StateBlock(
                                icon: Icons.leaderboard_outlined,
                                title: 'No results',
                                message: 'No leaderboard entries match the selected filters.',
                              ),
                            ),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final entry = _filteredLeaders[index];
                                final isTop3 = index < 3;
                                return Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    16,
                                    index == 0 ? 0 : 0,
                                    16,
                                    index == _filteredLeaders.length - 1 ? 24 : 8,
                                  ),
                                  child: _LeaderboardCard(
                                    entry: entry,
                                    isTop3: isTop3,
                                    tokens: tokens,
                                  ),
                                );
                              },
                              childCount: _filteredLeaders.length,
                            ),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({
    required this.entry,
    required this.isTop3,
    required this.tokens,
  });

  final LeaderboardEntryModel entry;
  final bool isTop3;
  final CissThemeTokens tokens;

  IconData get _rankIcon {
    switch (entry.rank) {
      case 1:
        return Icons.emoji_events_rounded;
      case 2:
        return Icons.workspace_premium_rounded;
      case 3:
        return Icons.military_tech_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  Color get _rankColor {
    switch (entry.rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return tokens.inkMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = entry.currentMonthScore >= 90
        ? tokens.success
        : entry.currentMonthScore >= 75
            ? tokens.accent
            : tokens.danger;

    return ModernCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isTop3 ? _rankColor.withValues(alpha: 0.15) : tokens.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: isTop3
                  ? Icon(_rankIcon, color: _rankColor, size: 22)
                  : Text(
                      '#${entry.rank}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tokens.inkMuted,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Text(
                      entry.employeeCode.isNotEmpty ? entry.employeeCode : entry.employeeId,
                      style: TextStyle(fontSize: 11, color: tokens.inkMuted),
                    ),
                    if (entry.clientName.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: tokens.inkMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          entry.clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: tokens.inkMuted),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${entry.currentMonthScore.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: scoreColor,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    entry.currentMonthScore >= entry.previousMonthScore
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 14,
                    color: entry.currentMonthScore >= entry.previousMonthScore
                        ? tokens.success
                        : tokens.danger,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${entry.totalEvaluations} evals',
                    style: TextStyle(fontSize: 10, color: tokens.inkMuted),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.items = const <String>[],
    this.values,
    required this.selected,
    this.onSelected,
  });

  final String label;
  final List<String> items;
  final List<String>? values;
  final String selected;
  final void Function(String?)? onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: tokens.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected == 'all' ? null : selected,
          isExpanded: true,
          hint: Text(
            selected == 'all' ? 'All' : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.ink,
            ),
          ),
          items: <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(
              value: 'all',
              child: Text('All', style: TextStyle(fontSize: 13, color: tokens.ink)),
            ),
            ...items.asMap().entries.map((entry) {
              final name = entry.value;
              final actualValue = values != null && entry.key < values!.length
                  ? values![entry.key]
                  : name;
              return DropdownMenuItem<String>(
                value: actualValue,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: tokens.ink),
                ),
              );
            }),
          ],
          onChanged: onSelected,
          dropdownColor: tokens.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          icon: Icon(Icons.expand_more_rounded, color: tokens.inkMuted, size: 18),
        ),
      ),
    );
  }
}
