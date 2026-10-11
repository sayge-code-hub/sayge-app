part of 'dms_bloc.dart';

abstract class DmsEvent extends Equatable {
  const DmsEvent();

  @override
  List<Object?> get props => [];
}

class DmsStarted extends DmsEvent {
  const DmsStarted();
}

class DmsHubOpened extends DmsEvent {
  const DmsHubOpened();
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

class DmsPickedFile {
  const DmsPickedFile({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
  });

  final String fileName;
  final Uint8List bytes;
  final String mimeType;
}

class DmsFilesSelected extends DmsEvent {
  const DmsFilesSelected(this.files);

  final List<DmsPickedFile> files;

  @override
  List<Object?> get props => [
        for (final file in files) '${file.fileName}:${file.bytes.length}',
      ];
}

class DmsCatalogEntityCreateRequested extends DmsEvent {
  const DmsCatalogEntityCreateRequested({
    required this.type,
    required this.name,
    this.subtitle = '',
  });

  final DmsEntityType type;
  final String name;
  final String subtitle;

  @override
  List<Object?> get props => [type, name, subtitle];
}

class DmsDocumentDeleteRequested extends DmsEvent {
  const DmsDocumentDeleteRequested(this.documentId);

  final String documentId;

  @override
  List<Object?> get props => [documentId];
}

class DmsDocumentReplaceRequested extends DmsEvent {
  const DmsDocumentReplaceRequested({
    required this.existing,
    required this.fileName,
    required this.fileBytes,
    this.mimeType = 'application/octet-stream',
  });

  final DocumentRecord existing;
  final String fileName;
  final Uint8List fileBytes;
  final String mimeType;

  @override
  List<Object?> get props => [existing.id, fileName, fileBytes.length, mimeType];
}
