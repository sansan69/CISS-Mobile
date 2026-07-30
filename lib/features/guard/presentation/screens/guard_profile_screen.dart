import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/models/guard_profile.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../app/theme/app_tokens.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/security_settings_card.dart';
import '../../../../../shared/widgets/document_list_tile.dart';
import '../../../../../shared/utils/initials.dart';
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
        final tokens = CissThemeTokens.of(context);
        final docs = profile.documents;

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
            // ── Hero panel ─────────────────────────────────────────────
            _ProfileHero(profile: profile),
            const SizedBox(height: AppSpacing.lg),

            // ── Metric strip ───────────────────────────────────────────
            GuardMetricStrip(
              items: <GuardMetricItem>[
                GuardMetricItem(
                  label: 'Status',
                  value: profile.status.isEmpty ? 'Active' : profile.status,
                  icon: Icons.verified_user_rounded,
                  color: tokens.success,
                ),
                GuardMetricItem(
                  label: 'District',
                  value: profile.district.isEmpty ? '-' : profile.district,
                  icon: Icons.place_rounded,
                  color: tokens.primary,
                ),
                GuardMetricItem(
                  label: 'Client',
                  value: profile.clientName.isEmpty ? '-' : profile.clientName,
                  icon: Icons.apartment_rounded,
                  color: tokens.accent,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Personal information ───────────────────────────────────
            _SectionHeader(title: 'PERSONAL INFO'),
            const SizedBox(height: AppSpacing.sm),
            _InfoCard(
              rows: <_InfoRow>[
                _InfoRow('Phone', profile.phoneNumber),
                _InfoRow(
                    'Email',
                    (profile.emailAddress ?? '').isEmpty
                        ? '-'
                        : profile.emailAddress!),
                _InfoRow(
                    'Gender',
                    (profile.gender ?? '').isEmpty ? '-' : profile.gender!),
                _InfoRow(
                    'Joining Date',
                    _formatDate(profile.joiningDate ?? '')),
                _InfoRow('Resource ID', profile.resourceIdNumber ?? ''),
                _InfoRow('Address', profile.address ?? ''),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Bank details ───────────────────────────────────────────
            if (profile.bankAccountNumber != null ||
                profile.bankIfscCode != null ||
                profile.bankName != null) ...[
              _SectionHeader(title: 'BANK DETAILS'),
              const SizedBox(height: AppSpacing.sm),
              _InfoCard(
                rows: <_InfoRow>[
                  if (profile.bankName != null && profile.bankName!.isNotEmpty)
                    _InfoRow('Bank', profile.bankName!),
                  if (profile.bankAccountNumber != null &&
                      profile.bankAccountNumber!.isNotEmpty)
                    _InfoRow('Account Number', profile.bankAccountNumber!),
                  if (profile.bankIfscCode != null &&
                      profile.bankIfscCode!.isNotEmpty)
                    _InfoRow('IFSC Code', profile.bankIfscCode!),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Documents ──────────────────────────────────────────────
            if (docs.isNotEmpty) ...[
              _SectionHeader(title: 'DOCUMENTS'),
              const SizedBox(height: AppSpacing.sm),
              ...docs.map(
                (doc) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: DocumentListTile(
                    name: doc.label,
                    url: doc.url,
                    fileType: _guessFileType(doc.url),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── ID proof details ───────────────────────────────────────
            if (profile.idProofNumber != null &&
                profile.idProofNumber!.isNotEmpty) ...[
              _SectionHeader(title: 'ID PROOF DETAILS'),
              const SizedBox(height: AppSpacing.sm),
              _InfoCard(
                rows: <_InfoRow>[
                  if (profile.idProofType != null &&
                      profile.idProofType!.isNotEmpty)
                    _InfoRow('Type', profile.idProofType!),
                  _InfoRow('Number', profile.idProofNumber!),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Address proof details ──────────────────────────────────
            if (profile.addressProofNumber != null &&
                profile.addressProofNumber!.isNotEmpty) ...[
              _SectionHeader(title: 'ADDRESS PROOF DETAILS'),
              const SizedBox(height: AppSpacing.sm),
              _InfoCard(
                rows: <_InfoRow>[
                  if (profile.addressProofType != null &&
                      profile.addressProofType!.isNotEmpty)
                    _InfoRow('Type', profile.addressProofType!),
                  _InfoRow('Number', profile.addressProofNumber!),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Security settings ──────────────────────────────────────
            const SecuritySettingsCard(),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Profile hero
// ═════════════════════════════════════════════════════════════════════════════

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});

  final GuardProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final isActive = profile.status.isEmpty ||
        profile.status.toLowerCase().contains('active');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tokens.primary, tokens.primaryStrong],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tokens.primaryStrong.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: tokens.surface.withValues(alpha: 0.16),
                backgroundImage:
                    (profile.profilePhotoUrl != null &&
                            profile.profilePhotoUrl!.isNotEmpty)
                        ? NetworkImage(profile.profilePhotoUrl!)
                        : null,
                child:
                    (profile.profilePhotoUrl == null ||
                            profile.profilePhotoUrl!.isEmpty)
                        ? Text(
                            initials(profile.fullName, fallback: 'G'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: tokens.surface,
                            ),
                          )
                        : null,
              ),
              const Spacer(),
              // Status chip
              StatusChip(
                label: profile.status.isEmpty ? 'Active' : profile.status,
                tone: isActive
                    ? StatusChipTone.success
                    : StatusChipTone.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            profile.fullName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            [
              if (profile.clientName.isNotEmpty) profile.clientName,
              if (profile.district.isNotEmpty) profile.district,
              profile.employeeId,
            ].join(' • '),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Section header
// ═════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: tokens.inkMuted,
        letterSpacing: 2,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Info card (label / value rows)
// ═════════════════════════════════════════════════════════════════════════════

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return ModernCard(
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

// ═════════════════════════════════════════════════════════════════════════════
// Helpers
// ═════════════════════════════════════════════════════════════════════════════

String _formatDate(String value) {
  if (value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
}

String _guessFileType(String url) {
  final lower = url.toLowerCase();
  if (lower.endsWith('.pdf')) return 'pdf';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image';
  if (lower.endsWith('.png')) return 'image';
  if (lower.endsWith('.gif')) return 'image';
  if (lower.endsWith('.webp')) return 'image';
  // Firebase Storage URLs don't always have extensions
  return 'image';
}
