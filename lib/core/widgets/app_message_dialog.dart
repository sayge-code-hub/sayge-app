import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_button.dart';

/// Centered confirmation popup (replaces success snackbars).
Future<void> showAppMessageDialog(
  BuildContext context, {
  required String message,
  String title = 'Success',
  String confirmLabel = 'OK',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          title,
          style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
        ),
        content: Text(
          message,
          style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                color: AppColors.text,
              ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          SizedBox(
            width: 120,
            child: AppButton(
              label: confirmLabel,
              expand: true,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ],
      );
    },
  );
}
