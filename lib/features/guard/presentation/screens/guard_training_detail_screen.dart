import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/training_models.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../widgets/guard_portal_widgets.dart';
import 'guard_training_quiz_screen.dart';

/// Builds an Office Online embed URL for viewing PPTX/DOCX in browser.
String _officeEmbedUrl(String publicUrl) {
  return 'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(publicUrl)}';
}

/// Safely formats a date string for display.
String _formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day}/${local.month}/${local.year} $hour:$minute $suffix';
}

class GuardTrainingDetailScreen extends ConsumerWidget {
  const GuardTrainingDetailScreen({super.key, required this.assignment});

  final TrainingAssignmentModel assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final isComplete =
        assignment.status.toLowerCase().contains('complete') ||
        assignment.status.toLowerCase().contains('viewed') ||
        assignment.status.toLowerCase().contains('acknowledged');
    final contentType = assignment.contentType?.toLowerCase() ?? '';
    final hasViewableContent = assignment.contentUrl != null &&
        assignment.contentUrl!.isNotEmpty;

    final bool isImage = hasViewableContent &&
        (contentType == 'image' ||
            contentType == 'jpg' ||
            contentType == 'jpeg' ||
            contentType == 'png' ||
            contentType == 'gif' ||
            assignment.contentUrl!.contains(RegExp(r'\.(jpg|jpeg|png|gif|webp)$', caseSensitive: false)));

    final bool isPdf = hasViewableContent &&
        (contentType == 'pdf' ||
            assignment.contentUrl!.contains(RegExp(r'\.pdf$', caseSensitive: false)));

    final bool isPptx = hasViewableContent &&
        (contentType == 'pptx' || contentType == 'ppt' ||
            assignment.contentUrl!.contains(RegExp(r'\.(pptx|ppt)$', caseSensitive: false)));

    final bool isOfficeDoc = hasViewableContent &&
        (isPptx ||
            contentType == 'docx' || contentType == 'doc' ||
            assignment.contentUrl!.contains(RegExp(r'\.(docx|doc|xlsx|xls)$', caseSensitive: false)));

    final bool canViewInline = isImage || isPdf || isOfficeDoc;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            GuardHeroPanel(
              eyebrow: isComplete ? 'Completed module' : 'Assigned module',
              title: assignment.title,
              subtitle: assignment.dueLabel.isEmpty
                  ? 'No due date'
                  : _formatDate(assignment.dueLabel),
              icon: isComplete
                  ? Icons.check_circle_rounded
                  : Icons.assignment_rounded,
              accentColor: isComplete ? tokens.success : tokens.accent,
              trailing: StatusChip(
                label: assignment.status,
                tone: isComplete
                    ? StatusChipTone.success
                    : StatusChipTone.warning,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: GuardMetricStrip(
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
                    label: 'Attached',
                    value: hasViewableContent ? 'Yes' : 'No',
                    icon: Icons.attach_file_rounded,
                    color: tokens.accent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: GuardFormCard(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.menu_book_rounded, color: tokens.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Training content',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: tokens.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Inline content viewer for images, PDFs, Office docs
                  if (canViewInline) ...[
                    Container(
                      width: double.infinity,
                      height: 340,
                      decoration: BoxDecoration(
                        color: tokens.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: tokens.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: isImage
                          ? _buildImageViewer(context, tokens)
                          : _buildOfficeEmbedViewer(context, tokens),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: () => _openUrl(context),
                      icon: Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text(
                        isPptx
                            ? 'Open in PowerPoint Online'
                            : isPdf
                                ? 'Open PDF'
                                : 'Open content in browser',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Fallback content button (for non-viewable content like video)
                  if (hasViewableContent && !canViewInline)
                    GuardRecordCard(
                      title: 'Open content',
                      subtitle: assignment.contentFileName ?? 'Training material',
                      icon: contentType == 'video'
                          ? Icons.play_circle_outline_rounded
                          : Icons.picture_as_pdf_outlined,
                      chip: assignment.contentType == null
                          ? null
                          : StatusChip(
                              label: assignment.contentType!,
                              tone: StatusChipTone.info,
                            ),
                      onTap: () => _openUrl(context),
                    ),

                  if (!hasViewableContent)
                    const GuardRecordCard(
                      title: 'No content file',
                      subtitle:
                          'This module does not have an attachment yet.',
                      icon: Icons.insert_drive_file_outlined,
                    ),

                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Review the material and follow the office instructions. '
                    'Completed modules are marked after acknowledgment or supervisor review.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.inkMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: GuardFormCard(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.quiz_rounded, color: tokens.accent),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Assessment',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: tokens.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Complete the quiz to verify your understanding '
                    'of this training module.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.inkMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GuardTrainingQuizScreen(
                              assignmentId: assignment.id,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.quiz_rounded),
                      label: const Text('Start Quiz'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageViewer(BuildContext context, CissThemeTokens tokens) {
    return InteractiveViewer(
      panEnabled: true,
      scaleEnabled: true,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          assignment.contentUrl!,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                    color: tokens.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Loading image...',
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.broken_image_rounded,
                    size: 48, color: tokens.danger),
                const SizedBox(height: 8),
                Text('Could not load image',
                    style: TextStyle(color: tokens.inkMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfficeEmbedViewer(
      BuildContext context, CissThemeTokens tokens) {
    if (isPdf) {
      // Render PDF as a document viewer card with open action
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.picture_as_pdf_rounded,
                size: 64, color: tokens.danger),
            const SizedBox(height: 12),
            Text(
              assignment.contentFileName ?? 'PDF Document',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openUrl(context),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open PDF'),
            ),
            const SizedBox(height: 8),
            Text(
              'PDF will open in an external viewer.',
              style: TextStyle(fontSize: 12, color: tokens.inkMuted),
            ),
          ],
        ),
      );
    }

    // Office docs (PPTX, DOCX) — show a preview card + embed link
    final label = isPptx ? 'PowerPoint' : 'Office Document';
    final icon = isPptx
        ? Icons.slideshow_rounded
        : Icons.description_rounded;
    final color = isPptx ? Colors.deepOrange : tokens.primary;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 8),
          Text(
            assignment.contentFileName ?? label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.ink,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () =>
                _openUrl(context, office: true),
            icon: const Icon(Icons.open_in_browser_rounded, size: 18),
            label: Text('View in Office Online'),
          ),
          const SizedBox(height: 8),
          Text(
            'Opens in Microsoft Office Viewer.',
            style: TextStyle(fontSize: 12, color: tokens.inkMuted),
          ),
        ],
      ),
    );
  }

  bool get isPdf =>
      assignment.contentType?.toLowerCase() == 'pdf' ||
      (assignment.contentUrl?.contains(RegExp(r'\.pdf$', caseSensitive: false)) ?? false);

  bool get isPptx =>
      assignment.contentType?.toLowerCase() == 'pptx' ||
      assignment.contentType?.toLowerCase() == 'ppt' ||
      (assignment.contentUrl?.contains(RegExp(r'\.(pptx|ppt)$', caseSensitive: false)) ?? false);

  bool get isImage {
    final ct = assignment.contentType?.toLowerCase() ?? '';
    if (ct == 'image' || ct == 'jpg' || ct == 'jpeg' || ct == 'png' || ct == 'gif') return true;
    return assignment.contentUrl?.contains(RegExp(r'\.(jpg|jpeg|png|gif|webp)$', caseSensitive: false)) ?? false;
  }

  Future<void> _openUrl(BuildContext context, {bool office = false}) async {
    final url = office && isPptx
        ? _officeEmbedUrl(assignment.contentUrl!)
        : assignment.contentUrl!;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open content')),
      );
    }
  }
}
