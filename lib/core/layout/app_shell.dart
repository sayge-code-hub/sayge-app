import 'package:flutter/material.dart';

import '../../features/auth/domain/entities/user.dart';
import '../theme/app_colors.dart';
import 'app_destination.dart';
import 'breakpoints.dart';

/// Responsive shell inspired by desktop HR consoles.
///
/// Desktop: persistent left sidebar + wide main panel.
/// Mobile: top app bar + drawer (not a shrunk sidebar).
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.user,
    required this.title,
    required this.sections,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.onBack,
    this.actions,
  });

  /// Sidebar logo band: top padding + logo + bottom padding (before divider).
  static const double logoBandHeight = 24 + 30 + 20;

  final User user;
  final String title;
  final List<AppNavSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  /// When set, shows a leading back control in the content header / app bar.
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final shell = Breakpoints.isDesktop(context)
        ? _DesktopShell(
            user: user,
            title: title,
            sections: sections,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            onBack: onBack,
            actions: actions,
            body: body,
          )
        : _MobileShell(
            user: user,
            title: title,
            sections: sections,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            onBack: onBack,
            actions: actions,
            body: body,
          );

    if (onBack == null) return shell;

    // Nested panes under the shell often use go_router `go`, so the navigator
    // may not pop. Intercept system/browser-style back to the parent route.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack!();
      },
      child: shell,
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.user,
    required this.title,
    required this.sections,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.onBack,
    this.actions,
  });

  final User user;
  final String title;
  final List<AppNavSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(
        children: [
          _Sidebar(
            user: user,
            sections: sections,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title.isNotEmpty)
                    _DesktopHeader(
                      title: title,
                      onBack: onBack,
                      actions: actions,
                    )
                  else
                    const SizedBox(height: AppShell.logoBandHeight),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Breakpoints.contentMax,
                        ),
                        child: body,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.user,
    required this.title,
    required this.sections,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.onBack,
    this.actions,
  });

  final User user;
  final String title;
  final List<AppNavSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: onBack == null ? 0 : NavigationToolbar.kMiddleSpacing,
        title: title.isEmpty
            ? null
            : Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
        leading: onBack == null
            ? null
            : IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
        actions: actions,
      ),
      drawer: Drawer(
        backgroundColor: AppColors.surfaceMuted,
        child: SafeArea(
          child: _Sidebar(
            user: user,
            sections: sections,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              Navigator.of(context).pop();
              onDestinationSelected(index);
            },
            compact: false,
          ),
        ),
      ),
      body: body,
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({
    required this.title,
    this.onBack,
    this.actions,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 32, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null) ...[
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              icon: const Icon(
                Icons.arrow_back,
                size: 22,
                color: AppColors.text,
              ),
            ),
            const SizedBox(width: 4),
          ] else
            const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 26,
                  ),
            ),
          ),
          ...?actions,
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.user,
    required this.sections,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.compact = true,
  });

  final User user;
  final List<AppNavSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool compact;

  static const _navFontSize = 14.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 248 : null,
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border(
          right: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/images/sayge_logo.webp',
                height: 30,
                semanticLabel: 'Sayge',
              ),
            ),
          ),
          const Divider(
            height: 1,
            color: AppColors.border,
          ),
          const SizedBox(height: 12),
          ..._buildNav(context),
          const Spacer(),
          const Divider(
            height: 1,
            color: AppColors.border,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.text.withValues(alpha: 0.08),
                  child: Text(
                    _initials(user),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 12,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name ?? user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontSize: 13,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.roleLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNav(BuildContext context) {
    final widgets = <Widget>[];
    var nextIndex = 0;

    for (final section in sections) {
      final sectionIndex = section.selectable ? nextIndex++ : null;
      final sectionSelected =
          sectionIndex != null && sectionIndex == selectedIndex;

      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: _NavTile(
            label: section.label,
            selected: sectionSelected,
            fontSize: _navFontSize,
            leading: section.iconAsset != null
                ? Image.asset(
                    section.iconAsset!,
                    width: 18,
                    height: 18,
                    color: AppColors.text,
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.groups_outlined,
                      size: 18,
                      color: AppColors.text,
                    ),
                  )
                : section.icon != null
                    ? Icon(
                        section.icon,
                        size: 18,
                        color: AppColors.text,
                      )
                    : null,
            onTap: section.selectable
                ? () => onDestinationSelected(sectionIndex!)
                : null,
            indent: false,
          ),
        ),
      );

      for (final item in section.items) {
        final index = nextIndex++;
        final selected = index == selectedIndex;
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
            child: _NavTile(
              label: item.label,
              selected: selected,
              fontSize: _navFontSize,
              leading: item.iconAsset != null
                  ? Image.asset(
                      item.iconAsset!,
                      width: 18,
                      height: 18,
                      color: AppColors.textLight,
                      colorBlendMode: BlendMode.srcIn,
                    )
                  : item.icon != null
                      ? Icon(
                          item.icon,
                          size: 18,
                          color: AppColors.textLight,
                        )
                      : null,
              onTap: () => onDestinationSelected(index),
              indent: true,
            ),
          ),
        );
      }

      widgets.add(const SizedBox(height: 12));
    }

    return widgets;
  }

  String _initials(User user) {
    final source = (user.name ?? user.email).trim();
    final parts = source.split(RegExp(r'\s+|@'));
    if (parts.isEmpty || parts.first.isEmpty) return 'S';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.selected,
    required this.fontSize,
    required this.indent,
    this.leading,
    this.onTap,
  });

  final String label;
  final bool selected;
  final double fontSize;
  final bool indent;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    if (selected) {
      textColor = AppColors.highlight;
    } else if (onTap == null) {
      textColor = AppColors.text;
    } else {
      textColor = AppColors.textLight;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.fromLTRB(indent ? 28 : 12, 11, 12, 11),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w400,
                        color: textColor,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
