import 'package:flutter/foundation.dart';
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
    required String category,
    required Uint8List fileBytes,
    String mimeType = 'application/octet-stream',
    int fileSizeBytes = 0,
    String notes = '',
  });

  Future<String> getDownloadUrl(String storagePath);
}

class DocumentRemoteDataSourceImpl implements DocumentRemoteDataSource {
  DocumentRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _documentsTable = 'documents';
  static const _entitiesTable = 'dms_entities';
  static const _employeesTable = 'employees';
  static const _clientsTable = 'clients';
  static const _bucket = 'documents';

  @override
  Future<List<DmsEntity>> getEntities(DmsEntityType type) async {
    try {
      switch (type) {
        case DmsEntityType.employee:
          return _employees();
        case DmsEntityType.client:
          return _clients();
        case DmsEntityType.vendor:
        case DmsEntityType.candidate:
          return _catalogEntities(type);
      }
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to load DMS entities from Supabase.');
    }
  }

  Future<List<DmsEntity>> _employees() async {
    final rows = await _client
        .from(_employeesTable)
        .select('employee_id, employee_name, designation, is_active, photo_path')
        .order('employee_name');
    return (rows as List<dynamic>).map((row) {
      final map = row as Map<String, dynamic>;
      final designation = (map['designation'] ?? '').toString().trim();
      final active = map['is_active'] == true || map['is_active'] == 'true';
      final bits = <String>[
        if (designation.isNotEmpty) designation,
        if (!active) 'Inactive',
      ];
      final photoPath = (map['photo_path'] ?? '').toString().trim();
      return DmsEntity(
        id: (map['employee_id'] ?? '').toString(),
        name: (map['employee_name'] ?? '').toString(),
        type: DmsEntityType.employee,
        subtitle: bits.join(' · '),
        imageUrl: _employeePhotoUrl(photoPath),
      );
    }).toList();
  }

  String? _employeePhotoUrl(String path) {
    if (path.isEmpty) return null;
    final bucket = path.startsWith('documents/') ? 'documents' : 'employee-avatars';
    try {
      return _client.storage.from(bucket).getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  String? _brandLogoUrl(String path) {
    if (path.isEmpty) return null;
    final bucket = path.startsWith('documents/') ? 'documents' : 'brand-logos';
    try {
      return _client.storage.from(bucket).getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  Future<List<DmsEntity>> _clients() async {
    final rows = await _client
        .from(_clientsTable)
        .select('id, name, contact_name, vendor_code, logo_path')
        .order('name');
    return (rows as List<dynamic>).map((row) {
      final map = row as Map<String, dynamic>;
      final contact = (map['contact_name'] ?? '').toString().trim();
      final vendor = (map['vendor_code'] ?? '').toString().trim();
      final bits = <String>[
        if (contact.isNotEmpty) contact,
        if (vendor.isNotEmpty) vendor,
      ];
      final logoPath = (map['logo_path'] ?? '').toString().trim();
      return DmsEntity(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        type: DmsEntityType.client,
        subtitle: bits.join(' · '),
        imageUrl: _brandLogoUrl(logoPath),
      );
    }).toList();
  }

  Future<List<DmsEntity>> _catalogEntities(DmsEntityType type) async {
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
    required String category,
    required Uint8List fileBytes,
    String mimeType = 'application/octet-stream',
    int fileSizeBytes = 0,
    String notes = '',
  }) async {
    final trimmedTitle = title.trim();
    final trimmedFile = fileName.trim();
    final trimmedCategory = category.trim().isEmpty
        ? DmsDocumentCategories.fallback
        : category.trim();
    if (trimmedTitle.isEmpty) {
      throw const ServerException('Document title is required.');
    }
    if (trimmedFile.isEmpty || fileBytes.isEmpty) {
      throw const ServerException('Choose at least one file to attach.');
    }

    final safeFile = trimmedFile.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final id =
        'doc-${entityType.storageValue}-$entityId-${DateTime.now().microsecondsSinceEpoch}';
    final path =
        'documents/${entityType.storageValue}/$entityId/${id}_$safeFile';
    final resolvedMime =
        mimeType.trim().isEmpty ? 'application/octet-stream' : mimeType.trim();
    final payload = {
      'id': id,
      'entity_type': entityType.storageValue,
      'entity_id': entityId,
      'entity_name': entityName,
      'title': trimmedTitle,
      'file_name': safeFile,
      'mime_type': resolvedMime,
      'file_size_bytes': fileSizeBytes > 0 ? fileSizeBytes : fileBytes.length,
      'storage_path': path,
      'notes': notes.trim(),
      'category': trimmedCategory,
      'uploaded_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _client.storage.from(_bucket).uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(
              contentType: resolvedMime,
              upsert: false,
            ),
          );
      final row = await _client
          .from(_documentsTable)
          .insert(payload)
          .select()
          .single();
      return DocumentModel.fromJson(row);
    } on StorageException catch (e) {
      throw ServerException(e.message);
    } on PostgrestException catch (e) {
      try {
        await _client.storage.from(_bucket).remove([path]);
      } catch (_) {}
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to add document.');
    }
  }

  @override
  Future<String> getDownloadUrl(String storagePath) async {
    final path = storagePath.trim();
    if (path.isEmpty) {
      throw const ServerException('No file is attached to this document.');
    }
    try {
      // Signed URL fails when the object is missing from the bucket.
      return await _client.storage.from(_bucket).createSignedUrl(path, 3600);
    } on StorageException catch (e) {
      final message = e.message.trim();
      if (message.isEmpty) {
        throw const ServerException(
          'File is not available in storage yet. Upload the document to view it.',
        );
      }
      throw ServerException(message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to get document link.');
    }
  }
}
