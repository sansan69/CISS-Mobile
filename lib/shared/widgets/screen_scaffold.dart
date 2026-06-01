import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/brand.dart';

class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  // Toolbar heights: base = company label + title; extended = + subtitle
  static const double _toolbarBase = 68.0;
  static const double _toolbarWithSub = 80.0;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final double toolbarHeight =
        subtitle == null ? _toolbarBase : _toolbarWithSub;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(toolbarHeight + statusBarHeight),
        child: SafeArea(
          bottom: false,
          child: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          toolbarHeight: toolbarHeight,
          title: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // Brand logo
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: tokens.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset(kCompanyLogoAsset, fit: BoxFit.contain),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Company name — always visible brand mark
                      Text(
                        kCompanyName.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tokens.primaryStrong,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Screen title
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: tokens.inkMuted,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            ...actions,
            const SizedBox(width: AppSpacing.xs),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    tokens.accent.withValues(alpha: 0.28),
                    tokens.border,
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
      ),
      body: Stack(
        children: <Widget>[
          Positioned(
            top: -120,
            left: -40,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.primarySoft.withValues(alpha: 0.42),
                ),
              ),
            ),
          ),
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemBuilder: (BuildContext context, int index) => children[index],
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemCount: children.length,
          ),
        ],
      ),
    );
  }
}
