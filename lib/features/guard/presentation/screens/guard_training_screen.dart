import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/models/training_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/section_card.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/glass_card.dart';
import '../../../../../app/theme/app_tokens.dart';
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
      loading: () =>
          const GuardLoadingScaffold(label: 'Loading training modules...'),
      error: (Object error, StackTrace stackTrace) => GuardErrorScaffold(
        title: 'Could not load training',
        error: error,
        onRetry: () => ref.invalidate(guardTrainingProvider),
      ),
      data: (assignments) {
        final completed = assignments
            .where((a) => a.status.toLowerCase().contains('complete') ||
                a.status.toLowerCase().contains('viewed') ||
                a.status.toLowerCase().contains('acknowledged'))
            .toList();
        final pending = assignments
            .where((a) => !completed.contains(a))
            .toList();
        final progress = assignments.isEmpty
            ? 0.0
            : completed.length / assignments.length;

        return ScreenScaffold(
          title: 'Training',
          subtitle: '${completed.length} of ${assignments.length} modules completed',
          onRefresh: () async => ref.invalidate(guardTrainingProvider),
          actions: <Widget>[
            IconButton(
              onPressed: () => ref.invalidate(guardTrainingProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          children: <Widget>[
            // ── Progress Card ──
            _buildProgressCard(tokens, progress, completed.length, assignments.length),
            const SizedBox(height: 16),

            // ── Pending Modules Section ──
            if (pending.isNotEmpty) ...[
              SectionCard(
                title: 'Pending',
                subtitle: '${pending.length} module${pending.length == 1 ? '' : 's'} awaiting acknowledgment',
                icon: Icons.pending_actions_rounded,
              ),
              ...pending.map((assignment) => _buildTrainingCard(
                context, ref, assignment, tokens, isCompleted: false,
              )),
              const SizedBox(height: 8),
            ],

            // ── Completed Modules Section ──
            if (completed.isNotEmpty) ...[
              SectionCard(
                title: 'Completed',
                subtitle: '${completed.length} module${completed.length == 1 ? '' : 's'} acknowledged',
                icon: Icons.check_circle_outline_rounded,
              ),
              ...completed.map((assignment) => _buildTrainingCard(
                context, ref, assignment, tokens, isCompleted: true,
              )),
              const SizedBox(height: 8),
            ],

            // ── Empty State ──
            if (assignments.isEmpty)
              const StateBlock(
                icon: Icons.school_rounded,
                title: 'No training assigned',
                message:
                    'New training modules and briefings will appear here when assigned by the office.',
              ),

            // ── Evaluations Section ──
            SectionCard(
              title: 'Evaluations',
              subtitle:
                  'Scores and quiz attempts are available from the Evaluations tab.',
              icon: Icons.quiz_rounded,
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressCard(
    CissThemeTokens tokens,
    double progress,
    int completed,
    int total,
  ) {
    final percentage = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tokens.accent.withValues(alpha: 0.06),
            tokens.accent.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tokens.accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, color: tokens.accent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRAINING PROGRESS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: tokens.accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      total == 0
                          ? 'No modules assigned'
                          : percentage == 100
                              ? '🎉 All modules completed!'
                              : '$percentage% complete',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: tokens.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$completed/$total',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: tokens.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: tokens.accent.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(tokens.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingCard(
    BuildContext context,
    WidgetRef ref,
    TrainingAssignmentModel assignment,
    CissThemeTokens tokens, {
    required bool isCompleted,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GuardTrainingDetailScreen(assignment: assignment),
                    ),
                  );
                },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            accentColor: isCompleted ? tokens.success : tokens.accent,
            child: Row(
              children: [
                // Left icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isCompleted ? tokens.success : tokens.accent)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_circle_rounded : Icons.assignment_rounded,
                    color: isCompleted ? tokens.success : tokens.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Center info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tokens.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 11, color: tokens.inkMuted),
                          const SizedBox(width: 4),
                          Text(
                            assignment.dueLabel.isNotEmpty
                                ? _formatDueLabel(assignment.dueLabel)
                                : 'No date',
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.inkMuted,
                            ),
                          ),
                          if (assignment.contentType != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.insert_drive_file_rounded,
                                size: 11, color: tokens.inkMuted),
                            const SizedBox(width: 4),
                            Text(
                              assignment.contentType!,
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.inkMuted,
                              ),
                            ),
                          ],
                          if (hasContent) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.open_in_new_rounded,
                                size: 11, color: tokens.accent),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Right: status chip + acknowledge button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusChip(
                      label: isCompleted ? 'Completed' : assignment.status,
                      tone: isCompleted ? StatusChipTone.success : StatusChipTone.info,
                    ),
                    if (!isCompleted) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 30,
                        child: FilledButton.tonalIcon(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(mobileRepositoryProvider)
                                  .acknowledgeTraining(assignment.id);
                              ref.invalidate(guardTrainingProvider);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.check_rounded, size: 14),
                          label: const Text('Acknowledge', style: TextStyle(fontSize: 11)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: Size.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
