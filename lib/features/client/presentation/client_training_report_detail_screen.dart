import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

class ClientTrainingReportDetailScreen extends StatelessWidget {
  const ClientTrainingReportDetailScreen({
    super.key,
    required this.report,
  });

  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    final topic = report['topic']?.toString() ?? 'Training';
    final trainingDate = report['trainingDate']?.toString() ??
        report['visitDate']?.toString() ??
        '';
    final officer = report['fieldOfficerName']?.toString() ?? '-';
    final status = report['status']?.toString() ?? 'submitted';
    final description = report['description']?.toString() ?? '';
    final duration = report['duration']?.toString() ?? '';
    final attendeeCount = (report['attendeeCount'] as num?)?.toInt() ?? 0;
    final siteName = report['siteName']?.toString() ?? '';
    final district = report['district']?.toString() ?? '';
    final photos = report['photos'] as List<dynamic>? ?? const <dynamic>[];
    final attachments = report['attachments'] as List<dynamic>? ??
        const <dynamic>[];

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Training Report'),
        backgroundColor: tokens.canvas,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ModernHero(
            eyebrow: siteName.isNotEmpty ? siteName : district,
            title: topic,
            subtitle: '${_formatDate(trainingDate)} \u2022 $officer',
            trailing: StatusChip(
              label: status,
              tone: StatusChipTone.info,
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader('REPORT DETAILS', tokens),
          const SizedBox(height: 12),
          ModernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: tokens.ink,
                    ),
                  ),
                if (description.isNotEmpty) const SizedBox(height: 16),
                Row(
                  children: [
                    _infoChip(
                      Icons.timer_rounded,
                      duration.isNotEmpty ? duration : '\u2014',
                      tokens,
                    ),
                    const SizedBox(width: 12),
                    _infoChip(
                      Icons.groups_rounded,
                      '$attendeeCount attendee${attendeeCount == 1 ? '' : 's'}',
                      tokens,
                    ),
                    if (siteName.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      _infoChip(
                        Icons.location_on_rounded,
                        siteName,
                        tokens,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionHeader('PHOTOS', tokens),
            const SizedBox(height: 12),
            _PhotoGallery(photos: photos),
          ],
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionHeader('ATTACHMENTS', tokens),
            const SizedBox(height: 12),
            ModernCard(
              child: Column(
                children: _buildAttachmentList(attachments, tokens),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text, CissThemeTokens tokens) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: tokens.inkMuted,
        letterSpacing: 2,
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, CissThemeTokens tokens) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: tokens.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: tokens.primary),
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAttachmentList(
      List<dynamic> attachments, CissThemeTokens tokens) {
    final items = <Widget>[];
    for (var i = 0; i < attachments.length; i++) {
      final att = attachments[i];
      if (att is! Map) continue;
      final name = att['name']?.toString() ?? att['fileName']?.toString() ?? 'File';
      final url = att['url']?.toString() ?? att['downloadUrl']?.toString() ?? '';
      final hasUrl = url.isNotEmpty;

      if (i > 0) {
        items.add(
          Divider(height: 1, color: tokens.border.withValues(alpha: 0.3)),
        );
      }

      items.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            _iconForFile(name),
            color: tokens.primary,
          ),
          title: Text(
            name,
            style: const TextStyle(fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: hasUrl
              ? Text(
                  'Tap to download',
                  style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                )
              : Text(
                  'No download link',
                  style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                ),
          trailing: Icon(
            hasUrl ? Icons.download_rounded : Icons.block_rounded,
            color: hasUrl ? tokens.primary : tokens.inkMuted,
            size: 20,
          ),
          onTap: hasUrl ? () => _downloadAttachment(url, name) : null,
        ),
      );
    }
    return items;
  }

  IconData _iconForFile(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description_rounded;
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return Icons.table_chart_rounded;
    }
    return Icons.attach_file_rounded;
  }

  Future<void> _downloadAttachment(String url, String name) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatDate(String value) {
    if (value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _PhotoGallery extends StatelessWidget {
  const _PhotoGallery({required this.photos});

  final List<dynamic> photos;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final validUrls =
        photos.whereType<String>().where((u) => u.isNotEmpty).toList();

    if (validUrls.isEmpty) {
      return StateBlock(
        icon: Icons.photo_library_rounded,
        title: 'No photos',
        message: 'No photos were attached to this report.',
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: validUrls.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _openFullImage(context, validUrls[index], tokens),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.network(
              validUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: tokens.surfaceMuted,
                child: Icon(
                  Icons.broken_image_rounded,
                  color: tokens.inkMuted,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openFullImage(
      BuildContext context, String url, CissThemeTokens tokens) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: tokens.canvas,
          appBar: AppBar(
            backgroundColor: tokens.canvas,
            iconTheme: IconThemeData(color: tokens.ink),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.broken_image_rounded,
                  size: 64,
                  color: tokens.inkMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
