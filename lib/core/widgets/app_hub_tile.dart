import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/app_colors.dart';

/// Compact navigation tile for hub screens (Settings, DMS).
///
/// Icon and label sit in a balanced horizontal composition — no empty center.
class AppHubTile extends StatelessWidget {
  const AppHubTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDesktop = Breakpoints.isDesktop(context);
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;

    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 18 : 14,
            vertical: isDesktop ? 16 : 14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: isDesktop ? 40 : 36,
                height: isDesktop ? 40 : 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: isDesktop ? 20 : 18,
                  color: AppColors.text,
                ),
              ),
              SizedBox(width: isDesktop ? 14 : 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: isDesktop ? 14 : 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: AppColors.text,
                      ),
                    ),
                    if (hasSubtitle) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
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
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textLight.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared grid metrics for hub tile screens.
abstract final class AppHubGrid {
  static SliverGridDelegate delegate({
    required bool isDesktop,
    required bool hasSubtitle,
  }) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: isDesktop ? 2 : 1,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      // Short, wide cards read as professional density — not hollow squares.
      childAspectRatio: isDesktop
          ? (hasSubtitle ? 4.6 : 5.2)
          : (hasSubtitle ? 3.6 : 4.2),
    );
  }
}
