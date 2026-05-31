import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/brand.dart';

class CompanyContactCard extends StatelessWidget {
  const CompanyContactCard({
    super.key,
    this.title = 'Support',
    this.subtitle = 'Help with attendance or access.',
  });

  final String title;
  final String subtitle;

  Future<void> _openUrl(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: tokens.primaryStrong,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.inkMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openUrl(Uri.parse('mailto:$kCompanySupportEmail')),
                  icon: const Icon(Icons.email_rounded, size: 18),
                  label: const Text('Email support'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openUrl(Uri.parse(kCompanyPortalUrl)),
                  icon: const Icon(Icons.language_rounded, size: 18),
                  label: const Text('Open portal'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
