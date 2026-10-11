import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/dms_entity.dart';
import '../repositories/document_repository.dart';

class CreateCatalogEntityUseCase {
  const CreateCatalogEntityUseCase(this._repository);

  final DocumentRepository _repository;

  Future<Either<Failure, DmsEntity>> call({
    required DmsEntityType type,
    required String name,
    String subtitle = '',
  }) {
    return _repository.createCatalogEntity(
      type: type,
      name: name,
      subtitle: subtitle,
    );
  }
}
