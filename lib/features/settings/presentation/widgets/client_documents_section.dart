import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../../dms/domain/entities/dms_entity.dart';
import '../../../dms/domain/entities/document_record.dart';
import '../../../dms/domain/usecases/add_document.dart';
import '../../../dms/domain/usecases/get_documents.dart';

/// Lists and attaches DMS documents for a client (`entity_type` = company).
class ClientDocumentsSection extends StatefulWidget {
  const ClientDocumentsSection({
    super.key,
    required this.clientId,
    required this.clientName,
    this.enabled = true,
  });

  final String clientId;
  final String clientName;
  final bool enabled;

  @override
  State<ClientDocumentsSection> createState() => _ClientDocumentsSectionState();
}

class _ClientDocumentsSectionState extends State<ClientDocumentsSection> {
  late Future<_DocumentsLoadResult> _future;
  final _titleController = TextEditingController();
  final _fileController = TextEditingController();
  final _notesController = TextEditingController();
  String _category = DmsDocumentCategories.fallback;
  bool _saving = false;
  int _formEpoch = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ClientDocumentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientId != widget.clientId) {
      _future = _load();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _fileController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<_DocumentsLoadResult> _load() async {
    final result = await sl<GetDocumentsUseCase>()(
      entityType: DmsEntityType.client,
      entityId: widget.clientId,
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

  Future<void> _attach() async {
    if (!widget.enabled || _saving) return;
    final title = _titleController.text.trim();
    final fileName = _fileController.text.trim();
    if (title.isEmpty || fileName.isEmpty) {
      await showAppMessageDialog(
        context,
        title: 'Documents',
        message: 'Title and file name are required.',
      );
      return;
    }

    setState(() => _saving = true);
    final result = await sl<AddDocumentUseCase>()(
      entityType: DmsEntityType.client,
      entityId: widget.clientId,
      entityName: widget.clientName,
      title: title,
      fileName: fileName,
      category: _category,
      notes: _notesController.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    await result.fold(
      (failure) async {
        await showAppMessageDialog(
          context,
          title: 'Documents',
          message: failure.message,
        );
      },
      (_) async {
        _titleController.clear();
        _fileController.clear();
        _notesController.clear();
        setState(() {
          _category = DmsDocumentCategories.fallback;
          _formEpoch++;
        });
        _reload();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
            style: textTheme.titleMedium?.copyWith(
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
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
                );
              }

              if (result.documents.isEmpty) {
                return Text(
                  'No documents attached yet.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                  ),
                );
              }

              final grouped = <String, List<DocumentRecord>>{};
              for (final doc in result.documents) {
                final key = doc.category.trim().isEmpty
                    ? 'General'
                    : doc.category.trim();
                grouped.putIfAbsent(key, () => []).add(doc);
              }

              final dateFormat = AppDates.dms;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in grouped.entries) ...[
                    Text(
                      entry.key,
                      style: textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                        letterSpacing: 0.4,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final doc in entry.value) ...[
                      _DocumentRow(
                        document: doc,
                        dateLabel: dateFormat.format(doc.uploadedAt),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 4),
                  ],
                ],
              );
            },
          ),
          if (widget.enabled) ...[
            const Divider(height: 28, color: AppColors.border),
            Text(
              'Attach document',
              style: textTheme.titleMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 14),
            AppDropdown<String>(
              key: ValueKey('client-doc-category-$_formEpoch'),
              label: 'Category',
              value: DmsDocumentCategories.all.contains(_category)
                  ? _category
                  : DmsDocumentCategories.fallback,
              items: DmsDocumentCategories.all,
              itemLabel: (category) => category,
              enabled: !_saving,
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _category = value);
                    },
            ),
            const SizedBox(height: 12),
            AppTextField(
              key: ValueKey('client-doc-title-$_formEpoch'),
              controller: _titleController,
              label: 'Title',
              hintText: 'e.g. MSA',
              enabled: !_saving,
            ),
            const SizedBox(height: 12),
            AppTextField(
              key: ValueKey('client-doc-file-$_formEpoch'),
              controller: _fileController,
              label: 'File name',
              hintText: 'e.g. msa.pdf',
              enabled: !_saving,
            ),
            const SizedBox(height: 12),
            AppTextField(
              key: ValueKey('client-doc-notes-$_formEpoch'),
              controller: _notesController,
              label: 'Notes',
              hintText: 'Optional',
              enabled: !_saving,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: _saving ? 'Saving…' : 'Attach',
                expand: false,
                isLoading: _saving,
                enabled: !_saving,
                onPressed: _saving ? null : _attach,
              ),
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

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.document,
    required this.dateLabel,
  });

  final DocumentRecord document;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            document.title,
            style: textTheme.bodyLarge?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            document.fileName,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateLabel,
            style: textTheme.labelLarge?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textLight,
            ),
          ),
          if (document.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              document.notes,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: AppColors.textLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
