import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../shared/widgets/state_block.dart';

class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);

    return ScreenScaffold(
      title: 'Work Orders',
      subtitle: 'Manage duty assignments',
      children: <Widget>[
        StateBlock(
          icon: Icons.assignment,
          title: 'Work Orders',
          message: 'Full work order management is available on the web dashboard with import, assignment, and export features.',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Capabilities', style: TextStyle(fontWeight: FontWeight.w600, color: tokens.ink)),
            const SizedBox(height: 12),
            _capability(tokens, Icons.upload_file, 'Import work orders from Excel spreadsheets'),
            _capability(tokens, Icons.people, 'Assign guards with gender breakdown'),
            _capability(tokens, Icons.map, 'View duties by site on interactive map'),
            _capability(tokens, Icons.edit_note, 'Edit manpower requirements per duty'),
            _capability(tokens, Icons.download, 'Export assigned guard list to Excel'),
          ]),
        ),
      ],
    );
  }

  Widget _capability(CissThemeTokens tokens, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: tokens.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: tokens.ink))),
      ]),
    );
  }
}
