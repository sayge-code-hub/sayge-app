import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../injection_container.dart';
import '../../../dms/domain/entities/dms_entity.dart';
import '../../../dms/domain/entities/document_record.dart';
import '../../../dms/domain/usecases/get_documents.dart';

class EmployeeDocumentsSection extends StatefulWidget {
  const EmployeeDocumentsSection({
    super.key,
    required this.employeeId,
    required this.isDesktop,
  });

  final String employeeId;
  final bool isDesktop;

  @override
  State<EmployeeDocumentsSection> createState() =>
      _EmployeeDocumentsSectionState();
}

class _EmployeeDocumentsSectionState extends State<EmployeeDocumentsSection> {
  late Future<_DocumentsLoadResult> _future;

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
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
