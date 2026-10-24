import 'package:flutter/material.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_accent.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_list_card.dart';

class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = AppAccent.of(context);
    final isDesktop = Breakpoints.isDesktop(context);
    final textTheme = Theme.of(context).textTheme;
    final selected = accent.color.toARGB32();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 16,
        isDesktop ? 20 : 12,
        isDesktop ? 32 : 16,
        32,
      ),
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: AppListCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accent',
                    style: textTheme.titleMedium?.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Replaces the orange accent across the app. '
                    'Text, borders, and backgrounds stay the same.',
                    style: textTheme.bodyMedium?.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (final choice in AppAccent.presets)
                        _AccentSwatch(
                          choice: choice,
                          selected: choice.color.toARGB32() == selected,
                          onTap: () => accent.setColor(choice.color),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final AccentChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final checkColor = choice.color.computeLuminance() > 0.6
        ? AppColors.text
        : AppColors.background;

    return Tooltip(
      message: choice.name,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: choice.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.text : AppColors.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 18, color: checkColor)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              choice.name,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 11,
                color: selected ? AppColors.text : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
