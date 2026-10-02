import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Primary filled button used for main actions.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final isDisabled = !enabled || isLoading || onPressed == null;

    return SizedBox(
      width: expand ? double.infinity : null,
      height: 44,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.text,
          foregroundColor: AppColors.background,
          disabledBackgroundColor: AppColors.textLight,
          disabledForegroundColor: AppColors.background,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.background,
                    ),
                  ),
                )
              : Text(label, key: const ValueKey('label')),
        ),
      ),
    );
  }
}
