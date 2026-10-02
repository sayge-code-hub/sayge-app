import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_text_field.dart';

/// Compact search field for list / table toolbars.
class AppListSearchField extends StatelessWidget {
  const AppListSearchField({
    super.key,
    required this.onChanged,
    this.controller,
    this.hintText = 'Search…',
    this.enabled = true,
  });

  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final String hintText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      hintText: hintText,
      enabled: enabled,
      prefixIcon: Icons.search,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
    );
  }
}

/// Small, light action icon for dense list rows.
class AppListIconButton extends StatelessWidget {
  const AppListIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      iconSize: 18,
      color: AppColors.textLight,
      splashRadius: 18,
      icon: Icon(icon, weight: 300),
    );
  }
}
