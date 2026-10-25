import 'package:flutter/material.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';

/// Shared spacing for Cafe POS screens.
abstract final class CafePosSpace {
  static EdgeInsets page(BuildContext context) {
    final wide = Breakpoints.isDesktop(context);
    return EdgeInsets.fromLTRB(wide ? 32 : 16, 16, wide ? 32 : 16, 24);
  }

  static const double radius = 14;
  static const double gap = 12;
}

/// Soft atmospheric wash behind POS content (stays within app palette).
class CafePosBackdrop extends StatelessWidget {
  const CafePosBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceMuted,
            AppColors.surface,
            AppColors.background,
          ],
          stops: const [0, 0.35, 1],
        ),
      ),
      child: child,
    );
  }
}

/// POS screen toolbar — titles/subtitles are intentionally omitted (hub chrome).
class CafePosPageHeader extends StatelessWidget {
  const CafePosPageHeader({
    super.key,
    this.title = '',
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (trailing == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: trailing!,
    );
  }
}

/// Bumps when shell terminal actions are tapped.
abstract final class CafePosTerminalChrome {
  static final ValueNotifier<int> newTableTick = ValueNotifier<int>(0);
  static final ValueNotifier<int> clearTablesTick = ValueNotifier<int>(0);

  static void requestNewTable() => newTableTick.value++;

  static void requestClearTables() => clearTablesTick.value++;
}

/// Shell app-bar actions for list screens (Orders / Reports / Kitchen).
abstract final class CafePosListChrome {
  static final ValueNotifier<int> refreshTick = ValueNotifier<int>(0);
  static final ValueNotifier<int> deleteTick = ValueNotifier<int>(0);

  static void requestRefresh() => refreshTick.value++;

  static void requestDelete() => deleteTick.value++;
}

class CafePosEmptyState extends StatelessWidget {
  const CafePosEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.highlight.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Icon(icon, size: 28, color: AppColors.highlight),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 20),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Initials monogram for cafe rows / hub identity.
class CafePosMonogram extends StatelessWidget {
  const CafePosMonogram({super.key, required this.label, this.size = 44});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(label);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.highlight.withValues(alpha: 0.18),
            AppColors.highlight.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: AppColors.highlight.withValues(alpha: 0.22)),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              fontSize: size * 0.34,
              letterSpacing: -0.3,
            ),
      ),
    );
  }

  static String _initials(String raw) {
    final parts = raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

/// Tappable nav tile for Cafe POS hub.
class CafePosNavTile extends StatelessWidget {
  const CafePosNavTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle = '',
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CafePosSpace.radius),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.highlight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 22, color: AppColors.highlight),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.text,
                ),
              ),
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.25,
                    color: AppColors.textLight,
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

/// Shared compact app-bar controls for Orders / Reports date + actions.
abstract final class CafePosHeaderActions {
  static const double controlRadius = 6;

  static ButtonStyle dateButtonStyle() => TextButton.styleFrom(
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.background,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
        visualDensity: VisualDensity.compact,
      );

  static ButtonStyle iconButtonStyle() => IconButton.styleFrom(
        backgroundColor: AppColors.background,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
        visualDensity: VisualDensity.compact,
      );
}

class CafePosStatusChip extends StatelessWidget {
  const CafePosStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? color.withValues(alpha: 0.16)
        : AppColors.background;
    final border = selected ? color.withValues(alpha: 0.45) : AppColors.border;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                  height: 1,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.text : AppColors.textLight,
                ),
          ),
        ),
      ),
    );
  }
}
