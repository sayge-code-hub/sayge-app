import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/dms_entity.dart';
import '../models/document_model.dart';

abstract class DocumentRemoteDataSource {
  Future<List<DmsEntity>> getEntities(DmsEntityType type);

  Future<List<DocumentModel>> getDocuments({
    required DmsEntityType entityType,
    required String entityId,
  });

  Future<DocumentModel> addDocument({
    required DmsEntityType entityType,
    required String entityId,
    required String entityName,
    required String title,
    required String fileName,
    String mimeType = 'application/octet-stream',
    int fileSizeBytes = 0,
    String notes = '',
  });
}

class DocumentRemoteDataSourceImpl implements DocumentRemoteDataSource {
  DocumentRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _documentsTable = 'documents';
  static const _entitiesTable = 'dms_entities';

  @override
  Future<List<DmsEntity>> getEntities(DmsEntityType type) async {
    try {
      final rows = await _client
          .from(_entitiesTable)
          .select()
          .eq('entity_type', type.storageValue)
          .order('name');
      return (rows as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        return DmsEntity(
          id: (map['id'] ?? '').toString(),
          name: (map['name'] ?? '').toString(),
          type: DmsEntityType.fromStorage(
            (map['entity_type'] ?? type.storageValue).toString(),
          ),
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load DMS entities from Supabase.');
    }
  }

  @override
  Future<List<DocumentModel>> getDocuments({
    required DmsEntityType entityType,
    required String entityId,
  }) async {
    try {
      final rows = await _client
          .from(_documentsTable)
          .select()
          .eq('entity_type', entityType.storageValue)
          .eq('entity_id', entityId)
          .order('uploaded_at', ascending: false);
      return (rows as List<dynamic>)
          .map((row) => DocumentModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load documents from Supabase.');
    }
  }

  @override
  Future<DocumentModel> addDocument({
    required DmsEntityType entityType,
    required String entityId,
    required String entityName,
    required String title,
    required String fileName,
    String mimeType = 'application/octet-stream',
    int fileSizeBytes = 0,
    String notes = '',
  }) async {
    final trimmedTitle = title.trim();
    final trimmedFile = fileName.trim();
    if (trimmedTitle.isEmpty) {
      throw const ServerException('Document title is required.');
    }
    if (trimmedFile.isEmpty) {
      throw const ServerException('File name is required.');
    }

    final id =
        'doc-${entityType.storageValue}-$entityId-${DateTime.now().millisecondsSinceEpoch}';
    final path =
        'documents/${entityType.storageValue}/$entityId/$trimmedFile';
    final payload = {
      'id': id,
      'entity_type': entityType.storageValue,
      'entity_id': entityId,
      'entity_name': entityName,
      'title': trimmedTitle,
      'file_name': trimmedFile,
      'mime_type':
          mimeType.trim().isEmpty ? 'application/octet-stream' : mimeType,
      'file_size_bytes': fileSizeBytes,
      'storage_path': path,
      'notes': notes.trim(),
      'uploaded_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final row = await _client
          .from(_documentsTable)
          .insert(payload)
          .select()
          .single();
      return DocumentModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to add document.');
    }
  }
}
