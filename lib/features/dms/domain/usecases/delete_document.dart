import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/document_repository.dart';

class DeleteDocumentUseCase {
  const DeleteDocumentUseCase(this._repository);

  final DocumentRepository _repository;

  Future<Either<Failure, void>> call(String documentId) {
    return _repository.deleteDocument(documentId);
  }
}
