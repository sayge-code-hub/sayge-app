import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/dms_entity.dart';
import '../entities/document_record.dart';

abstract class DocumentRepository {
  Future<Either<Failure, List<DmsEntity>>> getEntities(DmsEntityType type);

  Future<Either<Failure, List<DocumentRecord>>> getDocuments({
    required DmsEntityType entityType,
    required String entityId,
  });

  Future<Either<Failure, DocumentRecord>> addDocument({
    required DmsEntityType entityType,
    required String entityId,
    required String entityName,
    required String title,
    required String fileName,
    required String category,
    String mimeType = 'application/octet-stream',
    int fileSizeBytes = 0,
    String notes = '',
  });
}
