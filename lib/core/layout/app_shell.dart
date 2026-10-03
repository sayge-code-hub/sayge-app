import 'package:flutter/material.dart';

import '../../features/auth/domain/entities/user.dart';
import '../theme/app_colors.dart';
import '../widgets/app_version_label.dart';
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
    this.onLogout,
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
  final VoidCallback? onLogout;
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
            onLogout: onLogout,
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
            onLogout: onLogout,
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
    this.onLogout,
    this.actions,
  });

  final User user;
  final String title;
  final List<AppNavSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final VoidCallback? onBack;
  final VoidCallback? onLogout;
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
            onLogout: onLogout,
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
                    const Padding(
                      padding: EdgeInsets.fromLTRB(32, 20, 32, 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AppVersionLabel(
                          alignment: Alignment.centerRight,
                          textAlign: TextAlign.right,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  // Full main-panel width (top header + body + sticky footers).
                  Expanded(child: body),
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
    this.onLogout,
    this.actions,
  });

  final User user;
  final String title;
  final List<AppNavSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final VoidCallback? onBack;
  final VoidCallback? onLogout;
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
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(
              child: AppVersionLabel(
                alignment: Alignment.centerRight,
                textAlign: TextAlign.right,
                fontSize: 11,
              ),
            ),
          ),
          ...?actions,
        ],
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
            onLogout: onLogout,
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
          const AppVersionLabel(
            alignment: Alignment.centerRight,
            textAlign: TextAlign.right,
            fontSize: 11,
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: 12),
            ...actions!,
          ],
        ],
      ),
    );
  }
}

class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.user,
    required this.sections,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onLogout,
    this.compact = true,
  });

  final User user;
  final List<AppNavSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onLogout;
  final bool compact;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  static const _navFontSize = 14.0;

  /// Section labels the user has expanded. Active route's section is also shown.
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    // Expand every section that has children so leaves (e.g. Expense) are
    // visible in the drawer / sidebar without an extra tap.
    for (final section in widget.sections) {
      if (section.items.isNotEmpty) {
        _expanded.add(section.label);
      }
    }
    final label = _sectionLabelForIndex(widget.selectedIndex);
    if (label != null) {
      _expanded.add(label);
    }
  }

  @override
  void didUpdateWidget(covariant _Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      final label = _sectionLabelForIndex(widget.selectedIndex);
      if (label != null && !_expanded.contains(label)) {
        setState(() => _expanded.add(label));
      }
    }
  }

  String? _sectionLabelForIndex(int selectedIndex) {
    var nextIndex = 0;
    for (final section in widget.sections) {
      final sectionIndex = section.selectable ? nextIndex++ : null;
      final childStart = nextIndex;
      nextIndex += section.items.length;
      final childEnd = nextIndex;

      if (sectionIndex == selectedIndex) return section.label;
      if (selectedIndex >= childStart && selectedIndex < childEnd) {
        return section.label;
      }
    }
    return null;
  }

  bool _isExpanded(AppNavSection section) {
    if (section.items.isEmpty) return false;
    return _expanded.contains(section.label);
  }

  void _toggleSection(AppNavSection section) {
    if (section.items.isEmpty) return;
    setState(() {
      if (_expanded.contains(section.label)) {
        _expanded.remove(section.label);
      } else {
        _expanded.add(section.label);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.compact ? 248 : null,
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                ..._buildNav(context),
                if (widget.onLogout != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: _NavTile(
                      label: 'Log out',
                      selected: false,
                      enabled: true,
                      fontSize: _navFontSize,
                      indent: false,
                      leading: const Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: AppColors.textLight,
                      ),
                      onTap: widget.onLogout,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(
            height: 1,
            color: AppColors.border,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.text.withValues(alpha: 0.08),
                  child: Text(
                    _initials(widget.user),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 12,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.user.name ?? widget.user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontSize: 13,
                              height: 1.2,
                              color: AppColors.text,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.user.roleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              height: 1.2,
                              color: AppColors.textLight,
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

    for (final section in widget.sections) {
      if (!section.enabled) {
        final muted = AppColors.textLight.withValues(alpha: 0.55);
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: _NavTile(
              label: section.label,
              selected: false,
              enabled: false,
              fontSize: _navFontSize,
              indent: false,
              leading: section.icon != null
                  ? Icon(section.icon, size: 18, color: muted)
                  : null,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 4));
        continue;
      }

      final sectionIndex = section.selectable ? nextIndex++ : null;
      final sectionSelected =
          sectionIndex != null && sectionIndex == widget.selectedIndex;
      final hasChildren = section.items.isNotEmpty;
      final expanded = _isExpanded(section);

      // Child indices are reserved even when collapsed so route indexes stay stable.
      final childIndexes = <int>[
        for (var i = 0; i < section.items.length; i++) nextIndex + i,
      ];
      nextIndex += section.items.length;

      final childSelected = childIndexes.contains(widget.selectedIndex);
      final sectionIconColor = sectionSelected || childSelected
          ? AppColors.highlight
          : AppColors.text;

      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: _NavTile(
            label: section.label,
            selected: sectionSelected || (hasChildren && childSelected),
            fontSize: _navFontSize,
            leading: section.iconAsset != null
                ? Image.asset(
                    section.iconAsset!,
                    width: 18,
                    height: 18,
                    color: sectionIconColor,
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.groups_outlined,
                      size: 18,
                      color: sectionIconColor,
                    ),
                  )
                : section.icon != null
                    ? Icon(
                        section.icon,
                        size: 18,
                        color: sectionIconColor,
                      )
                    : null,
            trailing: hasChildren
                ? Icon(
                    expanded
                        ? Icons.expand_more_rounded
                        : Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textLight,
                  )
                : null,
            onTap: () {
              if (hasChildren) {
                _toggleSection(section);
              }
              if (section.selectable && sectionIndex != null) {
                widget.onDestinationSelected(sectionIndex);
              }
            },
            indent: false,
          ),
        ),
      );

      if (expanded) {
        for (var i = 0; i < section.items.length; i++) {
          final item = section.items[i];
          final index = childIndexes[i];
          final selected = index == widget.selectedIndex;
          if (!item.enabled) {
            final muted = AppColors.textLight.withValues(alpha: 0.55);
            widgets.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                child: _NavTile(
                  label: item.label,
                  selected: false,
                  enabled: false,
                  fontSize: _navFontSize,
                  indent: true,
                  leading: item.icon != null
                      ? Icon(item.icon, size: 18, color: muted)
                      : null,
                ),
              ),
            );
            continue;
          }
          final iconColor =
              selected ? AppColors.highlight : AppColors.textLight;
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
                        color: iconColor,
                        colorBlendMode: BlendMode.srcIn,
                      )
                    : item.icon != null
                        ? Icon(
                            item.icon,
                            size: 18,
                            color: iconColor,
                          )
                        : null,
                onTap: () => widget.onDestinationSelected(index),
                indent: true,
              ),
            ),
          );
        }
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
    this.enabled = true,
    this.accentColor,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final Color? accentColor;
  final double fontSize;
  final bool indent;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    if (!enabled) {
      textColor = AppColors.textLight.withValues(alpha: 0.55);
    } else if (accentColor != null) {
      textColor = accentColor!;
    } else if (selected) {
      textColor = AppColors.highlight;
    } else if (onTap == null) {
      textColor = AppColors.text;
    } else {
      textColor = AppColors.textLight;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
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
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
