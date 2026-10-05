import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared list / detail tile chrome with comfortable internal padding.
class AppListCard extends StatelessWidget {
  const AppListCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppListCard.tilePadding,
    this.borderRadius = 10,
    this.color = AppColors.background,
  });

  /// Default padding for interactive list rows (proposals, invoices, payroll).
  static const EdgeInsets tilePadding = EdgeInsets.fromLTRB(18, 16, 14, 16);

  /// Slightly roomier padding for section / detail cards.
  static const EdgeInsets sectionPadding = EdgeInsets.fromLTRB(20, 18, 20, 20);

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side: const BorderSide(color: AppColors.border),
    );

    if (onTap == null) {
      return Material(
        color: color,
        shape: shape,
        child: Padding(
          padding: padding,
          child: child,
        ),
      );
    }

    return Material(
      color: color,
      shape: shape,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
