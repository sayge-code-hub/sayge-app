part of 'dms_bloc.dart';

enum DmsStatus {
  initial,
  loading,
  loadingDocuments,
  ready,
  saving,
  success,
  failure,
}

/// Hub (tiles) → entity list → documents for one entity.
enum DmsLevel { hub, entities, documents }

class DmsState extends Equatable {
  const DmsState({
    this.status = DmsStatus.initial,
    this.level = DmsLevel.hub,
    this.entityType = DmsEntityType.employee,
    this.entities = const [],
    this.selectedEntity,
    this.documents = const [],
    this.errorMessage,
  });

  final DmsStatus status;
  final DmsLevel level;
  final DmsEntityType entityType;
  final List<DmsEntity> entities;
  final DmsEntity? selectedEntity;
  final List<DocumentRecord> documents;
  final String? errorMessage;

  DmsState copyWith({
    DmsStatus? status,
    DmsLevel? level,
    DmsEntityType? entityType,
    List<DmsEntity>? entities,
    DmsEntity? selectedEntity,
    bool clearSelectedEntity = false,
    List<DocumentRecord>? documents,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DmsState(
      status: status ?? this.status,
      level: level ?? this.level,
      entityType: entityType ?? this.entityType,
      entities: entities ?? this.entities,
      selectedEntity:
          clearSelectedEntity ? null : (selectedEntity ?? this.selectedEntity),
      documents: documents ?? this.documents,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        level,
        entityType,
        entities,
        selectedEntity,
        documents,
        errorMessage,
      ];
}
