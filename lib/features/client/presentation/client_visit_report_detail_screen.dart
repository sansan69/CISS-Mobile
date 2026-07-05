import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

class ClientVisitReportDetailScreen extends StatelessWidget {
  const ClientVisitReportDetailScreen({
    super.key,
    required this.report,
  });

  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    final siteName = report['siteName']?.toString() ?? 'Site';
    final visitDate = report['visitDate']?.toString() ?? '';
    final officer = report['fieldOfficerName']?.toString() ?? '-';
    final status = report['status']?.toString() ?? 'submitted';
    final summary = report['summary']?.toString() ?? '';
    final guardsPresent = (report['guardsPresent'] as num?)?.toInt() ?? 0;
    final guardsAbsent = (report['guardsAbsent'] as num?)?.toInt() ?? 0;
    final issuesFound = (report['issuesFound'] as num?)?.toInt() ?? 0;
    final actionsRequired = report['actionsRequired']?.toString() ?? '';
    final district = report['district']?.toString() ?? '';
    final latitude = (report['latitude'] as num?)?.toDouble();
    final longitude = (report['longitude'] as num?)?.toDouble();
    final photos = report['photos'] as List<dynamic>? ?? const <dynamic>[];

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Visit Report'),
        backgroundColor: tokens.canvas,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ModernHero(
            eyebrow: district.isNotEmpty ? district : siteName,
            title: siteName,
            subtitle: '${_formatDate(visitDate)} \u2022 $officer',
            trailing: StatusChip(
              label: status,
              tone: status == 'submitted'
                  ? StatusChipTone.info
                  : StatusChipTone.success,
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader('REPORT DETAILS', tokens),
          const SizedBox(height: 12),
          ModernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary.isNotEmpty)
                  Text(
                    summary,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: tokens.ink,
                    ),
                  ),
                if (summary.isNotEmpty) const SizedBox(height: 16),
                Row(
                  children: [
                    _countBlock(
                      'Present',
                      guardsPresent,
                      tokens.success,
                      tokens.successSoft,
                      tokens,
                    ),
                    const SizedBox(width: 12),
                    _countBlock(
                      'Absent',
                      guardsAbsent,
                      tokens.danger,
                      tokens.dangerSoft,
                      tokens,
                    ),
                    const SizedBox(width: 12),
                    _countBlock(
                      'Issues',
                      issuesFound,
                      tokens.warning,
                      tokens.warningSoft,
                      tokens,
                    ),
                  ],
                ),
                if (actionsRequired.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: tokens.border.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Actions Required',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.inkMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    actionsRequired,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: tokens.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionHeader('PHOTOS', tokens),
            const SizedBox(height: 12),
            _PhotoGallery(photos: photos),
          ],
          if (latitude != null && longitude != null) ...[
            const SizedBox(height: 24),
            _sectionHeader('LOCATION', tokens),
            const SizedBox(height: 12),
            ModernCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.location_on_rounded,
                  color: tokens.primary,
                ),
                title: Text(
                  '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                ),
                subtitle: Text(
                  'GPS coordinates at time of visit',
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.inkMuted,
                  ),
                ),
                trailing: Icon(
                  Icons.open_in_new_rounded,
                  color: tokens.primary,
                  size: 20,
                ),
                onTap: () => _openMap(latitude, longitude, context),
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

  Widget _countBlock(
    String label,
    int count,
    Color accent,
    Color background,
    CissThemeTokens tokens,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMap(double lat, double lng, BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open map')),
      );
    }
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
