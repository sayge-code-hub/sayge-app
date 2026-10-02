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

class DmsState extends Equatable {
  const DmsState({
    this.status = DmsStatus.initial,
    this.entityType = DmsEntityType.employee,
    this.entities = const [],
    this.selectedEntity,
    this.documents = const [],
    this.documentTitle = '',
    this.documentFileName = '',
    this.documentNotes = '',
    this.errorMessage,
    this.formEpoch = 0,
  });

  final DmsStatus status;
  final DmsEntityType entityType;
  final List<DmsEntity> entities;
  final DmsEntity? selectedEntity;
  final List<DocumentRecord> documents;
  final String documentTitle;
  final String documentFileName;
  final String documentNotes;
  final String? errorMessage;
  final int formEpoch;

  DmsState copyWith({
    DmsStatus? status,
    DmsEntityType? entityType,
    List<DmsEntity>? entities,
    DmsEntity? selectedEntity,
    bool clearSelectedEntity = false,
    List<DocumentRecord>? documents,
    String? documentTitle,
    String? documentFileName,
    String? documentNotes,
    String? errorMessage,
    bool clearError = false,
    bool clearForm = false,
  }) {
    return DmsState(
      status: status ?? this.status,
      entityType: entityType ?? this.entityType,
      entities: entities ?? this.entities,
      selectedEntity:
          clearSelectedEntity ? null : (selectedEntity ?? this.selectedEntity),
      documents: documents ?? this.documents,
      documentTitle: clearForm ? '' : (documentTitle ?? this.documentTitle),
      documentFileName:
          clearForm ? '' : (documentFileName ?? this.documentFileName),
      documentNotes: clearForm ? '' : (documentNotes ?? this.documentNotes),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      formEpoch: clearForm ? formEpoch + 1 : formEpoch,
    );
  }

  @override
  List<Object?> get props => [
        status,
        entityType,
        entities,
        selectedEntity,
        documents,
        documentTitle,
        documentFileName,
        documentNotes,
        errorMessage,
        formEpoch,
      ];
}
