import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_tokens.dart';

/// Document tile with name, type indicator, and download action.
class DocumentListTile extends StatelessWidget {
  const DocumentListTile({
    super.key,
    required this.name,
    this.url,
    this.fileType,
    this.fileSize,
    this.onDownload,
    this.onTap,
  });

  final String name;
  final String? url;
  final String? fileType;
  final String? fileSize;
  final VoidCallback? onDownload;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    IconData icon;
    Color iconColor;

    switch (fileType?.toLowerCase()) {
      case 'pdf':
        icon = Icons.picture_as_pdf_rounded;
        iconColor = tokens.danger;
        break;
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
        icon = Icons.image_rounded;
        iconColor = tokens.success;
        break;
      case 'spreadsheet':
      case 'xls':
      case 'xlsx':
        icon = Icons.table_chart_rounded;
        iconColor = tokens.success;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.article_rounded;
        iconColor = tokens.primary;
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
        iconColor = tokens.inkMuted;
    }

    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: () {
          if (url != null && url!.isNotEmpty) {
            launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication);
          }
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tokens.ink,
                      ),
                    ),
                    if (fileSize != null && fileSize!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        fileSize!,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (url != null && url!.isNotEmpty)
                IconButton(
                  onPressed: () {
                    launchUrl(
                      Uri.parse(url!),
                      mode: LaunchMode.externalApplication,
                    );
                    onDownload?.call();
                  },
                  icon: Icon(Icons.download_rounded,
                      color: tokens.primary, size: 22),
                  tooltip: 'Download',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
