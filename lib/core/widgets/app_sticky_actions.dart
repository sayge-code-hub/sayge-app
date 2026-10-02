import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/app_colors.dart';

/// Sticky bottom action bar with equal-width buttons in a single row.
///
/// Use for screens with 1–2 primary CTAs. Each child is stretched to share
/// the row evenly — prefer [AppButton] with `expand: true` and full-width
/// [OutlinedButton]s.
class AppStickyActions extends StatelessWidget {
  const AppStickyActions({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    assert(
      children.isNotEmpty && children.length <= 2,
      'AppStickyActions expects 1–2 actions',
    );

    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;

    return Material(
      color: AppColors.background,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 16),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: children[i],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
