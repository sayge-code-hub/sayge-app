import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/app_colors.dart';

/// Sticky / footer action bar for 1–2 primary CTAs.
///
/// Spans the **full width** of the main content panel.
/// - **Mobile:** equal-width buttons in a sticky bottom bar.
/// - **Desktop:** buttons right-aligned at the bottom-right edge.
///
/// For list-page "New …" CTAs on desktop, put the button in the page toolbar
/// (e.g. beside the search field) and only use this widget on mobile.
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
      child: SizedBox(
        width: double.infinity,
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
            child: isDesktop ? _desktopRow() : _mobileRow(),
          ),
        ),
      ),
    );
  }

  Widget _desktopRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
            child: SizedBox(
              height: 44,
              width: 160,
              child: children[i],
            ),
          ),
        ],
      ],
    );
  }

  Widget _mobileRow() {
    return Row(
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
    );
  }
}
