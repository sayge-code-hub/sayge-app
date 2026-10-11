import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../entities/document_record.dart';
import '../repositories/document_repository.dart';

class ReplaceDocumentUseCase {
  const ReplaceDocumentUseCase(this._repository);

  final DocumentRepository _repository;

  Future<Either<Failure, DocumentRecord>> call({
    required DocumentRecord existing,
    required String fileName,
    required Uint8List fileBytes,
    String mimeType = 'application/octet-stream',
    String? title,
    String? category,
  }) {
    return _repository.replaceDocument(
      existing: existing,
      fileName: fileName,
      fileBytes: fileBytes,
      mimeType: mimeType,
      title: title,
      category: category,
    );
  }
}
