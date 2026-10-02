import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/dms_entity.dart';
import '../repositories/document_repository.dart';

class GetDmsEntitiesUseCase {
  const GetDmsEntitiesUseCase(this._repository);

  final DocumentRepository _repository;

  Future<Either<Failure, List<DmsEntity>>> call(DmsEntityType type) {
    return _repository.getEntities(type);
  }
}
