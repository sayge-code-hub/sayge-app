import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../../dms/domain/entities/dms_entity.dart';
import '../../../dms/domain/entities/document_record.dart';
import '../../../dms/domain/usecases/add_document.dart';
import '../../../dms/domain/usecases/get_documents.dart';
import '../../../dms/presentation/widgets/document_attachment_tile.dart';
import '../../../dms/presentation/widgets/document_drop_zone.dart';

class EmployeeDocumentsSection extends StatefulWidget {
  const EmployeeDocumentsSection({
    super.key,
    required this.employeeId,
    required this.isDesktop,
    this.employeeName = '',
    this.canUpload = false,
  });

  final String employeeId;
  final bool isDesktop;
  final String employeeName;
  final bool canUpload;

  @override
  State<EmployeeDocumentsSection> createState() =>
      _EmployeeDocumentsSectionState();
}

class _EmployeeDocumentsSectionState extends State<EmployeeDocumentsSection> {
  late Future<_DocumentsLoadResult> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant EmployeeDocumentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employeeId != widget.employeeId) {
      _future = _load();
    }
  }

  Future<_DocumentsLoadResult> _load() async {
    final result = await sl<GetDocumentsUseCase>()(
      entityType: DmsEntityType.employee,
      entityId: widget.employeeId,
    );
    return result.fold(
      (failure) => _DocumentsLoadResult.error(failure.message),
      (docs) => _DocumentsLoadResult.ok(docs),
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _attachFiles(List<DocumentPick> files) async {
    if (!widget.canUpload || _saving || files.isEmpty) return;
    setState(() => _saving = true);

    String? firstError;
    var uploaded = 0;
    for (final file in files) {
      final result = await sl<AddDocumentUseCase>()(
        entityType: DmsEntityType.employee,
        entityId: widget.employeeId,
        entityName: widget.employeeName.isEmpty
            ? widget.employeeId
            : widget.employeeName,
        title: file.title,
        fileName: file.fileName,
        category: file.category,
        fileBytes: file.bytes,
        mimeType: file.mimeType,
      );
      result.fold(
        (failure) => firstError ??= failure.message,
        (_) => uploaded++,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (uploaded == 0) {
      await showAppMessageDialog(
        context,
        title: 'Documents',
        message: firstError ?? 'Could not attach the selected files.',
      );
      return;
    }

    _reload();
    await showAppMessageDialog(
      context,
      message: uploaded == 1 ? 'Document attached' : 'Documents attached',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppListCard.sectionPadding,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Documents',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.highlight,
                ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<_DocumentsLoadResult>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.text),
                  ),
                );
              }

              final result = snapshot.data;
              if (result == null || result.errorMessage != null) {
                return Text(
                  result?.errorMessage ?? 'Could not load documents.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                      ),
                );
              }

              if (result.documents.isEmpty) {
                return Text(
                  'No documents attached yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textLight,
                      ),
                );
              }

              return DocumentAttachmentGrid(documents: result.documents);
            },
          ),
          if (widget.canUpload) ...[
            const Divider(height: 28, color: AppColors.border),
            DocumentDropZone(
              enabled: widget.canUpload,
              uploading: _saving,
              onFilesPicked: _attachFiles,
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentsLoadResult {
  const _DocumentsLoadResult._({
    required this.documents,
    this.errorMessage,
  });

  factory _DocumentsLoadResult.ok(List<DocumentRecord> documents) =>
      _DocumentsLoadResult._(documents: documents);

  factory _DocumentsLoadResult.error(String message) =>
      _DocumentsLoadResult._(documents: const [], errorMessage: message);

  final List<DocumentRecord> documents;
  final String? errorMessage;
}
