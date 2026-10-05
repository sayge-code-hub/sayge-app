import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../../hrms/domain/usecases/set_employee_photo_from_document_usecase.dart';
import '../../domain/entities/dms_entity.dart';
import '../../domain/entities/document_record.dart';
import '../../domain/usecases/get_document_download_url.dart';

bool documentIsImage(DocumentRecord document) {
  final name = document.fileName.toLowerCase();
  final mime = document.mimeType.toLowerCase();
  return mime.startsWith('image/') ||
      name.endsWith('.png') ||
      name.endsWith('.jpg') ||
      name.endsWith('.jpeg') ||
      name.endsWith('.webp') ||
      name.endsWith('.gif');
}

Future<void> openDocumentRecord(
  BuildContext context,
  DocumentRecord document,
) async {
  final result = await sl<GetDocumentDownloadUrlUseCase>()(document);
  if (!context.mounted) return;

  await result.fold(
    (failure) => showAppMessageDialog(
      context,
      title: 'Document',
      message: failure.message,
    ),
    (url) async {
      if (documentIsImage(document)) {
        final useAsProfile = document.entityType == DmsEntityType.employee;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return Dialog(
              backgroundColor: AppColors.background,
              surfaceTintColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              document.title.trim().isEmpty
                                  ? document.fileName
                                  : document.title.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(dialogContext)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: InteractiveViewer(
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Could not load this image. The file may not be uploaded yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textLight),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (useAsProfile)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () async {
                              final result =
                                  await sl<SetEmployeePhotoFromDocumentUseCase>()(
                                employeeId: document.entityId,
                                storagePath: document.storagePath,
                              );
                              if (!dialogContext.mounted) return;
                              await result.fold(
                                (failure) => showAppMessageDialog(
                                  dialogContext,
                                  title: 'Profile picture',
                                  message: failure.message,
                                ),
                                (_) async {
                                  Navigator.of(dialogContext).pop();
                                  if (!context.mounted) return;
                                  await showAppMessageDialog(
                                    context,
                                    message:
                                        'Profile picture updated for ${document.entityName}.',
                                  );
                                },
                              );
                            },
                            child: const Text('Use as profile picture'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
        return;
      }

      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        await showAppMessageDialog(
          context,
          title: 'Document',
          message: 'Could not open this document.',
        );
      }
    },
  );
}
