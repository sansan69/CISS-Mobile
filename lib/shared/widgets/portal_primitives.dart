import 'package:flutter/material.dart';

class PortalSurfaceCard extends StatelessWidget {
  const PortalSurfaceCard({super.key, required this.child, this.padding, this.margin, this.accentColor, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: margin ?? const EdgeInsets.only(bottom: 8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

class PortalSectionHeading extends StatelessWidget {
  const PortalSectionHeading({super.key, required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
        if (action != null) action!,
      ],
    ),
  );
}
