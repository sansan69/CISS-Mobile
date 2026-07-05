import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/training_models.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../widgets/guard_portal_widgets.dart';

class GuardTrainingDetailScreen extends ConsumerWidget {
  const GuardTrainingDetailScreen({super.key, required this.assignment});

  final TrainingAssignmentModel assignment;

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year} $hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final isComplete =
        assignment.status.toLowerCase().contains('complete') ||
        assignment.status.toLowerCase().contains('viewed') ||
        assignment.status.toLowerCase().contains('acknowledged');

    return ScreenScaffold(
      title: 'Training detail',
      subtitle: isComplete ? 'Completed' : 'Pending acknowledgment',
      children: <Widget>[
        GuardHeroPanel(
          eyebrow: isComplete ? 'Completed module' : 'Assigned module',
          title: assignment.title,
          subtitle:
              assignment.dueLabel.isEmpty
                  ? 'No due date'
                  : _formatDate(assignment.dueLabel),
          icon:
              isComplete
                  ? Icons.check_circle_rounded
                  : Icons.assignment_rounded,
          accentColor: isComplete ? tokens.success : tokens.accent,
          trailing: StatusChip(
            label: assignment.status,
            tone: isComplete ? StatusChipTone.success : StatusChipTone.warning,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        GuardMetricStrip(
          items: <GuardMetricItem>[
            GuardMetricItem(
              label: 'Status',
              value: isComplete ? 'Done' : 'Pending',
              icon: Icons.verified_rounded,
              color: isComplete ? tokens.success : tokens.warning,
            ),
            GuardMetricItem(
              label: 'Type',
              value: assignment.contentType ?? 'Module',
              icon: Icons.insert_drive_file_rounded,
              color: tokens.primary,
            ),
            GuardMetricItem(
              label: 'File',
              value: assignment.contentFileName == null ? 'No' : 'Yes',
              icon: Icons.attach_file_rounded,
              color: tokens.accent,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GuardFormCard(
          children: <Widget>[
            Text(
              'Training content',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: tokens.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (assignment.contentUrl != null &&
                assignment.contentUrl!.isNotEmpty)
              GuardRecordCard(
                title: 'Open content',
                subtitle: assignment.contentFileName ?? 'Training material',
                icon:
                    assignment.contentType == 'video'
                        ? Icons.play_circle_outline_rounded
                        : Icons.picture_as_pdf_outlined,
                chip:
                    assignment.contentType == null
                        ? null
                        : StatusChip(
                          label: assignment.contentType!,
                          tone: StatusChipTone.info,
                        ),
                onTap: () async {
                  final uri = Uri.tryParse(assignment.contentUrl!);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open content')),
                    );
                  }
                },
              )
            else
              const GuardRecordCard(
                title: 'No content file',
                subtitle: 'This module does not have an attachment yet.',
                icon: Icons.insert_drive_file_outlined,
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Review the material and follow the office instructions. Completed modules are marked after acknowledgment or supervisor review.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.inkMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
