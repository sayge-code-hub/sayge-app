part of 'dms_bloc.dart';

abstract class DmsEvent extends Equatable {
  const DmsEvent();

  @override
  List<Object?> get props => [];
}

class DmsStarted extends DmsEvent {
  const DmsStarted();
}

class DmsEntityTypeSelected extends DmsEvent {
  const DmsEntityTypeSelected(this.type);

  final DmsEntityType type;

  @override
  List<Object?> get props => [type];
}

class DmsEntitySelected extends DmsEvent {
  const DmsEntitySelected(this.entity);

  final DmsEntity entity;

  @override
  List<Object?> get props => [entity.id, entity.type];
}

class DmsSelectionCleared extends DmsEvent {
  const DmsSelectionCleared();
}

class DmsDocumentTitleChanged extends DmsEvent {
  const DmsDocumentTitleChanged(this.title);

  final String title;

  @override
  List<Object?> get props => [title];
}

class DmsDocumentFileNameChanged extends DmsEvent {
  const DmsDocumentFileNameChanged(this.fileName);

  final String fileName;

  @override
  List<Object?> get props => [fileName];
}

class DmsDocumentNotesChanged extends DmsEvent {
  const DmsDocumentNotesChanged(this.notes);

  final String notes;

  @override
  List<Object?> get props => [notes];
}

class DmsDocumentSubmitted extends DmsEvent {
  const DmsDocumentSubmitted();
}
