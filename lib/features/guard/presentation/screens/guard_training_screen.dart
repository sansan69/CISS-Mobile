import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/training_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../widgets/guard_portal_widgets.dart';
import 'guard_training_detail_screen.dart';

String _formatDueLabel(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day}/${local.month}/${local.year} $hour:$minute $suffix';
}

final FutureProvider<List<TrainingAssignmentModel>> guardTrainingProvider =
    FutureProvider<List<TrainingAssignmentModel>>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchTrainingAssignments();
    });

class GuardTrainingScreen extends ConsumerWidget {
  const GuardTrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final assignmentsAsync = ref.watch(guardTrainingProvider);

    return assignmentsAsync.when(
      loading:
          () =>
              const GuardLoadingScaffold(label: 'Loading training modules...'),
      error:
          (Object error, StackTrace stackTrace) => GuardErrorScaffold(
            title: 'Could not load training',
            error: error,
            onRetry: () => ref.invalidate(guardTrainingProvider),
          ),
      data: (assignments) {
        final completed =
            assignments
                .where(
                  (assignment) =>
                      assignment.status.toLowerCase().contains('complete') ||
                      assignment.status.toLowerCase().contains('viewed') ||
                      assignment.status.toLowerCase().contains('acknowledged'),
                )
                .toList();
        final pending =
            assignments
                .where((assignment) => !completed.contains(assignment))
                .toList();
        final progress =
            assignments.isEmpty ? 0.0 : completed.length / assignments.length;
        final percentage = (progress * 100).round();

        return ScreenScaffold(
          title: 'Training',
          subtitle: '${completed.length} of ${assignments.length} completed',
          onRefresh: () async => ref.invalidate(guardTrainingProvider),
          actions: <Widget>[
            IconButton(
              onPressed: () => ref.invalidate(guardTrainingProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          children: <Widget>[
            GuardHeroPanel(
              eyebrow: 'Training centre',
              title:
                  assignments.isEmpty
                      ? 'No modules assigned'
                      : '$percentage% complete',
              subtitle:
                  assignments.isEmpty
                      ? 'New briefings and quizzes will appear here.'
                      : '${pending.length} pending • ${completed.length} completed',
              icon: Icons.school_rounded,
              accentColor: tokens.accent,
            ),
            const SizedBox(height: AppSpacing.lg),
            GuardMetricStrip(
              items: <GuardMetricItem>[
                GuardMetricItem(
                  label: 'Total',
                  value: '${assignments.length}',
                  icon: Icons.library_books_rounded,
                  color: tokens.primary,
                ),
                GuardMetricItem(
                  label: 'Pending',
                  value: '${pending.length}',
                  icon: Icons.pending_actions_rounded,
                  color: tokens.warning,
                ),
                GuardMetricItem(
                  label: 'Done',
                  value: '${completed.length}',
                  icon: Icons.check_circle_rounded,
                  color: tokens.success,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _ProgressCard(progress: progress, percentage: percentage),
            const SizedBox(height: AppSpacing.lg),
            if (assignments.isEmpty)
              const StateBlock(
                icon: Icons.school_rounded,
                title: 'No training assigned',
                message:
                    'New training modules and briefings will appear here when assigned by the office.',
              ),
            if (pending.isNotEmpty) ...<Widget>[
              const _ListHeader(title: 'Pending modules'),
              const SizedBox(height: AppSpacing.sm),
              ...pending.map(
                (assignment) => _TrainingRecordCard(
                  assignment: assignment,
                  isCompleted: false,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (completed.isNotEmpty) ...<Widget>[
              const _ListHeader(title: 'Completed modules'),
              const SizedBox(height: AppSpacing.sm),
              ...completed.map(
                (assignment) => _TrainingRecordCard(
                  assignment: assignment,
                  isCompleted: true,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        );
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress, required this.percentage});

  final double progress;
  final int percentage;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return GuardFormCard(
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.trending_up_rounded, color: tokens.accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                percentage == 100
                    ? 'All modules completed'
                    : '$percentage% complete',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: tokens.accent.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
          ),
        ),
      ],
    );
  }
}

class _TrainingRecordCard extends ConsumerWidget {
  const _TrainingRecordCard({
    required this.assignment,
    required this.isCompleted,
  });

  final TrainingAssignmentModel assignment;
  final bool isCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusLabel = isCompleted ? 'Completed' : assignment.status;
    final due =
        assignment.dueLabel.isNotEmpty
            ? _formatDueLabel(assignment.dueLabel)
            : 'No due date';

    return GuardRecordCard(
      title: assignment.title,
      subtitle: '${assignment.contentType ?? 'Training'} • $due',
      icon: isCompleted ? Icons.check_circle_rounded : Icons.assignment_rounded,
      chip: StatusChip(
        label: statusLabel,
        tone: isCompleted ? StatusChipTone.success : StatusChipTone.info,
      ),
      trailing:
          isCompleted
              ? null
              : IconButton(
                tooltip: 'Acknowledge',
                icon: const Icon(Icons.done_rounded),
                onPressed: () async {
                  try {
                    await ref
                        .read(mobileRepositoryProvider)
                        .acknowledgeTraining(assignment.id);
                    ref.invalidate(guardTrainingProvider);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $error')));
                    }
                  }
                },
              ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GuardTrainingDetailScreen(assignment: assignment),
          ),
        );
      },
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: tokens.ink,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
