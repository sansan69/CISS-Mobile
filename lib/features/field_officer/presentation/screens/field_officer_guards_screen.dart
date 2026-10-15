import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/brand.dart';
import '../../../../../core/models/guard_profile.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/metric_card.dart';
import '../../../../../shared/widgets/brand_banner.dart';
import '../../../../../shared/widgets/compliance_tag.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import 'field_officer_guard_profile_screen.dart';
import 'field_officer_live_map_screen.dart';

String _statusLabel(String status) => switch (status
    .trim()
    .toLowerCase()
    .replaceAll('_', ' ')) {
  'pendingreview' || 'pending review' => 'Pending Review',
  'onleave' || 'on leave' => 'On Leave',
  'inactive' => 'Inactive',
  'exited' => 'Exited',
  'active' || '' => 'Active',
  _ => status,
};

StatusChipTone _statusTone(String status) => switch (_statusLabel(status)) {
  'Active' => StatusChipTone.success,
  'Pending Review' || 'On Leave' => StatusChipTone.warning,
  'Inactive' || 'Exited' => StatusChipTone.neutral,
  _ => StatusChipTone.info,
};

final FutureProvider<List<GuardProfileModel>> fieldOfficerGuardsProvider =
    FutureProvider<List<GuardProfileModel>>((Ref ref) {
      return ref
          .read(mobileRepositoryProvider)
          .fetchFieldOfficerGuards(includeInactive: true);
    });

class FieldOfficerGuardsScreen extends ConsumerStatefulWidget {
  const FieldOfficerGuardsScreen({super.key});

  @override
  ConsumerState<FieldOfficerGuardsScreen> createState() =>
      _FieldOfficerGuardsScreenState();
}

class _FieldOfficerGuardsScreenState
    extends ConsumerState<FieldOfficerGuardsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _client = 'All';
  String _status = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guardsAsync = ref.watch(fieldOfficerGuardsProvider);
    return guardsAsync.when(
      loading:
          () => const Scaffold(
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  _DirectoryHeader(),
                  Expanded(child: Center(child: CircularProgressIndicator())),
                ],
              ),
            ),
          ),
      error:
          (Object error, StackTrace stackTrace) => Scaffold(
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  const _DirectoryHeader(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: StateBlock(
                          icon: Icons.groups_2_rounded,
                          title: 'Could not load employees',
                          message: '$error',
                          action: FilledButton.tonal(
                            onPressed:
                                () =>
                                    ref.invalidate(fieldOfficerGuardsProvider),
                            child: const Text('Try again'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      data: (guards) {
        final clients =
            guards
                .map((guard) => guard.clientName.trim())
                .where((client) => client.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        if (_client != 'All' && !clients.contains(_client)) {
          clients.add(_client);
          clients.sort();
        }
        final selectedClient =
            _client == 'All' || clients.contains(_client) ? _client : 'All';
        final filtered = _filter(guards, selectedClient);
        final tokens = CissThemeTokens.of(context);

        return Scaffold(
          backgroundColor: tokens.canvas,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(fieldOfficerGuardsProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  100,
                ),
                children: <Widget>[
                  _DirectoryHeader(
                    onLiveMap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const FieldOfficerLiveMapScreen(),
                          ),
                        ),
                    onRefresh: () => ref.invalidate(fieldOfficerGuardsProvider),
                    // The list already supplies the screen margin, so the
                    // header must not add a second indent that would push it
                    // out of line with the search field and employee cards.
                    horizontalPadding: 0,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow =
                          constraints.maxWidth < 360 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.3;
                      final cards = <Widget>[
                        MetricCard(
                          label: 'Employees',
                          value: guards.length.toString(),
                          color: tokens.primary,
                        ),
                        MetricCard(
                          label: 'Districts',
                          value:
                              '${guards.map((g) => g.district).where((d) => d.trim().isNotEmpty).toSet().length}',
                          color: tokens.accent,
                        ),
                      ];
                      if (narrow) {
                        return Column(
                          children: [
                            SizedBox(width: double.infinity, child: cards[0]),
                            const SizedBox(height: AppSpacing.sm),
                            SizedBox(width: double.infinity, child: cards[1]),
                          ],
                        );
                      }
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: cards[1]),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      labelText: 'Search employees',
                      hintText: 'Name, employee ID, client, district, phone',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: tokens.surface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Column(
                    children: <Widget>[
                      SizedBox(
                        width: double.infinity,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: selectedClient,
                          decoration: const InputDecoration(
                            labelText: 'Client',
                          ),
                          items:
                              <String>['All', ...clients]
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(
                                        v,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (value) =>
                                  setState(() => _client = value ?? 'All'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items:
                              <String>[
                                    'All',
                                    'Pending Review',
                                    'Active',
                                    'Inactive',
                                    'On Leave',
                                    'Exited',
                                  ]
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(
                                        v,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (value) =>
                                  setState(() => _status = value ?? 'All'),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    children: <Widget>[
                      Text('${filtered.length} of ${guards.length} employees'),
                      TextButton.icon(
                        onPressed:
                            _query.isEmpty &&
                                    selectedClient == 'All' &&
                                    _status == 'All'
                                ? null
                                : () => setState(() {
                                  _query = '';
                                  _client = 'All';
                                  _status = 'All';
                                  _searchController.clear();
                                }),
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (guards.isEmpty)
                    const StateBlock(
                      icon: Icons.person_off_rounded,
                      title: 'No employees found',
                      message:
                          'Employees assigned to your districts will appear here once available.',
                    )
                  else if (filtered.isEmpty)
                    const StateBlock(
                      icon: Icons.search_off_rounded,
                      title: 'No matching employees',
                      message: 'Try changing your search or filters.',
                    )
                  else
                    ...filtered.map(_GuardDirectoryRow.new),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<GuardProfileModel> _filter(
    List<GuardProfileModel> guards,
    String selectedClient,
  ) {
    final query = _query.trim().toLowerCase();
    return guards.where((guard) {
      final haystack =
          [
            guard.fullName,
            guard.employeeId,
            guard.clientName,
            guard.district,
            guard.phoneNumber,
            guard.status,
          ].join(' ').toLowerCase();
      return haystack.contains(query) &&
          (selectedClient == 'All' ||
              guard.clientName.trim() == selectedClient) &&
          (_status == 'All' || _statusLabel(guard.status) == _status);
    }).toList();
  }
}

class _GuardDirectoryRow extends StatelessWidget {
  const _GuardDirectoryRow(this.guard);
  final GuardProfileModel guard;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);
    final imageUrl = guard.profilePhotoUrl;

    return ModernCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => FieldOfficerGuardProfileScreen(guard: guard),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 24,
                  backgroundColor: tokens.primarySoft,
                  backgroundImage:
                      imageUrl == null || imageUrl.isEmpty
                          ? null
                          : CachedNetworkImageProvider(imageUrl),
                  child:
                      imageUrl == null || imageUrl.isEmpty
                          ? Text(
                            _initials(guard.fullName, guard.employeeId),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: tokens.primaryStrong,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            guard.fullName.isEmpty
                                ? 'Employee'
                                : guard.fullName,
                            style: theme.textTheme.titleSmall,
                            softWrap: true,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          StatusChip(
                            label: _statusLabel(guard.status),
                            tone: _statusTone(guard.status),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: tokens.inkMuted,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (guard.employeeId.isNotEmpty)
                  Text(guard.employeeId, style: theme.textTheme.bodySmall),
                if (guard.clientName.isNotEmpty)
                  Text(guard.clientName, style: theme.textTheme.bodySmall),
                if (DateTime.tryParse(guard.createdAt ?? '')
                    case final enrolled?)
                  Text(
                    'Enrolled ${MaterialLocalizations.of(context).formatMediumDate(enrolled.toLocal())}',
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    if (guard.categoryLabel != null)
                      StatusChip(label: guard.categoryLabel!),
                    if (guard.district.isNotEmpty)
                      StatusChip(
                        label: guard.district,
                        icon: Icons.place_rounded,
                        tone: StatusChipTone.info,
                      ),
                    if (guard.phoneNumber.isNotEmpty)
                      StatusChip(
                        label: guard.phoneNumber,
                        icon: Icons.call_rounded,
                      ),
                    ComplianceTag(
                      label:
                          guard.anyMissingDocuments
                              ? 'Docs pending (${guard.missingDocuments.length})'
                              : 'Docs verified',
                      status:
                          guard.anyMissingDocuments
                              ? ComplianceStatus.pending
                              : ComplianceStatus.verified,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name, String fallback) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.map((p) => p[0]).take(2).join().toUpperCase();
    if (initials.isNotEmpty) return initials;
    final compactFallback = fallback.trim();
    if (compactFallback.isEmpty) return 'GU';
    final end = compactFallback.length < 2 ? compactFallback.length : 2;
    return compactFallback.substring(0, end).toUpperCase();
  }
}

class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader({
    this.onLiveMap,
    this.onRefresh,
    this.horizontalPadding = AppSpacing.md,
  });

  final VoidCallback? onLiveMap;
  final VoidCallback? onRefresh;
  /// Screen margin for the header content. Loading and error states render the
  /// header directly, while the loaded list already supplies the margin.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.sm,
        horizontalPadding,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (Navigator.of(context).canPop()) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: IconButton.styleFrom(foregroundColor: tokens.ink),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 40,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              const CissLogoBadge(size: 40),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      kCompanyName.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: tokens.primaryStrong,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Employee Directory',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Employees assigned to your districts',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.inkMuted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onLiveMap != null || onRefresh != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                IconButton(
                  onPressed: onLiveMap,
                  icon: Icon(
                    Icons.map_rounded,
                    color: tokens.primary,
                    size: 22,
                  ),
                  tooltip: 'Live map',
                ),
                IconButton(
                  onPressed: onRefresh,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: tokens.inkMuted,
                    size: 20,
                  ),
                  tooltip: 'Refresh',
                ),
              ],
            ),
        ],
      ),
    );
  }
}
