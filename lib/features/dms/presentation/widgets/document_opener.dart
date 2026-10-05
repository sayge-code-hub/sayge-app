import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../../hrms/domain/usecases/set_employee_photo_from_document_usecase.dart';
import '../../domain/entities/dms_entity.dart';
import '../../domain/entities/document_record.dart';
import '../../domain/usecases/get_document_download_url.dart';
import 'document_preview.dart';

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

bool documentIsPdf(DocumentRecord document) {
  final name = document.fileName.toLowerCase();
  final mime = document.mimeType.toLowerCase();
  return mime.contains('pdf') || name.endsWith('.pdf');
}

IconData documentIconFor(DocumentRecord document) {
  final name = document.fileName.toLowerCase();
  final mime = document.mimeType.toLowerCase();
  if (documentIsPdf(document)) return Icons.picture_as_pdf_outlined;
  if (documentIsImage(document)) return Icons.image_outlined;
  if (mime.contains('sheet') ||
      name.endsWith('.xls') ||
      name.endsWith('.xlsx') ||
      name.endsWith('.csv')) {
    return Icons.table_chart_outlined;
  }
  if (mime.contains('word') ||
      name.endsWith('.doc') ||
      name.endsWith('.docx')) {
    return Icons.description_outlined;
  }
  return Icons.attach_file;
}

String documentDisplayTitle(DocumentRecord document) {
  final title = document.title.trim();
  if (title.isNotEmpty) return title;
  final fileName = document.fileName.trim();
  return fileName.isEmpty ? 'Document' : fileName;
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
    (url) => showDocumentPreviewDialog(
      context,
      document: document,
      url: url,
    ),
  );
}

Future<void> downloadDocumentUrl({
  required String url,
  required String fileName,
}) async {
  final uri = Uri.parse(url);
  final launched = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
  if (!launched) {
    throw Exception('Could not download this document.');
  }
}

Future<void> showDocumentPreviewDialog(
  BuildContext context, {
  required DocumentRecord document,
  required String url,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _DocumentPreviewDialog(
        document: document,
        url: url,
      );
    },
  );
}

class _DocumentPreviewDialog extends StatefulWidget {
  const _DocumentPreviewDialog({
    required this.document,
    required this.url,
  });

  final DocumentRecord document;
  final String url;

  @override
  State<_DocumentPreviewDialog> createState() => _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState extends State<_DocumentPreviewDialog> {
  bool _downloading = false;
  bool _settingPhoto = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await downloadDocumentUrl(
        url: widget.url,
        fileName: widget.document.fileName,
      );
    } catch (_) {
      if (!mounted) return;
      await showAppMessageDialog(
        context,
        title: 'Document',
        message: 'Could not download this document.',
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _useAsProfile() async {
    setState(() => _settingPhoto = true);
    final result = await sl<SetEmployeePhotoFromDocumentUseCase>()(
      employeeId: widget.document.entityId,
      storagePath: widget.document.storagePath,
    );
    if (!mounted) return;
    setState(() => _settingPhoto = false);

    await result.fold(
      (failure) => showAppMessageDialog(
        context,
        title: 'Profile picture',
        message: failure.message,
      ),
      (_) async {
        Navigator.of(context).pop();
        if (!context.mounted) return;
        await showAppMessageDialog(
          context,
          message:
              'Profile picture updated for ${widget.document.entityName}.',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final url = widget.url;
    final title = documentDisplayTitle(document);
    final isImage = documentIsImage(document);
    final isPdf = documentIsPdf(document);
    final useAsProfile =
        isImage && document.entityType == DmsEntityType.employee;
    final webFrame = isPdf ? buildWebDocumentFrame(url) : null;

    return Dialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840, maxHeight: 780),
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
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Download',
                    onPressed: _downloading ? null : _download,
                    icon: _downloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined, size: 20),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColoredBox(
                    color: AppColors.surface,
                    child: SizedBox(
                      height: 520,
                      width: double.infinity,
                      child: isImage
                          ? InteractiveViewer(
                              child: Center(
                                child: Image.network(
                                  url,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'Could not load this image. The file may not be uploaded yet.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : (webFrame ??
                              _FallbackPreview(
                                document: document,
                                onOpen: _download,
                              )),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (useAsProfile) ...[
                    AppOutlinedButton(
                      label: _settingPhoto ? 'Updating…' : 'Use as profile',
                      enabled: !_settingPhoto && !_downloading,
                      onPressed: _useAsProfile,
                    ),
                    const SizedBox(width: 10),
                  ],
                  AppButton(
                    label: _downloading ? 'Downloading…' : 'Download',
                    expand: false,
                    isLoading: _downloading,
                    enabled: !_downloading,
                    onPressed: _download,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackPreview extends StatelessWidget {
  const _FallbackPreview({
    required this.document,
    required this.onOpen,
  });

  final DocumentRecord document;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              documentIconFor(document),
              size: 48,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 12),
            Text(
              document.fileName.trim().isEmpty
                  ? documentDisplayTitle(document)
                  : document.fileName.trim(),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Preview is not available for this file type. Download to open it.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 16),
            AppOutlinedButton(
              label: 'Open / download',
              onPressed: onOpen,
            ),
          ],
        ),
      ),
    );
  }
}
