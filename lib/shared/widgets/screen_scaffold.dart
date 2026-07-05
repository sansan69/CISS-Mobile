import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/brand.dart';
import '../../core/haptics.dart';

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
    this.showBackButton = false,
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

  static const double _toolbarBase = 72.0;
  static const double _toolbarWithSub = 84.0;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final double toolbarHeight =
        subtitle == null ? _toolbarBase : _toolbarWithSub;

    final Widget body = ListView.separated(
      controller: scrollController,
      primary: scrollController == null,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl + MediaQuery.of(context).padding.bottom,
      ),
      itemBuilder: (BuildContext context, int index) => children[index],
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemCount: children.length,
    );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(toolbarHeight),
        child: AppBar(
          automaticallyImplyLeading: false,
          leading:
              showBackButton
                  ? IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                    ),
                    onPressed: onBack ?? () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(foregroundColor: tokens.ink),
                  )
                  : null,
          titleSpacing: 0,
          toolbarHeight: toolbarHeight,
          title: Padding(
            padding: EdgeInsets.fromLTRB(showBackButton ? 4 : 16, 8, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: tokens.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Image.asset(kCompanyLogoAsset, fit: BoxFit.contain),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        kCompanyName.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tokens.primaryStrong,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: subtitle == null ? 17 : 15,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 1),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.inkMuted, height: 1.2),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[...actions, const SizedBox(width: AppSpacing.xs)],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border(bottom: BorderSide(color: tokens.border)),
                boxShadow: AppShadows.subtle,
              ),
              child: const SizedBox(height: 1),
            ),
          ),
        ),
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
