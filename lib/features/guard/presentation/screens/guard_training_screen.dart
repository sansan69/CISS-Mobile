import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/models/training_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/section_card.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../widgets/guard_portal_widgets.dart';

final FutureProvider<List<TrainingAssignmentModel>> guardTrainingProvider =
    FutureProvider<List<TrainingAssignmentModel>>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchTrainingAssignments();
    });

class GuardTrainingScreen extends ConsumerWidget {
  const GuardTrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        return ScreenScaffold(
          title: 'Training',
          subtitle: 'Assigned modules and evaluations',
          onRefresh: () async => ref.invalidate(guardTrainingProvider),
          actions: <Widget>[
            IconButton(
              onPressed: () => ref.invalidate(guardTrainingProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          children: <Widget>[
            SectionCard(
              title: 'Assigned Modules',
              subtitle:
                  '${assignments.length} module${assignments.length == 1 ? '' : 's'} assigned',
              icon: Icons.menu_book_rounded,
            ),
            if (assignments.isEmpty)
              const StateBlock(
                icon: Icons.school_rounded,
                title: 'No training assigned',
                message:
                    'New training modules and briefings will appear here when assigned by the office.',
              ),
            ...assignments.map(
              (assignment) {
                final bool isCompleted = assignment.status.toLowerCase().contains('complete') || 
                                       assignment.status.toLowerCase().contains('viewed');
                return GuardRecordCard(
                  title: assignment.title,
                  subtitle: assignment.contentFileName != null
                      ? '${assignment.status} • ${assignment.contentFileName}'
                      : assignment.contentType != null
                      ? '${assignment.status} • ${assignment.contentType}'
                      : assignment.status,
                  icon: Icons.assignment_rounded,
                  chip: StatusChip(
                    label: assignment.status,
                    tone: isCompleted
                        ? StatusChipTone.success
                        : StatusChipTone.info,
                  ),
                  trailing: isCompleted 
                      ? null 
                      : IconButton(
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          tooltip: 'Acknowledge',
                          onPressed: () async {
                            try {
                              await ref.read(mobileRepositoryProvider).acknowledgeTraining(assignment.id);
                              ref.invalidate(guardTrainingProvider);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                        ),
                  onTap:
                      assignment.contentUrl == null ||
                          assignment.contentUrl!.isEmpty
                      ? null
                      : () async {
                          final uri = Uri.tryParse(assignment.contentUrl!);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                );
              },
            ),
            const SizedBox(height: 4),
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
}
