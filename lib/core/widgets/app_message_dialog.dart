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

/// Ask before leaving a create / edit form. Returns `true` when the user
/// confirms they want to leave without saving.
Future<bool> confirmLeaveForm(
  BuildContext context, {
  String title = 'Leave without saving?',
  String message = 'Your changes will be lost if you go back.',
  String stayLabel = 'Stay',
  String leaveLabel = 'Leave',
}) async {
  final result = await showDialog<bool>(
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
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(stayLabel),
          ),
          SizedBox(
            width: 120,
            child: AppButton(
              label: leaveLabel,
              expand: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ),
        ],
      );
    },
  );
  return result == true;
}

/// Runs [onLeave] only after [confirmLeaveForm] succeeds.
Future<void> leaveFormIfConfirmed(
  BuildContext context,
  VoidCallback onLeave,
) async {
  final ok = await confirmLeaveForm(context);
  if (!ok || !context.mounted) return;
  onLeave();
}
