import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/models/guard_profile.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../app/theme/app_tokens.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/security_settings_card.dart';
import '../../../../../shared/widgets/document_list_tile.dart';
import '../../../../../shared/widgets/compliance_tag.dart';
import '../../../../../shared/utils/initials.dart';
import '../../../shared/device_identity_row.dart';
import '../widgets/guard_portal_widgets.dart';
import 'guard_aadhaar_correction_screen.dart';
import 'guard_document_upload_screen.dart';

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
            if (profile.categoryLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  profile.categoryLabel!,
                  style: AppTypography.label(context),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),

            // ── Personal information ───────────────────────────────────
            _SectionHeader(title: 'Personal info'),
            const SizedBox(height: AppSpacing.sm),
            _InfoCard(
              rows: <_InfoRow>[
                _InfoRow('Phone', profile.phoneNumber),
                _InfoRow(
                  'Email',
                  (profile.emailAddress ?? '').isEmpty
                      ? '-'
                      : profile.emailAddress!,
                ),
                _InfoRow(
                  'Gender',
                  (profile.gender ?? '').isEmpty ? '-' : profile.gender!,
                ),
                _InfoRow(
                  'Joining Date',
                  _formatDate(profile.joiningDate ?? ''),
                ),
                _InfoRow('Resource ID', profile.resourceIdNumber ?? ''),
                _InfoRow('Address', profile.address ?? ''),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Bank details ───────────────────────────────────────────
            if (profile.bankAccountNumber != null ||
                profile.bankIfscCode != null ||
                profile.bankName != null) ...[
              _SectionHeader(title: 'Bank details'),
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
              _SectionHeader(title: 'Documents'),
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

            // ── Verification status ────────────────────────────────────
            _SectionHeader(title: 'Verification status'),
            const SizedBox(height: AppSpacing.sm),
            ModernCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ComplianceTag(
                    label: 'Aadhaar Card',
                    status:
                        profile.canUploadAadhaar
                            ? ComplianceStatus.missing
                            : ComplianceStatus.verified,
                  ),
                  ComplianceTag(
                    label: 'Identity Proof',
                    status:
                        profile.canUploadIdentity
                            ? ComplianceStatus.missing
                            : ComplianceStatus.verified,
                  ),
                  ComplianceTag(
                    label: 'Address Proof',
                    status:
                        profile.canUploadAddress
                            ? ComplianceStatus.missing
                            : ComplianceStatus.verified,
                  ),
                  ComplianceTag(
                    label: 'Bank Details',
                    status:
                        (profile.bankAccountNumber ?? '').isNotEmpty
                            ? ComplianceStatus.verified
                            : ComplianceStatus.missing,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Document actions ────────────────────────────────────────
            _SectionHeader(title: 'Document actions'),
            const SizedBox(height: AppSpacing.sm),
            if (profile.anyMissingDocuments)
              ModernCard(
                child: ListTile(
                  leading: const Icon(Icons.upload_file_rounded),
                  title: const Text('Upload missing documents'),
                  subtitle: const Text(
                    'Add Aadhaar, identity or address proof',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => GuardDocumentUploadScreen(profile: profile),
                      ),
                    );
                    if (context.mounted) ref.invalidate(guardProfileProvider);
                  },
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            ModernCard(
              child: ListTile(
                leading: const Icon(Icons.published_with_changes_rounded),
                title: const Text('Request Aadhaar correction'),
                subtitle: const Text(
                  'Notify us about an Aadhaar detail to fix',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GuardAadhaarCorrectionScreen(),
                    ),
                  );
                  if (context.mounted) ref.invalidate(guardProfileProvider);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── ID proof details ───────────────────────────────────────
            if (profile.idProofNumber != null &&
                profile.idProofNumber!.isNotEmpty) ...[
              _SectionHeader(title: 'ID proof details'),
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
              _SectionHeader(title: 'Address proof details'),
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
            const SizedBox(height: AppSpacing.sm),
            const DeviceIdentityRow(),
            const SizedBox(height: AppSpacing.sm),
            ModernCard(
              child: ListTile(
                leading: const Icon(Icons.pin_rounded),
                title: const Text('Change PIN'),
                subtitle: const Text('Update your guard login PIN'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap:
                    () => showDialog<void>(
                      context: context,
                      builder: (_) => const _ChangePinDialog(),
                    ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChangePinDialog extends ConsumerStatefulWidget {
  const _ChangePinDialog();

  @override
  ConsumerState<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends ConsumerState<_ChangePinDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_next.text != _confirm.text ||
        !RegExp(r'^\d{4,6}$').hasMatch(_next.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New PIN must be 4–6 digits and match confirmation.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(mobileRepositoryProvider)
          .changeGuardPin(currentPin: _current.text, newPin: _next.text);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN changed successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _current,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Current PIN'),
          ),
          TextField(
            controller: _next,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'New PIN'),
          ),
          TextField(
            controller: _confirm,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Confirm new PIN'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child:
              _saving
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Change'),
        ),
      ],
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
    final isActive =
        profile.status.isEmpty ||
        profile.status.toLowerCase().contains('active');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.primary,
        borderRadius: BorderRadius.circular(AppRadius.md),
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
                        ? CachedNetworkImageProvider(profile.profilePhotoUrl!)
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
                tone:
                    isActive ? StatusChipTone.success : StatusChipTone.warning,
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
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: tokens.inkMuted,
        letterSpacing: 0.2,
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
