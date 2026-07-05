import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/haptics.dart';
import '../../features/auth/application/auth_controller.dart';

class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);

    return IconButton(
      tooltip: 'Account',
      icon: const Icon(Icons.more_vert_rounded),
      color: tokens.ink,
      onPressed: () {
        Haptics.selection();
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (BuildContext sheetContext) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ListTile(
                      leading: Icon(Icons.logout_rounded, color: tokens.danger),
                      title: Text(
                        'Sign out',
                        style: TextStyle(
                          color: tokens.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text('Return to the login screen'),
                      onTap: () async {
                        Haptics.heavy();
                        Navigator.of(sheetContext).pop();
                        await ref.read(authControllerProvider).signOut();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
