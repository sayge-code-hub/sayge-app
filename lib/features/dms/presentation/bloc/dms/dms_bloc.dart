import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/dms_entity.dart';
import '../../../domain/entities/document_record.dart';
import '../../../domain/usecases/add_document.dart';
import '../../../domain/usecases/create_catalog_entity.dart';
import '../../../domain/usecases/delete_document.dart';
import '../../../domain/usecases/get_dms_entities.dart';
import '../../../domain/usecases/get_documents.dart';
import '../../../domain/usecases/replace_document.dart';
import '../../widgets/document_drop_zone.dart';

part 'dms_event.dart';
part 'dms_state.dart';

class DmsBloc extends Bloc<DmsEvent, DmsState> {
  DmsBloc({
    required this.getDmsEntitiesUseCase,
    required this.getDocumentsUseCase,
    required this.addDocumentUseCase,
    required this.deleteDocumentUseCase,
    required this.replaceDocumentUseCase,
    required this.createCatalogEntityUseCase,
  }) : super(const DmsState()) {
    on<DmsStarted>(_onStarted);
    on<DmsHubOpened>(_onHubOpened);
    on<DmsEntityTypeSelected>(_onEntityTypeSelected);
    on<DmsEntitySelected>(_onEntitySelected);
    on<DmsSelectionCleared>(_onSelectionCleared);
    on<DmsFilesSelected>(_onFilesSelected);
    on<DmsCatalogEntityCreateRequested>(_onCatalogCreate);
    on<DmsDocumentDeleteRequested>(_onDocumentDelete);
    on<DmsDocumentReplaceRequested>(_onDocumentReplace);
  }

  final GetDmsEntitiesUseCase getDmsEntitiesUseCase;
  final GetDocumentsUseCase getDocumentsUseCase;
  final AddDocumentUseCase addDocumentUseCase;
  final DeleteDocumentUseCase deleteDocumentUseCase;
  final ReplaceDocumentUseCase replaceDocumentUseCase;
  final CreateCatalogEntityUseCase createCatalogEntityUseCase;

  Future<void> _onStarted(
    DmsStarted event,
    Emitter<DmsState> emit,
  ) async {
    emit(
      state.copyWith(
        level: DmsLevel.hub,
        status: DmsStatus.ready,
        clearSelectedEntity: true,
        documents: const [],
        clearError: true,
      ),
    );
  }

  void _onHubOpened(DmsHubOpened event, Emitter<DmsState> emit) {
    emit(
      state.copyWith(
        level: DmsLevel.hub,
        status: DmsStatus.ready,
        clearSelectedEntity: true,
        documents: const [],
        entities: const [],
        clearError: true,
      ),
    );
  }

  Future<void> _onEntityTypeSelected(
    DmsEntityTypeSelected event,
    Emitter<DmsState> emit,
  ) async {
    emit(
      state.copyWith(
        entityType: event.type,
        level: DmsLevel.entities,
        clearSelectedEntity: true,
        documents: const [],
        clearError: true,
      ),
    );
    await _loadEntities(emit, event.type);
  }

  Future<void> _onEntitySelected(
    DmsEntitySelected event,
    Emitter<DmsState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedEntity: event.entity,
        level: DmsLevel.documents,
        status: DmsStatus.loadingDocuments,
        clearError: true,
      ),
    );
    final result = await getDocumentsUseCase(
      entityType: event.entity.type,
      entityId: event.entity.id,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: DmsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (documents) => emit(
        state.copyWith(
          status: DmsStatus.ready,
          documents: documents,
        ),
      ),
    );
  }

  void _onSelectionCleared(
    DmsSelectionCleared event,
    Emitter<DmsState> emit,
  ) {
    emit(
      state.copyWith(
        level: DmsLevel.entities,
        clearSelectedEntity: true,
        documents: const [],
        clearError: true,
        status: DmsStatus.ready,
      ),
    );
  }

  Future<void> _onFilesSelected(
    DmsFilesSelected event,
    Emitter<DmsState> emit,
  ) async {
    final entity = state.selectedEntity;
    if (entity == null) {
      emit(
        state.copyWith(
          status: DmsStatus.failure,
          errorMessage: 'Select an entity first.',
        ),
      );
      return;
    }
    if (event.files.isEmpty) return;

    emit(state.copyWith(status: DmsStatus.saving, clearError: true));

    final uploaded = <DocumentRecord>[];
    String? firstError;
    for (final file in event.files) {
      if (file.bytes.isEmpty || file.fileName.trim().isEmpty) continue;
      final pick = DocumentPick(
        fileName: file.fileName,
        bytes: file.bytes,
        mimeType: file.mimeType,
      );
      final result = await addDocumentUseCase(
        entityType: entity.type,
        entityId: entity.id,
        entityName: entity.name,
        title: pick.title,
        fileName: file.fileName,
        category: pick.category,
        fileBytes: file.bytes,
        mimeType: file.mimeType,
      );
      result.fold(
        (failure) => firstError ??= failure.message,
        uploaded.add,
      );
    }

    if (uploaded.isEmpty) {
      emit(
        state.copyWith(
          status: DmsStatus.failure,
          errorMessage: firstError ?? 'Could not attach the selected files.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: DmsStatus.success,
        documents: [...uploaded, ...state.documents],
        errorMessage: firstError,
        clearError: firstError == null,
      ),
    );
  }

  Future<void> _onCatalogCreate(
    DmsCatalogEntityCreateRequested event,
    Emitter<DmsState> emit,
  ) async {
    emit(state.copyWith(status: DmsStatus.saving, clearError: true));
    final result = await createCatalogEntityUseCase(
      type: event.type,
      name: event.name,
      subtitle: event.subtitle,
    );
    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: DmsStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
      (entity) async {
        emit(
          state.copyWith(
            status: DmsStatus.ready,
            entities: [entity, ...state.entities],
            clearError: true,
          ),
        );
      },
    );
  }

  Future<void> _onDocumentDelete(
    DmsDocumentDeleteRequested event,
    Emitter<DmsState> emit,
  ) async {
    emit(state.copyWith(status: DmsStatus.saving, clearError: true));
    final result = await deleteDocumentUseCase(event.documentId);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: DmsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (_) => emit(
        state.copyWith(
          status: DmsStatus.ready,
          documents: [
            for (final doc in state.documents)
              if (doc.id != event.documentId) doc,
          ],
          clearError: true,
        ),
      ),
    );
  }

  Future<void> _onDocumentReplace(
    DmsDocumentReplaceRequested event,
    Emitter<DmsState> emit,
  ) async {
    emit(state.copyWith(status: DmsStatus.saving, clearError: true));
    final result = await replaceDocumentUseCase(
      existing: event.existing,
      fileName: event.fileName,
      fileBytes: event.fileBytes,
      mimeType: event.mimeType,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: DmsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (replaced) => emit(
        state.copyWith(
          status: DmsStatus.success,
          documents: [
            replaced,
            for (final doc in state.documents)
              if (doc.id != event.existing.id) doc,
          ],
          clearError: true,
        ),
      ),
    );
  }

  Future<void> _loadEntities(
    Emitter<DmsState> emit,
    DmsEntityType type,
  ) async {
    emit(state.copyWith(status: DmsStatus.loading, clearError: true));
    final result = await getDmsEntitiesUseCase(type);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: DmsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (entities) {
        emit(
          state.copyWith(
            status: DmsStatus.ready,
            entities: entities,
            clearSelectedEntity: true,
            documents: const [],
          ),
        );
      },
    );
  }
}
