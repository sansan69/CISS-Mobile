import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/guard_profile.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/network/ciss_error.dart';
import '../../../../../shared/widgets/metric_tile.dart';
import '../../../../../shared/widgets/portal_primitives.dart';
import '../../../../../core/cache/skeleton_widgets.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../auth/application/auth_controller.dart';

final FutureProvider<List<GuardProfileModel>> fieldOfficerGuardsProvider =
    FutureProvider<List<GuardProfileModel>>((Ref ref) {
  final session = ref.watch(authSessionProvider).value;
  final district = session?.assignedDistricts.isNotEmpty == true
      ? session!.assignedDistricts.first
      : null;
  return ref
      .watch(mobileRepositoryProvider)
      .fetchFieldOfficerGuards(district: district);
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
  String _selectedClient = 'all';
  String _selectedDistrict = 'all';
  String _selectedStatus = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guardsAsync = ref.watch(fieldOfficerGuardsProvider);
    return guardsAsync.when(
      loading: () => const SkeletonPage(cardCount: 5),
      error: (Object error, StackTrace stackTrace) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: StateBlock(
              icon: Icons.groups_2_outlined,
              title: 'Could not load guards',
              message: CissError.parse(error),
              action: FilledButton.tonal(
                onPressed: () => ref.invalidate(fieldOfficerGuardsProvider),
                child: const Text('Try again'),
              ),
            ),
          ),
        ),
      ),
      data: (guards) {
        final filtered = _filter(guards);
        final clientOptions = guards
            .map((guard) => guard.clientName.trim())
            .where((client) => client.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final districtOptions = guards
            .map((guard) => guard.district.trim())
            .where((district) => district.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final statusOptions = guards
            .map((guard) => guard.status.trim())
            .where((status) => status.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        return ScreenScaffold(
          title: 'Guards',
          subtitle: 'Employee directory for your districts',
          actions: <Widget>[
            IconButton(
              onPressed: () => ref.invalidate(fieldOfficerGuardsProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: MetricTile(
                    label: 'Visible',
                    value: filtered.length.toString(),
                    helper: '${guards.length} total in scope',
                    icon: Icons.groups_2_outlined,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MetricTile(
                    label: 'Districts',
                    value: districtOptions.length.toString(),
                    helper:
                        '${clientOptions.length} client${clientOptions.length == 1 ? '' : 's'}',
                    icon: Icons.map_outlined,
                  ),
                ),
              ],
            ),
            PortalSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const PortalSectionHeading(title: 'Filters & Search'),
                  const SizedBox(height: AppSpacing.md),
                  const PortalFieldLabel('Search'),
                  TextField(
                    controller: _searchController,
                    onChanged: (String value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search by name, ID, or phone',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _DirectoryFilter(
                          label: 'Client',
                          value: _selectedClient,
                          options: clientOptions,
                          allLabel: 'All Clients',
                          onChanged: (String? value) {
                            if (value == null) return;
                            setState(() => _selectedClient = value);
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _DirectoryFilter(
                          label: 'District',
                          value: _selectedDistrict,
                          options: districtOptions,
                          allLabel: 'All Districts',
                          onChanged: (String? value) {
                            if (value == null) return;
                            setState(() => _selectedDistrict = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DirectoryFilter(
                    label: 'Status',
                    value: _selectedStatus,
                    options: statusOptions,
                    allLabel: 'All Statuses',
                    onChanged: (String? value) {
                      if (value == null) return;
                      setState(() => _selectedStatus = value);
                    },
                  ),
                ],
              ),
            ),
            if (guards.isEmpty)
              const StateBlock(
                icon: Icons.person_off_outlined,
                title: 'No guards found',
                message:
                    'Guards assigned to your districts will appear here once available.',
              )
            else if (filtered.isEmpty)
              const StateBlock(
                icon: Icons.search_off_rounded,
                title: 'No matching guards',
                message:
                    'Try changing the search, client, district, or status filters.',
              )
            else
              ...filtered.map(_GuardDirectoryRow.new),
          ],
        );
      },
    );
  }

  List<GuardProfileModel> _filter(List<GuardProfileModel> guards) {
    final String query = _query.trim().toLowerCase();
    return guards.where((GuardProfileModel guard) {
      if (_selectedClient != 'all' && guard.clientName != _selectedClient) {
        return false;
      }
      if (_selectedDistrict != 'all' && guard.district != _selectedDistrict) {
        return false;
      }
      if (_selectedStatus != 'all' && guard.status != _selectedStatus) {
        return false;
      }
      if (query.isEmpty) return true;
      final String haystack = <String>[
        guard.fullName,
        guard.employeeId,
        guard.clientName,
        guard.district,
        guard.phoneNumber,
        guard.status,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }
}

class _DirectoryFilter extends StatelessWidget {
  const _DirectoryFilter({
    required this.label,
    required this.value,
    required this.options,
    required this.allLabel,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final String allLabel;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PortalFieldLabel(label),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(
              value: 'all',
              child: Text(allLabel),
            ),
            ...options.map(
              (String option) => DropdownMenuItem<String>(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onChanged,
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}

class _GuardDirectoryRow extends StatefulWidget {
  const _GuardDirectoryRow(this.guard);
  final GuardProfileModel guard;

  @override
  State<_GuardDirectoryRow> createState() => _GuardDirectoryRowState();
}

class _GuardDirectoryRowState extends State<_GuardDirectoryRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);
    final guard = widget.guard;
    final String? imageUrl = guard.profilePhotoUrl;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: PortalSurfaceCard(
        padding: EdgeInsets.zero,
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
                    backgroundImage: imageUrl == null || imageUrl.isEmpty
                        ? null
                        : NetworkImage(imageUrl),
                    child: imageUrl == null || imageUrl.isEmpty
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                guard.fullName.isEmpty ? 'Guard' : guard.fullName,
                                style: theme.textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            _statusChip(guard.status),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          [
                            if (guard.employeeId.isNotEmpty) guard.employeeId,
                            if (guard.clientName.isNotEmpty) guard.clientName,
                          ].join(' • '),
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: <Widget>[
                            if (guard.district.isNotEmpty)
                              StatusChip(
                                label: guard.district,
                                icon: Icons.place_outlined,
                                tone: StatusChipTone.info,
                              ),
                            if (guard.phoneNumber.isNotEmpty)
                              StatusChip(
                                label: guard.phoneNumber,
                                icon: Icons.call_outlined,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (_expanded) ...<Widget>[
              Divider(height: 1, color: tokens.border),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: <Widget>[
                    if (guard.employeeId.isNotEmpty)
                      _InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'Employee ID',
                        value: guard.employeeId,
                        tokens: tokens,
                      ),
                    if (guard.clientName.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _InfoRow(
                        icon: Icons.business_rounded,
                        label: 'Client',
                        value: guard.clientName,
                        tokens: tokens,
                      ),
                    ],
                    if (guard.district.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _InfoRow(
                        icon: Icons.place_outlined,
                        label: 'District',
                        value: guard.district,
                        tokens: tokens,
                      ),
                    ],
                    if (guard.phoneNumber.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _InfoRow(
                        icon: Icons.call_outlined,
                        label: 'Phone',
                        value: guard.phoneNumber,
                        tokens: tokens,
                      ),
                    ],
                    if (guard.gender != null && guard.gender!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Gender',
                        value: guard.gender!,
                        tokens: tokens,
                      ),
                    ],
                    if (guard.joiningDate != null &&
                        guard.joiningDate!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Joined',
                        value: _formatDateLabel(guard.joiningDate!),
                        tokens: tokens,
                      ),
                    ],
                    if (guard.resourceIdNumber != null &&
                        guard.resourceIdNumber!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _InfoRow(
                        icon: Icons.fingerprint_rounded,
                        label: 'ID Number',
                        value: guard.resourceIdNumber!,
                        tokens: tokens,
                      ),
                    ],
                    if (guard.address != null && guard.address!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _InfoRow(
                        icon: Icons.home_outlined,
                        label: 'Address',
                        value: guard.address!,
                        tokens: tokens,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  StatusChip _statusChip(String status) {
    final String normalized = status.trim().toLowerCase();
    if (normalized == 'inactive') {
      return const StatusChip(label: 'Inactive', tone: StatusChipTone.neutral);
    }
    if (normalized == 'onleave') {
      return const StatusChip(label: 'OnLeave', tone: StatusChipTone.warning);
    }
    if (normalized == 'exited') {
      return const StatusChip(label: 'Exited', tone: StatusChipTone.danger);
    }
    return StatusChip(
      label: status.isEmpty ? 'Active' : status,
      tone: StatusChipTone.success,
    );
  }

  String _formatDateLabel(String raw) {
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.day.toString().padLeft(2, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.year}';
  }

  String _initials(String name, String fallback) {
    final Iterable<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty);
    final String initials = parts.map((String p) => p[0]).take(2).join().toUpperCase();
    if (initials.isNotEmpty) return initials;
    final String compactFallback = fallback.trim();
    if (compactFallback.isEmpty) return 'GU';
    final int end = compactFallback.length < 2 ? compactFallback.length : 2;
    return compactFallback.substring(0, end).toUpperCase();
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.tokens,
  });

  final IconData icon;
  final String label;
  final String value;
  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: tokens.inkMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.inkMuted,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.ink,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
