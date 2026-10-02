import 'dms_entity.dart';

/// Document metadata stored in the DMS (file bytes live in storage).
class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.title,
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.storagePath,
    required this.notes,
    required this.uploadedAt,
  });

  final String id;
  final DmsEntityType entityType;
  final String entityId;
  final String entityName;
  final String title;
  final String fileName;
  final String mimeType;
  final int fileSizeBytes;
  final String storagePath;
  final String notes;
  final DateTime uploadedAt;
}
