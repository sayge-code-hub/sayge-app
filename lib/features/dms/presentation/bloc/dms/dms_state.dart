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
    this.documentTitle = '',
    this.documentFileName = '',
    this.documentNotes = '',
    this.documentCategory = DmsDocumentCategories.fallback,
    this.errorMessage,
    this.formEpoch = 0,
  });

  final DmsStatus status;
  final DmsLevel level;
  final DmsEntityType entityType;
  final List<DmsEntity> entities;
  final DmsEntity? selectedEntity;
  final List<DocumentRecord> documents;
  final String documentTitle;
  final String documentFileName;
  final String documentNotes;
  final String documentCategory;
  final String? errorMessage;
  final int formEpoch;

  /// Documents grouped by category for the detail panel.
  Map<String, List<DocumentRecord>> get documentsByCategory {
    final map = <String, List<DocumentRecord>>{};
    for (final doc in documents) {
      final key = doc.category.trim().isEmpty
          ? DmsDocumentCategories.fallback
          : doc.category.trim();
      map.putIfAbsent(key, () => []).add(doc);
    }
    final ordered = <String, List<DocumentRecord>>{};
    for (final category in DmsDocumentCategories.all) {
      final list = map.remove(category);
      if (list != null && list.isNotEmpty) ordered[category] = list;
    }
    for (final entry in map.entries) {
      ordered[entry.key] = entry.value;
    }
    return ordered;
  }

  DmsState copyWith({
    DmsStatus? status,
    DmsLevel? level,
    DmsEntityType? entityType,
    List<DmsEntity>? entities,
    DmsEntity? selectedEntity,
    bool clearSelectedEntity = false,
    List<DocumentRecord>? documents,
    String? documentTitle,
    String? documentFileName,
    String? documentNotes,
    String? documentCategory,
    String? errorMessage,
    bool clearError = false,
    bool clearForm = false,
  }) {
    return DmsState(
      status: status ?? this.status,
      level: level ?? this.level,
      entityType: entityType ?? this.entityType,
      entities: entities ?? this.entities,
      selectedEntity:
          clearSelectedEntity ? null : (selectedEntity ?? this.selectedEntity),
      documents: documents ?? this.documents,
      documentTitle: clearForm ? '' : (documentTitle ?? this.documentTitle),
      documentFileName:
          clearForm ? '' : (documentFileName ?? this.documentFileName),
      documentNotes: clearForm ? '' : (documentNotes ?? this.documentNotes),
      documentCategory: clearForm
          ? DmsDocumentCategories.fallback
          : (documentCategory ?? this.documentCategory),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      formEpoch: clearForm ? formEpoch + 1 : formEpoch,
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
        documentTitle,
        documentFileName,
        documentNotes,
        documentCategory,
        errorMessage,
        formEpoch,
      ];
}
