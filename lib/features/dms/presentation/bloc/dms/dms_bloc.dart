import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/dms_entity.dart';
import '../../../domain/entities/document_record.dart';
import '../../../domain/usecases/add_document.dart';
import '../../../domain/usecases/get_dms_entities.dart';
import '../../../domain/usecases/get_documents.dart';

part 'dms_event.dart';
part 'dms_state.dart';

class DmsBloc extends Bloc<DmsEvent, DmsState> {
  DmsBloc({
    required this.getDmsEntitiesUseCase,
    required this.getDocumentsUseCase,
    required this.addDocumentUseCase,
  }) : super(const DmsState()) {
    on<DmsStarted>(_onStarted);
    on<DmsEntityTypeSelected>(_onEntityTypeSelected);
    on<DmsEntitySelected>(_onEntitySelected);
    on<DmsSelectionCleared>(_onSelectionCleared);
    on<DmsDocumentTitleChanged>(_onTitleChanged);
    on<DmsDocumentFileNameChanged>(_onFileNameChanged);
    on<DmsDocumentNotesChanged>(_onNotesChanged);
    on<DmsDocumentSubmitted>(_onSubmitted);
  }

  final GetDmsEntitiesUseCase getDmsEntitiesUseCase;
  final GetDocumentsUseCase getDocumentsUseCase;
  final AddDocumentUseCase addDocumentUseCase;

  Future<void> _onStarted(
    DmsStarted event,
    Emitter<DmsState> emit,
  ) async {
    await _loadEntities(emit, state.entityType);
  }

  Future<void> _onEntityTypeSelected(
    DmsEntityTypeSelected event,
    Emitter<DmsState> emit,
  ) async {
    if (event.type == state.entityType && state.entities.isNotEmpty) {
      return;
    }
    emit(
      state.copyWith(
        entityType: event.type,
        clearSelectedEntity: true,
        documents: const [],
        clearError: true,
        clearForm: true,
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
        status: DmsStatus.loadingDocuments,
        clearError: true,
        clearForm: true,
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
        clearSelectedEntity: true,
        documents: const [],
        clearError: true,
        clearForm: true,
        status: DmsStatus.ready,
      ),
    );
  }

  void _onTitleChanged(
    DmsDocumentTitleChanged event,
    Emitter<DmsState> emit,
  ) {
    emit(
      state.copyWith(
        documentTitle: event.title,
        clearError: true,
        status: DmsStatus.ready,
      ),
    );
  }

  void _onFileNameChanged(
    DmsDocumentFileNameChanged event,
    Emitter<DmsState> emit,
  ) {
    emit(
      state.copyWith(
        documentFileName: event.fileName,
        clearError: true,
        status: DmsStatus.ready,
      ),
    );
  }

  void _onNotesChanged(
    DmsDocumentNotesChanged event,
    Emitter<DmsState> emit,
  ) {
    emit(
      state.copyWith(
        documentNotes: event.notes,
        clearError: true,
        status: DmsStatus.ready,
      ),
    );
  }

  Future<void> _onSubmitted(
    DmsDocumentSubmitted event,
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
    if (state.documentTitle.trim().isEmpty) {
      emit(
        state.copyWith(
          status: DmsStatus.failure,
          errorMessage: 'Document title is required',
        ),
      );
      return;
    }
    if (state.documentFileName.trim().isEmpty) {
      emit(
        state.copyWith(
          status: DmsStatus.failure,
          errorMessage: 'File name is required',
        ),
      );
      return;
    }

    emit(state.copyWith(status: DmsStatus.saving, clearError: true));
    final result = await addDocumentUseCase(
      entityType: entity.type,
      entityId: entity.id,
      entityName: entity.name,
      title: state.documentTitle,
      fileName: state.documentFileName,
      notes: state.documentNotes,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: DmsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (document) {
        final updated = [document, ...state.documents];
        emit(
          state.copyWith(
            status: DmsStatus.success,
            documents: updated,
            clearForm: true,
          ),
        );
      },
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
