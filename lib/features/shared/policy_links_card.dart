import '../../core/i18n/app_strings.dart';
import 'package:flutter/material.dart';
import 'policy_webview_screen.dart';

class PolicyLinksCard extends StatelessWidget {
  const PolicyLinksCard({super.key});
  static const _links = {
    'policyPrivacy': String.fromEnvironment('CISS_PRIVACY_URL'),
    'policyTerms': String.fromEnvironment('CISS_TERMS_URL'),
    'policyPsara': String.fromEnvironment('CISS_PSARA_URL'),
  };
  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final links =
        _links.entries.where((entry) {
          final uri = Uri.tryParse(entry.value);
          return uri?.scheme == 'https' &&
              uri!.host.isNotEmpty &&
              uri.userInfo.isEmpty;
        }).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.label('policies'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (links.isEmpty) Text(strings.label('policyNotConfigured')),
            for (final link in links)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.label(link.key)),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => PolicyWebViewScreen(
                              title: strings.label(link.key),
                              url: link.value,
                            ),
                      ),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
