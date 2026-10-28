import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/app_colors.dart';

/// Shared mobile-first layout for login / password auth screens.
///
/// Keeps consistent outer padding, a scrollable centered column (max 420),
/// and optional sticky footer (e.g. version label) that stays above the
/// home indicator without eating into the form.
class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    super.key,
    required this.child,
    this.footer,
  });

  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final compact = Breakpoints.isCompact(context);
    final horizontal = compact ? 20.0 : 24.0;
    final top = compact ? 20.0 : 28.0;
    final bottom = compact ? 12.0 : 16.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            scrollbars: false,
                            overscroll: false,
                          ),
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.viewInsetsOf(context).bottom > 0
                                  ? 12
                                  : 0,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Center(
                                child: child,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: 8),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
