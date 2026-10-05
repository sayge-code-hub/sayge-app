import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared control height for primary / outlined CTAs next to search fields.
const double kAppButtonHeight = 36;

/// Primary filled button used for main actions.
///
/// Height is fixed at [height] so toolbar and form CTAs stay consistent.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.expand = true,
  });

  static const double height = kAppButtonHeight;

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
      height: height,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.text,
          foregroundColor: AppColors.background,
          disabledBackgroundColor: AppColors.textLight,
          disabledForegroundColor: AppColors.background,
          minimumSize: const Size(0, height),
          maximumSize: const Size(double.infinity, height),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
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

/// Outlined companion to [AppButton] — same height, padding, and type size.
class AppOutlinedButton extends StatelessWidget {
  const AppOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.expand = false,
  });

  static const double height = kAppButtonHeight;

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final isDisabled = !enabled || onPressed == null;

    return SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: OutlinedButton(
        onPressed: isDisabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          disabledForegroundColor: AppColors.textLight,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(0, height),
          maximumSize: const Size(double.infinity, height),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
