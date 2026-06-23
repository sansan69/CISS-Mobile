import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/training_models.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/glass_card.dart';
import '../../../../../shared/widgets/status_chip.dart';

/// Training assignment detail screen.
/// Shows full assignment info and provides content viewing + acknowledgment.
///
/// Mirrors web app's /guard/training/quiz/[assignmentId] flow in a simplified
/// mobile format.
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
    final isComplete = assignment.status.toLowerCase().contains('complete') ||
        assignment.status.toLowerCase().contains('viewed') ||
        assignment.status.toLowerCase().contains('acknowledged');

    return ScreenScaffold(
      title: assignment.title,
      subtitle: isComplete ? 'Completed' : 'Pending acknowledgment',
      children: [
        // Status and dates
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusChip(
                      label: assignment.status,
                      tone: isComplete ? StatusChipTone.success : StatusChipTone.warning,
                    ),
                    const Spacer(),
                    if (assignment.contentType != null)
                      StatusChip(
                        label: assignment.contentType!,
                        tone: StatusChipTone.info,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoRow(label: 'Assigned', value: _formatDate(assignment.dueLabel)),
                if (assignment.contentFileName != null)
                  _InfoRow(label: 'File', value: assignment.contentFileName!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Content section
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Text('Training Content',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: tokens.ink)),
              ),
              if (assignment.contentUrl != null && assignment.contentUrl!.isNotEmpty) ...[
                ListTile(
                  leading: Icon(
                    assignment.contentType == 'video'
                        ? Icons.play_circle_outline
                        : Icons.picture_as_pdf_outlined,
                    color: tokens.primary,
                  ),
                  title: Text('Open Content',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(assignment.contentFileName ?? 'Training material'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
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
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'No content file available for this module.',
                    style: TextStyle(fontSize: 13, color: tokens.inkMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Instructions
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: tokens.primary),
                    const SizedBox(width: 8),
                    Text('Instructions',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: tokens.ink)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Review the training content above. '
                  'Once you\'ve completed the module, it will be marked as acknowledged '
                  'automatically or by your supervisor.',
                  style: TextStyle(fontSize: 13, color: tokens.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: tokens.inkMuted)),
          Flexible(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
