import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/models/guard_profile.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../app/theme/app_tokens.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/security_settings_card.dart';
import '../widgets/guard_portal_widgets.dart';

final FutureProvider<GuardProfileModel> guardProfileProvider =
    FutureProvider<GuardProfileModel>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchGuardProfile();
    });

class GuardProfileScreen extends ConsumerWidget {
  const GuardProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(guardProfileProvider);
    return profileAsync.when(
      loading:
          () => const GuardLoadingScaffold(label: 'Loading guard profile...'),
      error:
          (Object error, StackTrace stackTrace) => GuardErrorScaffold(
            title: 'Could not load profile',
            error: error,
            onRetry: () => ref.invalidate(guardProfileProvider),
          ),
      data: (profile) {
        return ScreenScaffold(
          title: 'Profile',
          subtitle: profile.employeeId,
          actions: <Widget>[
            IconButton(
              onPressed: () => ref.invalidate(guardProfileProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          children: <Widget>[
            GuardHeroPanel(
              eyebrow: 'Guard profile',
              title: profile.fullName,
              subtitle:
                  '${profile.clientName} • ${profile.district} • ${profile.employeeId}',
              icon: Icons.person_rounded,
              accentColor:
                  profile.status.toLowerCase().contains('active') ||
                          profile.status.isEmpty
                      ? CissThemeTokens.of(context).success
                      : CissThemeTokens.of(context).warning,
              trailing: _ProfileAvatar(photoUrl: profile.profilePhotoUrl),
            ),
            const SizedBox(height: AppSpacing.lg),
            GuardMetricStrip(
              items: <GuardMetricItem>[
                GuardMetricItem(
                  label: 'Status',
                  value: profile.status.isEmpty ? 'Active' : profile.status,
                  icon: Icons.verified_user_rounded,
                  color: CissThemeTokens.of(context).success,
                ),
                GuardMetricItem(
                  label: 'District',
                  value: profile.district.isEmpty ? '-' : profile.district,
                  icon: Icons.place_rounded,
                  color: CissThemeTokens.of(context).primary,
                ),
                GuardMetricItem(
                  label: 'Client',
                  value: profile.clientName.isEmpty ? '-' : profile.clientName,
                  icon: Icons.apartment_rounded,
                  color: CissThemeTokens.of(context).accent,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            GuardRecordCard(
              title: profile.fullName,
              subtitle:
                  '${profile.clientName} • ${profile.district} • ${profile.status}',
              icon: Icons.badge_rounded,
              chip: StatusChip(
                label: profile.status.isEmpty ? 'Profile' : profile.status,
                tone:
                    profile.status.toLowerCase().contains('active') ||
                            profile.status.isEmpty
                        ? StatusChipTone.success
                        : profile.status.toLowerCase().contains('suspend')
                        ? StatusChipTone.danger
                        : StatusChipTone.warning,
              ),
            ),
            _InfoCard(
              rows: <_InfoRow>[
                _InfoRow('Phone', profile.phoneNumber),
                _InfoRow(
                  'Gender',
                  (profile.gender ?? '').isEmpty ? '-' : profile.gender!,
                ),
                _InfoRow('Joining Date', profile.joiningDate ?? ''),
                _InfoRow('Resource ID', profile.resourceIdNumber ?? ''),
                _InfoRow('Address', profile.address ?? ''),
              ],
            ),
            const SecuritySettingsCard(),
          ],
        );
      },
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.white.withValues(alpha: 0.16),
      backgroundImage: url == null || url.isEmpty ? null : NetworkImage(url),
      child:
          url == null || url.isEmpty
              ? const Icon(Icons.person_rounded, color: Colors.white)
              : null,
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children:
            rows
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 120,
                          child: Text(
                            row.label,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: tokens.inkMuted),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            row.value.isEmpty ? '-' : row.value,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(color: tokens.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}
