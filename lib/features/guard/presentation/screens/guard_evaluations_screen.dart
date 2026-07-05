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
              (evaluation) => GuardRecordCard(
                title: evaluation.title,
                subtitle:
                    '${evaluation.status} • Score ${evaluation.scoreLabel}',
                icon: Icons.quiz_rounded,
                chip: StatusChip(
                  label: evaluation.scoreLabel,
                  tone: StatusChipTone.info,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
