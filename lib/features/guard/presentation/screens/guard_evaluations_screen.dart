import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/models/training_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/section_card.dart';
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
    final evaluationsAsync = ref.watch(guardEvaluationsProvider);
    return evaluationsAsync.when(
      loading: () =>
          const GuardLoadingScaffold(label: 'Loading evaluations...'),
      error: (Object error, StackTrace stackTrace) => GuardErrorScaffold(
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
            SectionCard(
              title: 'Assigned Evaluations',
              subtitle:
                  '${evaluations.length} record${evaluations.length == 1 ? '' : 's'}',
              icon: Icons.workspace_premium_outlined,
            ),
            if (evaluations.isEmpty)
              const StateBlock(
                icon: Icons.workspace_premium_outlined,
                title: 'No evaluations yet',
                message:
                    'Performance evaluations and quiz scores will be listed here once published.',
              ),
            ...evaluations.map(
              (evaluation) => GuardRecordCard(
                title: evaluation.title,
                subtitle:
                    '${evaluation.status} • Score ${evaluation.scoreLabel}',
                icon: Icons.quiz_outlined,
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
