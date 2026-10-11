import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_message_dialog.dart';
import '../widgets/app_text_field.dart';
import 'pdf_saver.dart';

/// Saves PDF bytes locally, then opens a mailto: draft with subject/body.
Future<void> emailPdfDocument({
  required Uint8List bytes,
  required String filename,
  required String subject,
  required String body,
  String? to,
}) async {
  await savePdfBytes(bytes: bytes, filename: filename);
  final uri = Uri(
    scheme: 'mailto',
    path: (to ?? '').trim(),
    queryParameters: {
      'subject': subject,
      'body': body,
    },
  );
  final launched = await launchUrl(uri);
  if (!launched) {
    throw StateError('Could not open email app');
  }
}

/// Prompts for a recipient, then runs [onRecipient] with the entered address.
Future<void> showEmailRecipientDialog({
  required BuildContext context,
  required Future<void> Function(String recipient) onRecipient,
  String title = 'Email document',
  String initialRecipient = '',
}) async {
  final controller = TextEditingController(text: initialRecipient);
  final recipient = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text(title),
        content: AppTextField(
          label: 'Recipient email',
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Continue',
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
          ),
        ],
      );
    },
  );
  controller.dispose();
  if (recipient == null || recipient.isEmpty) return;

  try {
    await onRecipient(recipient);
  } catch (_) {
    if (!context.mounted) return;
    await showAppMessageDialog(
      context,
      title: 'Email',
      message: 'Could not prepare the email. The PDF was saved if download succeeded.',
    );
  }
}
