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
