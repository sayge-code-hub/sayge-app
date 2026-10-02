import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/dms_entity.dart';
import '../../domain/entities/document_record.dart';
import '../bloc/dms/dms_bloc.dart';

class DmsPage extends StatelessWidget {
  const DmsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DmsBloc>()..add(const DmsStarted()),
      child: const _DmsBody(),
    );
  }
}

class _DmsBody extends StatelessWidget {
  const _DmsBody();

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);

    return BlocConsumer<DmsBloc, DmsState>(
      listenWhen: (prev, next) =>
          (prev.status != next.status && next.status == DmsStatus.success) ||
          (isDesktop &&
              prev.entities != next.entities &&
              next.selectedEntity == null &&
              next.entities.isNotEmpty &&
              next.status == DmsStatus.ready),
      listener: (context, state) async {
        if (state.status == DmsStatus.success) {
          await showAppMessageDialog(
            context,
            message: 'Document attached',
          );
          if (!context.mounted) return;
        }
        if (isDesktop &&
            state.selectedEntity == null &&
            state.entities.isNotEmpty &&
            state.status == DmsStatus.ready) {
          context.read<DmsBloc>().add(DmsEntitySelected(state.entities.first));
        }
      },
      builder: (context, state) {
        if (state.status == DmsStatus.initial ||
            (state.status == DmsStatus.loading && state.entities.isEmpty)) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        final typeTabs = _EntityTypeTabs(
          selected: state.entityType,
          onSelected: (type) {
            context.read<DmsBloc>().add(DmsEntityTypeSelected(type));
          },
        );

        if (isDesktop) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(32, 12, 32, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                typeTabs,
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 280,
                        child: _EntityListPanel(state: state, fill: true),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _DocumentsPanel(state: state, fill: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile: list → documents drill-down with Back to the entity list.
        final showingDocuments = state.selectedEntity != null;
        final mobileBody = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: typeTabs,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: showingDocuments
                    ? _DocumentsPanel(
                        state: state,
                        fill: true,
                        onBack: () {
                          context
                              .read<DmsBloc>()
                              .add(const DmsSelectionCleared());
                        },
                      )
                    : _EntityListPanel(state: state, fill: true),
              ),
            ),
          ],
        );

        if (!showingDocuments) return mobileBody;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              context.read<DmsBloc>().add(const DmsSelectionCleared());
            }
          },
          child: mobileBody,
        );
      },
    );
  }
}

class _EntityTypeTabs extends StatelessWidget {
  const _EntityTypeTabs({
    required this.selected,
    required this.onSelected,
  });

  final DmsEntityType selected;
  final ValueChanged<DmsEntityType> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in DmsEntityType.values)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(type),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        type == selected ? AppColors.text : AppColors.border,
                  ),
                ),
                child: Text(
                  type.label,
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: type == selected
                        ? AppColors.text
                        : AppColors.textLight,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EntityListPanel extends StatelessWidget {
  const _EntityListPanel({
    required this.state,
    required this.fill,
  });

  final DmsState state;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget body;
    if (state.status == DmsStatus.loading) {
      const loadingChild = Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.text),
        ),
      );
      body = fill
          ? const Expanded(child: loadingChild)
          : loadingChild;
    } else if (state.entities.isEmpty) {
      final empty = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No ${state.entityType.label.toLowerCase()} yet.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textLight),
          textAlign: TextAlign.center,
        ),
      );
      body = fill ? Expanded(child: Center(child: empty)) : empty;
    } else {
      final list = ListView.separated(
        shrinkWrap: !fill,
        physics: fill ? null : const NeverScrollableScrollPhysics(),
        itemCount: state.entities.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          color: AppColors.border,
        ),
        itemBuilder: (context, index) {
          final entity = state.entities[index];
          final selected = state.selectedEntity?.id == entity.id;
          return InkWell(
            onTap: () {
              context.read<DmsBloc>().add(DmsEntitySelected(entity));
            },
            child: Container(
              color: selected ? AppColors.surfaceMuted : AppColors.background,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Text(
                entity.name,
                style: textTheme.bodyLarge?.copyWith(
                  fontSize: 14,
                  color: selected ? AppColors.text : AppColors.textLight,
                ),
              ),
            ),
          );
        },
      );
      body = fill ? Expanded(child: list) : list;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              state.entityType.label,
              style: textTheme.titleLarge?.copyWith(fontSize: 16),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          body,
        ],
      ),
    );
  }
}

class _DocumentsPanel extends StatelessWidget {
  const _DocumentsPanel({
    required this.state,
    required this.fill,
    this.onBack,
  });

  final DmsState state;
  final bool fill;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entity = state.selectedEntity;
    final dateFormat = AppDates.dms;

    Widget content;
    if (entity == null) {
      content = Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Select ${state.entityType.singular.toLowerCase()} to view documents.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textLight),
          textAlign: TextAlign.center,
        ),
      );
    } else if (state.status == DmsStatus.loadingDocuments) {
      content = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.text),
        ),
      );
    } else {
      final form = Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.documents.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'No documents attached yet.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
              )
            else
              for (final doc in state.documents) ...[
                _DocumentRow(
                  document: doc,
                  dateLabel: dateFormat.format(doc.uploadedAt),
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 8),
            Text(
              'Attach document',
              style: textTheme.titleMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 14),
            AppTextField(
              key: ValueKey('dms-title-${state.formEpoch}'),
              label: 'Title',
              hintText: 'e.g. PAN card',
              onChanged: (value) {
                context.read<DmsBloc>().add(DmsDocumentTitleChanged(value));
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              key: ValueKey('dms-file-${state.formEpoch}'),
              label: 'File name',
              hintText: 'e.g. pan_card.pdf',
              onChanged: (value) {
                context
                    .read<DmsBloc>()
                    .add(DmsDocumentFileNameChanged(value));
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              key: ValueKey('dms-notes-${state.formEpoch}'),
              label: 'Notes',
              hintText: 'Optional',
              onChanged: (value) {
                context.read<DmsBloc>().add(DmsDocumentNotesChanged(value));
              },
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: state.status == DmsStatus.saving ? 'Saving…' : 'Attach',
                expand: false,
                onPressed: state.status == DmsStatus.saving
                    ? null
                    : () {
                        context
                            .read<DmsBloc>()
                            .add(const DmsDocumentSubmitted());
                      },
              ),
            ),
          ],
        ),
      );

      if (fill) {
        content = Expanded(
          child: SingleChildScrollView(child: form),
        );
      } else {
        content = form;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              onBack != null ? 4 : 20,
              onBack != null ? 4 : 16,
              20,
              onBack != null ? 4 : 12,
            ),
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: AppColors.text,
                    ),
                  ),
                Expanded(
                  child: Text(
                    entity == null
                        ? 'Documents'
                        : 'Documents · ${entity.name}',
                    style: textTheme.titleLarge?.copyWith(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          content,
        ],
      ),
    );
  }
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
