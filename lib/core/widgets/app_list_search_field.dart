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
    this.iconSize = 18,
    this.buttonSize = 36,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double iconSize;
  final double buttonSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.all(buttonSize <= 28 ? 4 : 6),
      constraints: BoxConstraints(
        minWidth: buttonSize,
        minHeight: buttonSize,
      ),
      iconSize: iconSize,
      color: AppColors.textLight,
      splashRadius: buttonSize / 2,
      icon: Icon(icon, weight: 300),
    );
  }
}
