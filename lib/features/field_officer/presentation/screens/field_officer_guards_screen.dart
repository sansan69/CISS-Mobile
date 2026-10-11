import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
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

final FutureProvider<List<GuardProfileModel>> fieldOfficerGuardsProvider =
    FutureProvider<List<GuardProfileModel>>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchFieldOfficerGuards();
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
            body: Column(
              children: <Widget>[
                BrandBanner(
                  title: 'Guards',
                  subtitle: 'Guard directory and live duty locations',
                ),
                Expanded(child: Center(child: CircularProgressIndicator())),
              ],
            ),
          ),
      error:
          (Object error, StackTrace stackTrace) => Scaffold(
            body: Column(
              children: <Widget>[
                const BrandBanner(
                  title: 'Guards',
                  subtitle: 'Guard directory and live duty locations',
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: StateBlock(
                        icon: Icons.groups_2_rounded,
                        title: 'Could not load guards',
                        message: '$error',
                        action: FilledButton.tonal(
                          onPressed:
                              () => ref.invalidate(fieldOfficerGuardsProvider),
                          child: const Text('Try again'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      data: (guards) {
        final filtered = _filter(guards);
        final tokens = CissThemeTokens.of(context);

        return Scaffold(
          backgroundColor: tokens.canvas,
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(fieldOfficerGuardsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                100,
              ),
              children: <Widget>[
                BrandBanner(
                  title: 'Guards',
                  subtitle: 'Guard directory and live duty locations',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const FieldOfficerLiveMapScreen(),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.map_rounded,
                          color: tokens.primary,
                          size: 22,
                        ),
                        tooltip: 'Live map',
                      ),
                      IconButton(
                        onPressed:
                            () => ref.invalidate(fieldOfficerGuardsProvider),
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: tokens.inkMuted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        MetricCard(
                          label: 'Visible',
                          value: guards.length.toString(),
                          color: tokens.primary,
                          width: 140,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        MetricCard(
                          label: 'Districts',
                          value:
                              '${guards.map((g) => g.district).where((d) => d.trim().isNotEmpty).toSet().length}',
                          color: tokens.accent,
                          width: 140,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    labelText: 'Search guards',
                    hintText: 'Name, employee ID, client, district, phone',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: tokens.surface,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (guards.isEmpty)
                  const StateBlock(
                    icon: Icons.person_off_rounded,
                    title: 'No guards found',
                    message:
                        'Guards assigned to your districts will appear here once available.',
                  )
                else if (filtered.isEmpty)
                  const StateBlock(
                    icon: Icons.search_off_rounded,
                    title: 'No matching guards',
                    message: 'Try a different name, ID, client, or district.',
                  )
                else
                  ...filtered.map(_GuardDirectoryRow.new),
              ],
            ),
          ),
        );
      },
    );
  }

  List<GuardProfileModel> _filter(List<GuardProfileModel> guards) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return guards;
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
      return haystack.contains(query);
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
                          : NetworkImage(imageUrl),
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
                          StatusChip(
                            label:
                                guard.status.isEmpty ? 'Active' : guard.status,
                            tone: StatusChipTone.success,
                          ),
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
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: tokens.inkMuted,
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
