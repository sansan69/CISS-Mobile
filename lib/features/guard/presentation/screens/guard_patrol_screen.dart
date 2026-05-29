import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/patrol_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/camera_capture_screen.dart';
import '../../../../../shared/widgets/portal_primitives.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/section_card.dart';
import '../../../../../shared/widgets/state_block.dart';

final FutureProvider<GuardPatrolStatusModel> guardPatrolStatusProvider =
    FutureProvider<GuardPatrolStatusModel>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchGuardPatrolStatus();
    });

String _formatIsoLabel(String? value) {
  if (value == null || value.isEmpty) return '—';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return '—';
  final local = parsed.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} $hour:$minute $suffix';
}

class GuardPatrolScreen extends ConsumerStatefulWidget {
  const GuardPatrolScreen({super.key});

  @override
  ConsumerState<GuardPatrolScreen> createState() => _GuardPatrolScreenState();
}

class _GuardPatrolScreenState extends ConsumerState<GuardPatrolScreen> {
  String? _selectedPatrolPointId;
  String? _photoPath;
  final TextEditingController _notesController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const CameraCaptureScreen(),
      ),
    );
    if (!mounted) return;
    setState(() => _photoPath = path);
  }

  Future<void> _submit(GuardPatrolStatusModel status, String type) async {
    final activeDuty = status.activeDuty;
    if (activeDuty == null) {
      setState(() => _error = 'Start duty attendance before using patrol monitoring.');
      return;
    }

    final selectedPoint = status.patrolPoints.where(
      (point) => point.id == _selectedPatrolPointId,
    );
    final patrolPoint = selectedPoint.isEmpty ? null : selectedPoint.first;
    final requiresPhoto = type == 'hourly_photo' ||
        status.settings.photoRequiredForPatrol ||
        patrolPoint?.requiresPhoto == true;
    if (requiresPhoto && _photoPath == null) {
      setState(() => _error = 'Capture a photo before submitting.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      String? photoUrl;
      if (_photoPath != null) {
        final file = File(_photoPath!);
        final bytes = await file.readAsBytes();
        final dataUrl = await ref
            .read(mobileRepositoryProvider)
            .encodeFileToDataUrl(bytes, 'image/jpeg');
        final uploadResult = await ref
            .read(mobileRepositoryProvider)
            .uploadAttendancePhoto(
              path:
                  'patrol/${status.employeeId}/${DateTime.now().millisecondsSinceEpoch}.jpg',
              dataUrl: dataUrl,
            );
        photoUrl = uploadResult['url'] as String?;
      }

      await ref.read(mobileRepositoryProvider).submitGuardPatrolActivity(
        <String, dynamic>{
          'type': type,
          'siteId': activeDuty.siteId,
          if (activeDuty.dutyPointId != null) 'dutyPointId': activeDuty.dutyPointId,
          if (activeDuty.shiftCode != null) 'shiftCode': activeDuty.shiftCode,
          if (patrolPoint != null) 'patrolPointId': patrolPoint.id,
          if (photoUrl case final String uploadedPhotoUrl) 'photoUrl': uploadedPhotoUrl,
          if (_notesController.text.trim().isNotEmpty)
            'notes': _notesController.text.trim(),
          'activityAt': DateTime.now().toUtc().toIso8601String(),
        },
      );

      if (!mounted) return;
      setState(() {
        _photoPath = null;
        _notesController.clear();
        if (type == 'patrol') {
          _selectedPatrolPointId = null;
        }
      });
      ref.invalidate(guardPatrolStatusProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            type == 'hourly_photo'
                ? 'Hourly night check submitted.'
                : 'Patrol round submitted.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patrolAsync = ref.watch(guardPatrolStatusProvider);
    final tokens = CissThemeTokens.of(context);

    return patrolAsync.when(
      loading: () => ScreenScaffold(
        title: 'Patrol',
        subtitle: 'Loading duty monitoring',
        children: const <Widget>[
          Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          )),
        ],
      ),
      error: (Object error, _) => ScreenScaffold(
        title: 'Patrol',
        subtitle: 'Could not load patrol status',
        children: <Widget>[
          StateBlock(
            icon: Icons.error_outline_rounded,
            title: 'Patrol setup unavailable',
            message: error.toString(),
          ),
        ],
      ),
      data: (GuardPatrolStatusModel status) {
        final activeDuty = status.activeDuty;
        final selectedPatrolPoint = status.patrolPoints.where(
          (point) => point.id == _selectedPatrolPointId,
        );
        final patrolPoint =
            selectedPatrolPoint.isEmpty ? null : selectedPatrolPoint.first;

        return ScreenScaffold(
          title: 'Patrol',
          subtitle: status.clientName,
          actions: <Widget>[
            IconButton(
              onPressed: () => ref.invalidate(guardPatrolStatusProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          children: <Widget>[
            if (!status.enabled)
              const StateBlock(
                icon: Icons.shield_outlined,
                title: 'Patrol monitoring is off',
                message:
                    'This client has not enabled patrol rounds or hourly night-photo checks.',
              )
            else if (activeDuty == null)
              const StateBlock(
                icon: Icons.fact_check_outlined,
                title: 'No active duty session',
                message:
                    'Check in to your duty first. Patrol and hourly proof only open while you are on active duty.',
              )
            else ...<Widget>[
              SectionCard(
                title: activeDuty.siteName,
                subtitle:
                    '${activeDuty.district} • ${activeDuty.dutyPointName ?? 'Duty point'} • ${activeDuty.shiftLabel ?? 'Shift'}',
                icon: Icons.place_outlined,
                trailing: Text(
                  activeDuty.activeSinceLabel ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.inkMuted,
                      ),
                ),
              ),
              PortalSurfaceCard(
                accentColor: status.hourlyRequirement.dueNow
                    ? tokens.danger
                    : tokens.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    PortalSectionHeading(
                      title: 'Night Proof',
                      action: status.hourlyRequirement.enabled
                          ? Icon(
                              status.hourlyRequirement.dueNow
                                  ? Icons.alarm_on_rounded
                                  : Icons.schedule_rounded,
                              color: status.hourlyRequirement.dueNow
                                  ? tokens.danger
                                  : tokens.primary,
                            )
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      status.hourlyRequirement.enabled
                          ? (status.hourlyRequirement.dueNow
                              ? 'Hourly night check is due now'
                              : 'Next hourly check at ${_formatIsoLabel(status.hourlyRequirement.nextDueAt)}')
                          : 'Hourly night-photo checks are not required for this duty window.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: tokens.ink,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Window ${status.hourlyRequirement.nightWindowLabel}'
                      '${status.hourlyRequirement.lastSubmittedAt != null ? ' • Last submitted ${_formatIsoLabel(status.hourlyRequirement.lastSubmittedAt)}' : ''}'
                      '${status.hourlyRequirement.overdueMinutes > 0 ? ' • ${status.hourlyRequirement.overdueMinutes} min overdue' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: tokens.inkMuted,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: _submitting || !status.hourlyRequirement.enabled
                          ? null
                          : () => _submit(status, 'hourly_photo'),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Submit Hourly Photo'),
                    ),
                  ],
                ),
              ),
              PortalSurfaceCard(
                accentColor: tokens.success,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const PortalSectionHeading(title: 'Patrol Round'),
                    const SizedBox(height: AppSpacing.sm),
                    if (status.patrolPoints.isEmpty)
                      Text(
                        'No checkpoint list is configured for this duty point yet. You can still submit a general patrol proof.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: tokens.inkMuted,
                            ),
                      )
                    else
                      Column(
                        children: status.patrolPoints.map((point) {
                          final selected = point.id == _selectedPatrolPointId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                onTap: () => setState(() {
                                  _selectedPatrolPointId =
                                      selected ? null : point.id;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(
                                      color: selected
                                          ? tokens.primary
                                          : tokens.border,
                                    ),
                                    color: selected
                                        ? tokens.primarySoft
                                        : tokens.surface,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Icon(
                                        selected
                                            ? Icons.radio_button_checked_rounded
                                            : Icons.radio_button_off_rounded,
                                        color: selected
                                            ? tokens.primary
                                            : tokens.inkMuted,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              point.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(color: tokens.ink),
                                            ),
                                            if (point.description.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: AppSpacing.xxs,
                                                ),
                                                child: Text(
                                                  point.description,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: tokens.inkMuted,
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _capturePhoto,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(_photoPath == null
                          ? 'Capture proof photo'
                          : 'Retake photo'),
                    ),
                    if (_photoPath != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Image.file(
                          File(_photoPath!),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: patrolPoint == null
                            ? 'Notes (optional)'
                            : 'Notes for ${patrolPoint.name}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: tokens.danger,
                            ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _submit(status, 'patrol'),
                      icon: _submitting
                          ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                          : const Icon(Icons.route_outlined),
                      label: const Text('Submit Patrol Round'),
                    ),
                  ],
                ),
              ),
              PortalSurfaceCard(
                accentColor: tokens.warning,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const PortalSectionHeading(title: 'Recent Activity'),
                    const SizedBox(height: AppSpacing.sm),
                    if (status.recentActivities.isEmpty)
                      Text(
                        'Your recent patrol and hourly photo submissions will appear here.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: tokens.inkMuted,
                            ),
                      )
                    else
                      Column(
                        children: status.recentActivities.map((activity) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: tokens.surface,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: Border.all(color: tokens.border),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Icon(
                                    activity.type == 'hourly_photo'
                                        ? Icons.camera_alt_outlined
                                        : Icons.route_outlined,
                                    color: activity.type == 'hourly_photo'
                                        ? tokens.primary
                                        : tokens.success,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          activity.type == 'hourly_photo'
                                              ? 'Hourly photo shared'
                                              : (activity.patrolPointName ??
                                                  'Patrol round completed'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(color: tokens.ink),
                                        ),
                                        const SizedBox(height: AppSpacing.xxs),
                                        Text(
                                          '${activity.siteName}${activity.dutyPointName != null ? ' • ${activity.dutyPointName}' : ''}${activity.shiftLabel != null ? ' • ${activity.shiftLabel}' : ''}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: tokens.inkMuted,
                                              ),
                                        ),
                                        if ((activity.notes ?? '').isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: AppSpacing.xxs,
                                            ),
                                            child: Text(
                                              activity.notes!,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: tokens.inkMuted,
                                                  ),
                                            ),
                                          ),
                                        if (activity.photoUrl != null && activity.photoUrl!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(AppRadius.sm),
                                              child: Image.network(
                                                activity.photoUrl!,
                                                height: 80,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatIsoLabel(activity.activityAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: tokens.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
