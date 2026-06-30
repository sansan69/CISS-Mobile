import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../shared/widgets/state_block.dart';

class AdminGuardsScreen extends ConsumerWidget {
  const AdminGuardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);

    return ScreenScaffold(
      title: 'Guards',
      subtitle: 'Manage guard profiles',
      children: <Widget>[
        StateBlock(
          icon: Icons.group,
          title: 'Guard Management',
          message: 'Open the web dashboard for full guard CRUD, bulk import, QR generation, and profile editing.',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w600, color: tokens.ink)),
            const SizedBox(height: 12),
            _actionTile(tokens, Icons.add_circle_outline, 'Add Employee', 'Use the web dashboard to enroll new guards'),
            _actionTile(tokens, Icons.download, 'Bulk Import', 'Upload Excel files to import multiple guards'),
            _actionTile(tokens, Icons.qr_code, 'QR Codes', 'Generate and print guard QR identification cards'),
          ]),
        ),
      ],
    );
  }

  Widget _actionTile(CissThemeTokens tokens, IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 20, color: tokens.primary),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: tokens.ink)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: tokens.inkMuted)),
        ])),
      ]),
    );
  }
}
