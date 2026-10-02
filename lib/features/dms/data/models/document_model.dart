import '../../domain/entities/dms_entity.dart';
import '../../domain/entities/document_record.dart';

class DocumentModel extends DocumentRecord {
  const DocumentModel({
    required super.id,
    required super.entityType,
    required super.entityId,
    required super.entityName,
    required super.title,
    required super.fileName,
    required super.mimeType,
    required super.fileSizeBytes,
    required super.storagePath,
    required super.notes,
    required super.category,
    required super.uploadedAt,
  });

  factory DocumentModel.fromEntity(DocumentRecord record) {
    return DocumentModel(
      id: record.id,
      entityType: record.entityType,
      entityId: record.entityId,
      entityName: record.entityName,
      title: record.title,
      fileName: record.fileName,
      mimeType: record.mimeType,
      fileSizeBytes: record.fileSizeBytes,
      storagePath: record.storagePath,
      notes: record.notes,
      category: record.category,
      uploadedAt: record.uploadedAt,
    );
  }

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    final category = (json['category'] ?? '').toString().trim();
    return DocumentModel(
      id: (json['id'] ?? '').toString(),
      entityType: DmsEntityType.fromStorage(
        (json['entity_type'] ?? 'company').toString(),
      ),
      entityId: (json['entity_id'] ?? '').toString(),
      entityName: (json['entity_name'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      fileName: (json['file_name'] ?? '').toString(),
      mimeType: (json['mime_type'] ?? 'application/octet-stream').toString(),
      fileSizeBytes: _asInt(json['file_size_bytes']),
      storagePath: (json['storage_path'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      category: category.isEmpty ? DmsDocumentCategories.fallback : category,
      uploadedAt: _asDate(json['uploaded_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity_type': entityType.storageValue,
      'entity_id': entityId,
      'entity_name': entityName,
      'title': title,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size_bytes': fileSizeBytes,
      'storage_path': storagePath,
      'notes': notes,
      'category': category,
      'uploaded_at': uploadedAt.toUtc().toIso8601String(),
    };
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
