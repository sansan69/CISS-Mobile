import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/brand.dart';

class RoleHeader extends StatelessWidget {
  const RoleHeader({
    super.key,
    required this.name,
    required this.role,
    required this.icon,
    this.trailing,
  });

  final String name;
  final String role;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
        boxShadow: AppShadows.subtle,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tokens.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: tokens.border),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(7),
                    child: Image.asset(kCompanyLogoAsset, fit: BoxFit.contain),
                  ),
                  Positioned(
                    right: 3,
                    bottom: 3,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: tokens.border),
                      ),
                      child: Icon(icon, size: 12, color: tokens.primaryStrong),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    role.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.primaryStrong,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      height: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tokens.ink,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
