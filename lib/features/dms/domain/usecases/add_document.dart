import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../entities/dms_entity.dart';
import '../entities/document_record.dart';
import '../repositories/document_repository.dart';

class AddDocumentUseCase {
  const AddDocumentUseCase(this._repository);

  final DocumentRepository _repository;

  Future<Either<Failure, DocumentRecord>> call({
    required DmsEntityType entityType,
    required String entityId,
    required String entityName,
    required String title,
    required String fileName,
    required String category,
    required Uint8List fileBytes,
    String mimeType = 'application/octet-stream',
    String notes = '',
  }) {
    return _repository.addDocument(
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      title: title,
      fileName: fileName,
      category: category,
      fileBytes: fileBytes,
      mimeType: mimeType,
      fileSizeBytes: fileBytes.length,
      notes: notes,
    );
  }
}
