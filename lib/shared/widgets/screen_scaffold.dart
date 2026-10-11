import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/haptics.dart';
import 'brand_banner.dart';

/// Universal screen scaffold for CISS Workforce.
///
/// Provides a consistent AppBar with company branding (logo + name) and screen
/// title. Every screen in the app — guard tabs, FO tabs, login pages, detail
/// screens — uses this widget to guarantee identical header appearance.
///
/// [title] is the primary screen heading shown in the AppBar.
/// [subtitle] appears below the title in a smaller muted style.
/// [children] are rendered in a scrollable body.
/// [actions] are placed in the AppBar's trailing slot.
/// [showBackButton] when true, the AppBar shows a back arrow. Defaults to false.
/// [onBack] overrides the default back behavior (defaults to [Navigator.pop]).
/// [onRefresh] when provided, enables pull-to-refresh with haptic feedback.
/// [scrollController] for programmatic scroll control (e.g. scroll-to-top).
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions = const <Widget>[],
    this.showBackButton = true,
    this.onBack,
    this.onRefresh,
    this.scrollController,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Future<void> Function()? onRefresh;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    final Widget body = ListView.separated(
      controller: scrollController,
      primary: scrollController == null,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        84 + MediaQuery.of(context).padding.bottom,
      ),
      itemBuilder: (BuildContext context, int index) => children[index],
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemCount: children.length,
    );

    return Scaffold(
      appBar: CissAppBar(
        title: title,
        subtitle: subtitle,
        actions: actions,
        showBackButton: showBackButton,
        onBack: onBack,
      ),
      body:
          onRefresh != null
              ? RefreshIndicator(
                onRefresh: () async {
                  Haptics.medium();
                  await onRefresh!();
                },
                color: tokens.primary,
                backgroundColor: tokens.surface,
                child: body,
              )
              : body,
    );
  }
}
