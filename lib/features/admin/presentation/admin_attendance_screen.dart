import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../shared/widgets/state_block.dart';

class AdminAttendanceScreen extends ConsumerWidget {
  const AdminAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);

    return ScreenScaffold(
      title: 'Attendance',
      subtitle: 'Monitor guard attendance',
      children: <Widget>[
        StateBlock(
          icon: Icons.checklist,
          title: 'Attendance Overview',
          message: 'Real-time attendance monitoring is available on the web dashboard with live maps, filters, and export.',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Available Features', style: TextStyle(fontWeight: FontWeight.w600, color: tokens.ink)),
            const SizedBox(height: 12),
            _feature(tokens, Icons.map, 'Live guard locations on interactive map'),
            _feature(tokens, Icons.filter_alt, 'Filter by district, site, client, date'),
            _feature(tokens, Icons.download, 'Export attendance logs to Excel'),
            _feature(tokens, Icons.photo_library, 'Photo compliance review with AI analysis'),
            _feature(tokens, Icons.warning_amber, 'Mock location detection alerts'),
          ]),
        ),
      ],
    );
  }

  Widget _feature(CissThemeTokens tokens, IconData icon, String text) {
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
