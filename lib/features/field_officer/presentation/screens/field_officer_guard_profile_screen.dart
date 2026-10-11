import 'package:flutter/material.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/guard_profile.dart';
import '../../../../../shared/widgets/brand_banner.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/status_chip.dart';

/// Profile view opened from the Field Officer Guards directory.
///
/// Operational views such as live location and attendance intentionally do
/// not belong here. They have their own menu entry and screen.
class FieldOfficerGuardProfileScreen extends StatelessWidget {
  const FieldOfficerGuardProfileScreen({super.key, required this.guard});

  final GuardProfileModel guard;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final displayName =
        guard.fullName.trim().isEmpty ? 'Guard profile' : guard.fullName;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          BrandBanner(
            title: displayName,
            subtitle: 'Guard profile',
            showBackButton: true,
          ),
          const SizedBox(height: AppSpacing.md),
          _ProfileHero(guard: guard),
          const SizedBox(height: AppSpacing.md),
          _ProfileSection(
            title: 'Personal information',
            icon: Icons.person_outline_rounded,
            fields: <_ProfileFieldData>[
              _ProfileFieldData('Full name', guard.fullName),
              _ProfileFieldData('Date of birth', guard.dateOfBirth),
              _ProfileFieldData('Gender', guard.gender),
              _ProfileFieldData("Father's name", guard.fatherName),
              _ProfileFieldData("Mother's name", guard.motherName),
              _ProfileFieldData('Marital status', guard.maritalStatus),
              if (_hasText(guard.maritalStatus, equals: 'married'))
                _ProfileFieldData('Spouse name', guard.spouseName),
              _ProfileFieldData(
                'Educational qualification',
                _preferredQualification(guard),
              ),
              _ProfileFieldData('Nationality', guard.nationality),
              _ProfileFieldData('District', guard.district),
              _ProfileFieldData(
                'Identification mark',
                guard.identificationMark,
              ),
              _ProfileFieldData(
                'Height',
                guard.heightCm == null
                    ? null
                    : '${_numberText(guard.heightCm!)} cm',
              ),
              _ProfileFieldData(
                'Weight',
                guard.weightKg == null
                    ? null
                    : '${_numberText(guard.weightKg!)} kg',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ProfileSection(
            title: 'Contact details',
            icon: Icons.contact_phone_outlined,
            fields: <_ProfileFieldData>[
              _ProfileFieldData('Phone number', guard.phoneNumber),
              _ProfileFieldData('Email address', guard.emailAddress),
              _ProfileFieldData('Full address', guard.address, multiline: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ProfileSection(
            title: 'Employment details',
            icon: Icons.work_outline_rounded,
            fields: <_ProfileFieldData>[
              _ProfileFieldData('Employee ID', guard.employeeId),
              _ProfileFieldData('Client name', guard.clientName),
              _ProfileFieldData('Assigned site', guard.siteName),
              _ProfileFieldData('Job designation', guard.jobDesignation),
              _ProfileFieldData('Resource ID', guard.resourceIdNumber),
              _ProfileFieldData('Joining date', guard.joiningDate),
              _ProfileFieldData('Status', guard.status),
              if (_hasText(guard.exitDate))
                _ProfileFieldData('Exit date', guard.exitDate),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _IdentificationSection(guard: guard),
        ],
      ),
    );
  }

  static String? _preferredQualification(GuardProfileModel guard) {
    final value = guard.educationalQualification?.trim();
    if (value == null || value.isEmpty) return guard.qualificationName;
    if (value.toLowerCase() == 'any other qualification') {
      return guard.otherQualification ?? guard.qualificationName;
    }
    return value;
  }

  static bool _hasText(String? value, {String? equals}) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return false;
    return equals == null || text.toLowerCase() == equals.toLowerCase();
  }

  static String _numberText(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.guard});

  final GuardProfileModel guard;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);
    final imageUrl = guard.profilePhotoUrl;

    return ModernCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          CircleAvatar(
            radius: 38,
            backgroundColor: tokens.primarySoft,
            backgroundImage:
                imageUrl == null || imageUrl.isEmpty
                    ? null
                    : NetworkImage(imageUrl),
            child:
                imageUrl == null || imageUrl.isEmpty
                    ? Text(
                      _initials(guard.fullName, guard.employeeId),
                      style: theme.textTheme.headlineSmall?.copyWith(
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
                Text(
                  guard.fullName.isEmpty ? 'Guard' : guard.fullName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  [
                    if (guard.employeeId.isNotEmpty) guard.employeeId,
                    if (guard.clientName.isNotEmpty) guard.clientName,
                  ].join(' • '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    StatusChip(
                      label: guard.status.isEmpty ? 'Active' : guard.status,
                      tone: _statusTone(guard.status),
                    ),
                    if (guard.district.isNotEmpty)
                      StatusChip(
                        label: guard.district,
                        icon: Icons.place_rounded,
                        tone: StatusChipTone.info,
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
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.fields,
  });

  final String title;
  final IconData icon;
  final List<_ProfileFieldData> fields;

  @override
  Widget build(BuildContext context) {
    final visibleFields = fields.where((field) => field.hasValue).toList();
    if (visibleFields.isEmpty) return const SizedBox.shrink();

    final tokens = CissThemeTokens.of(context);
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: tokens.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...visibleFields.indexed.expand(
            (item) => <Widget>[
              if (item.$1 > 0) Divider(height: 1, color: tokens.border),
              _ProfileField(field: item.$2),
            ],
          ),
        ],
      ),
    );
  }
}

class _IdentificationSection extends StatelessWidget {
  const _IdentificationSection({required this.guard});

  final GuardProfileModel guard;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final fields =
        <_ProfileFieldData>[
          _ProfileFieldData(
            'Identity proof',
            _joinProof(guard.idProofType, guard.idProofNumber),
          ),
          _ProfileFieldData(
            'Address proof',
            _joinProof(guard.addressProofType, guard.addressProofNumber),
          ),
        ].where((field) => field.hasValue).toList();

    final completion = <Widget>[
      _DocumentStatusChip(
        label: 'Identity',
        status: guard.documentStatus['identity'],
        available: guard.documentAvailability['identityFront'] == true,
      ),
      _DocumentStatusChip(
        label: 'Address',
        status: guard.documentStatus['address'],
        available: guard.documentAvailability['addressFront'] == true,
      ),
      _DocumentStatusChip(
        label: 'Signature',
        status: guard.documentStatus['signature'],
        available: guard.documentAvailability['signature'] == true,
      ),
    ];

    if (fields.isEmpty &&
        guard.documentStatus.isEmpty &&
        guard.documentAvailability.isEmpty) {
      return const SizedBox.shrink();
    }

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.verified_user_outlined,
                size: 20,
                color: tokens.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Identification & documents',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (fields.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            ...fields.indexed.expand(
              (item) => <Widget>[
                if (item.$1 > 0) Divider(height: 1, color: tokens.border),
                _ProfileField(field: item.$2),
              ],
            ),
          ],
          if (guard.documentStatus.isNotEmpty ||
              guard.documentAvailability.isNotEmpty) ...<Widget>[
            if (fields.isNotEmpty) const SizedBox(height: AppSpacing.sm),
            Text(
              'Document completion',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: tokens.inkMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: completion,
            ),
          ],
        ],
      ),
    );
  }

  static String? _joinProof(String? type, String? number) {
    final parts = <String>[
      if (type?.trim().isNotEmpty == true) type!.trim(),
      if (number?.trim().isNotEmpty == true) number!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' • ');
  }
}

class _DocumentStatusChip extends StatelessWidget {
  const _DocumentStatusChip({
    required this.label,
    required this.status,
    required this.available,
  });

  final String label;
  final String? status;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final complete = status == 'complete' || available;
    return StatusChip(
      label: '$label: ${complete ? 'On file' : 'Missing'}',
      icon:
          complete
              ? Icons.check_circle_outline_rounded
              : Icons.info_outline_rounded,
      tone: complete ? StatusChipTone.success : StatusChipTone.warning,
    );
  }
}

class _ProfileFieldData {
  const _ProfileFieldData(this.label, this.value, {this.multiline = false});

  final String label;
  final String? value;
  final bool multiline;

  bool get hasValue => value?.trim().isNotEmpty == true;
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.field});

  final _ProfileFieldData field;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child:
          field.multiline
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    field.label,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.inkMuted),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    field.value!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
              : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      field.label,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: tokens.inkMuted),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    child: Text(
                      field.value!,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

StatusChipTone _statusTone(String status) {
  switch (status.trim().toLowerCase()) {
    case 'active':
    case 'on duty':
    case 'present':
      return StatusChipTone.success;
    case 'inactive':
    case 'exited':
    case 'left':
      return StatusChipTone.danger;
    case 'pending':
      return StatusChipTone.warning;
    default:
      return StatusChipTone.neutral;
  }
}

String _initials(String name, String fallback) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  final initials = parts.map((part) => part[0]).take(2).join().toUpperCase();
  if (initials.isNotEmpty) return initials;
  final compactFallback = fallback.trim();
  if (compactFallback.isEmpty) return 'GU';
  final end = compactFallback.length < 2 ? compactFallback.length : 2;
  return compactFallback.substring(0, end).toUpperCase();
}
