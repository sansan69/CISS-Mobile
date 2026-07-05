import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/training_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../widgets/guard_portal_widgets.dart';

final FutureProvider<List<EvaluationModel>> guardEvaluationsProvider =
    FutureProvider<List<EvaluationModel>>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchEvaluations();
    });

class GuardEvaluationsScreen extends ConsumerWidget {
  const GuardEvaluationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final evaluationsAsync = ref.watch(guardEvaluationsProvider);
    return evaluationsAsync.when(
      loading:
          () => const GuardLoadingScaffold(label: 'Loading evaluations...'),
      error:
          (Object error, StackTrace stackTrace) => GuardErrorScaffold(
            title: 'Could not load evaluations',
            error: error,
            onRetry: () => ref.invalidate(guardEvaluationsProvider),
          ),
      data: (evaluations) {
        return ScreenScaffold(
          title: 'Evaluations',
          subtitle: 'Quiz and performance records',
          onRefresh: () async => ref.invalidate(guardEvaluationsProvider),
          actions: <Widget>[
            IconButton(
              onPressed: () => ref.invalidate(guardEvaluationsProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          children: <Widget>[
            GuardHeroPanel(
              eyebrow: 'Performance',
              title:
                  '${evaluations.length} evaluation${evaluations.length == 1 ? '' : 's'}',
              subtitle:
                  evaluations.isEmpty
                      ? 'Quiz and performance results will appear here.'
                      : 'Review your latest published records.',
              icon: Icons.workspace_premium_rounded,
              accentColor: tokens.warning,
            ),
            const SizedBox(height: AppSpacing.lg),
            GuardMetricStrip(
              items: <GuardMetricItem>[
                GuardMetricItem(
                  label: 'Records',
                  value: '${evaluations.length}',
                  icon: Icons.assignment_turned_in_rounded,
                  color: tokens.primary,
                ),
                GuardMetricItem(
                  label: 'Latest',
                  value:
                      evaluations.isEmpty ? '-' : evaluations.first.scoreLabel,
                  icon: Icons.stars_rounded,
                  color: tokens.warning,
                ),
                GuardMetricItem(
                  label: 'Status',
                  value: evaluations.isEmpty ? '-' : evaluations.first.status,
                  icon: Icons.verified_rounded,
                  color: tokens.success,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (evaluations.isEmpty)
              const StateBlock(
                icon: Icons.workspace_premium_rounded,
                title: 'No evaluations yet',
                message:
                    'Performance evaluations and quiz scores will be listed here once published.',
              ),
            ...evaluations.map(
              (evaluation) => _EvaluationCard(
                evaluation: evaluation,
                tokens: tokens,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EvaluationCard extends StatefulWidget {
  const _EvaluationCard({required this.evaluation, required this.tokens});

  final EvaluationModel evaluation;
  final CissThemeTokens tokens;

  @override
  State<_EvaluationCard> createState() => _EvaluationCardState();
}

class _EvaluationCardState extends State<_EvaluationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.evaluation;
    final t = widget.tokens;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.border.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.quiz_rounded, color: t.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${e.status} \u2022 Score ${e.scoreLabel}',
                          style: TextStyle(
                            fontSize: 12,
                            color: t.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: e.scoreLabel,
                    tone: StatusChipTone.info,
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more_rounded, color: t.inkMuted),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 16),
                Divider(height: 1, color: t.border.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                _criteriaRow('Punctuality', e.punctualityScore, t),
                _criteriaRow('Uniform', e.uniformScore, t),
                _criteriaRow('Behavior', e.behaviorScore, t),
                _criteriaRow('Skill', e.skillScore, t),
                _criteriaRow('Client Feedback', e.clientFeedbackScore, t),
                if (e.comments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: t.inkMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e.comments,
                    style: TextStyle(
                      fontSize: 13,
                      color: t.ink,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _criteriaRow(String label, double score, CissThemeTokens t) {
    final normalized = score.clamp(0, 10);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: t.inkMuted),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: normalized / 10,
                minHeight: 8,
                backgroundColor: t.border.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  normalized >= 7
                      ? t.success
                      : normalized >= 4
                          ? t.warning
                          : t.danger,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '${normalized.toStringAsFixed(0)}/10',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.ink,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
