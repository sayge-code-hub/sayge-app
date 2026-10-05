import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_hub_tile.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/dms_entity.dart';
import '../bloc/dms/dms_bloc.dart';
import '../widgets/document_attachment_tile.dart';
import '../widgets/document_drop_zone.dart';
import '../../../hrms/presentation/widgets/employee_avatar.dart';

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
          prev.status != next.status && next.status == DmsStatus.success,
      listener: (context, state) async {
        if (state.status == DmsStatus.success) {
          await showAppMessageDialog(
            context,
            message: 'Documents attached',
          );
        }
      },
      builder: (context, state) {
        if (state.status == DmsStatus.initial) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        final padding = EdgeInsets.fromLTRB(
          isDesktop ? 32 : 16,
          isDesktop ? 12 : 8,
          isDesktop ? 32 : 16,
          isDesktop ? 32 : 16,
        );

        Widget child;
        switch (state.level) {
          case DmsLevel.hub:
            child = _HubView(isDesktop: isDesktop);
          case DmsLevel.entities:
            child = _EntityListView(state: state, isDesktop: isDesktop);
          case DmsLevel.documents:
            child = _DocumentsView(state: state, isDesktop: isDesktop);
        }

        final needsBackTrap = state.level != DmsLevel.hub;
        final body = Padding(padding: padding, child: child);

        if (!needsBackTrap) return body;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final bloc = context.read<DmsBloc>();
            if (state.level == DmsLevel.documents) {
              bloc.add(const DmsSelectionCleared());
            } else {
              bloc.add(const DmsHubOpened());
            }
          },
          child: body,
        );
      },
    );
  }
}

IconData _iconFor(DmsEntityType type) {
  switch (type) {
    case DmsEntityType.employee:
      return Icons.people_outline;
    case DmsEntityType.client:
      return Icons.apartment_outlined;
    case DmsEntityType.vendor:
      return Icons.storefront_outlined;
    case DmsEntityType.candidate:
      return Icons.badge_outlined;
  }
}

class _HubView extends StatelessWidget {
  const _HubView({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final tiles = DmsEntityType.values;

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: GridView.builder(
          shrinkWrap: true,
          itemCount: tiles.length,
          gridDelegate: AppHubGrid.delegate(
            isDesktop: isDesktop,
            hasSubtitle: false,
          ),
          itemBuilder: (context, index) {
            final type = tiles[index];
            return AppHubTile(
              title: type.label,
              icon: _iconFor(type),
              onTap: () =>
                  context.read<DmsBloc>().add(DmsEntityTypeSelected(type)),
            );
          },
        ),
      ),
    );
  }
}

class _EntityListView extends StatefulWidget {
  const _EntityListView({required this.state, required this.isDesktop});

  final DmsState state;
  final bool isDesktop;

  @override
  State<_EntityListView> createState() => _EntityListViewState();
}

class _EntityListViewState extends State<_EntityListView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final state = widget.state;
    final isDesktop = widget.isDesktop;
    final q = _query.trim().toLowerCase();
    final entities = q.isEmpty
        ? state.entities
        : state.entities.where((e) {
            return e.name.toLowerCase().contains(q) ||
                e.subtitle.toLowerCase().contains(q);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () =>
                  context.read<DmsBloc>().add(const DmsHubOpened()),
              icon: const Icon(Icons.arrow_back, size: 20),
            ),
            Expanded(
              child: Text(
                state.entityType.label,
                style: textTheme.titleMedium?.copyWith(fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppListSearchField(
          hintText: 'Search ${state.entityType.label.toLowerCase()}…',
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: state.status == DmsStatus.loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.text),
                  )
                : state.entities.isEmpty
                    ? Center(
                        child: Text(
                          state.entityType == DmsEntityType.vendor ||
                                  state.entityType == DmsEntityType.candidate
                              ? 'No ${state.entityType.label.toLowerCase()} in DMS yet. Add rows to dms_entities.'
                              : 'No ${state.entityType.label.toLowerCase()} found.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : entities.isEmpty
                        ? Center(
                            child: Text(
                              'No matches.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textLight,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: entities.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: AppColors.border,
                            ),
                            itemBuilder: (context, index) {
                              final entity = entities[index];
                              return ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isDesktop ? 20 : 16,
                                  vertical: 8,
                                ),
                                leading: entity.imageUrl != null ||
                                        entity.type ==
                                            DmsEntityType.employee ||
                                        entity.type == DmsEntityType.client
                                    ? EmployeeAvatar(
                                        name: entity.name,
                                        photoUrl: entity.imageUrl,
                                        radius: 18,
                                      )
                                    : null,
                                title: Text(
                                  entity.name,
                                  style: textTheme.bodyLarge
                                      ?.copyWith(fontSize: 14),
                                ),
                                subtitle: entity.subtitle.isEmpty
                                    ? null
                                    : Text(
                                        entity.subtitle,
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontSize: 12,
                                          color: AppColors.textLight,
                                        ),
                                      ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textLight,
                                  size: 18,
                                ),
                                onTap: () => context
                                    .read<DmsBloc>()
                                    .add(DmsEntitySelected(entity)),
                              );
                            },
                          ),
          ),
        ),
      ],
    );
  }
}

class _DocumentsView extends StatelessWidget {
  const _DocumentsView({required this.state, required this.isDesktop});

  final DmsState state;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entity = state.selectedEntity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () =>
                  context.read<DmsBloc>().add(const DmsSelectionCleared()),
              icon: const Icon(Icons.arrow_back, size: 20),
            ),
            if (entity != null &&
                (entity.imageUrl != null ||
                    entity.type == DmsEntityType.employee ||
                    entity.type == DmsEntityType.client)) ...[
              EmployeeAvatar(
                name: entity.name,
                photoUrl: entity.imageUrl,
                radius: 18,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entity?.name ?? 'Documents',
                    style: textTheme.titleMedium?.copyWith(fontSize: 16),
                  ),
                  if (entity?.subtitle.isNotEmpty == true)
                    Text(
                      entity!.subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: state.status == DmsStatus.loadingDocuments
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.text),
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 24 : 16,
                      16,
                      isDesktop ? 24 : 16,
                      24,
                    ),
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
                        DocumentAttachmentGrid(documents: state.documents),
                      const Divider(height: 24, color: AppColors.border),
                      DocumentDropZone(
                        enabled: state.status != DmsStatus.saving,
                        uploading: state.status == DmsStatus.saving,
                        onFilesPicked: (files) {
                          context.read<DmsBloc>().add(
                                DmsFilesSelected([
                                  for (final file in files)
                                    DmsPickedFile(
                                      fileName: file.fileName,
                                      bytes: file.bytes,
                                      mimeType: file.mimeType,
                                    ),
                                ]),
                              );
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
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
