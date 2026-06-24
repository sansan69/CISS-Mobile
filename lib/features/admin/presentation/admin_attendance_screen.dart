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
      subtitle: 'View attendance records',
      children: <Widget>[
        StateBlock(
          icon: Icons.construction_rounded,
          title: 'Coming Soon',
          message: 'Attendance logs will be available in the next update.',
        ),
      ],
    );
  }
}
