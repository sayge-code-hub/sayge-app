import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/document_record.dart';
import '../repositories/document_repository.dart';

class GetDocumentDownloadUrlUseCase {
  const GetDocumentDownloadUrlUseCase(this._repository);

  final DocumentRepository _repository;

  Future<Either<Failure, String>> call(DocumentRecord document) {
    return _repository.getDownloadUrl(document);
  }
}
