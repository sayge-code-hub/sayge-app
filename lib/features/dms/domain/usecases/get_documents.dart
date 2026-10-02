import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/dms_entity.dart';
import '../entities/document_record.dart';
import '../repositories/document_repository.dart';

class GetDocumentsUseCase {
  const GetDocumentsUseCase(this._repository);

  final DocumentRepository _repository;

  Future<Either<Failure, List<DocumentRecord>>> call({
    required DmsEntityType entityType,
    required String entityId,
  }) {
    return _repository.getDocuments(
      entityType: entityType,
      entityId: entityId,
    );
  }
}
