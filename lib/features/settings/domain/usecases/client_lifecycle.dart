import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/client.dart';
import '../repositories/client_repository.dart';

class UpdateClientUseCase {
  const UpdateClientUseCase(this._repository);

  final ClientRepository _repository;

  Future<Either<Failure, Client>> call(Client client) {
    return _repository.updateClient(client);
  }
}

class SetClientActiveUseCase {
  const SetClientActiveUseCase(this._repository);

  final ClientRepository _repository;

  Future<Either<Failure, Client>> call({
    required String id,
    required bool isActive,
  }) {
    return _repository.setClientActive(id: id, isActive: isActive);
  }
}

class DeleteClientUseCase {
  const DeleteClientUseCase(this._repository);

  final ClientRepository _repository;

  Future<Either<Failure, void>> call(String id) {
    return _repository.deleteClient(id);
  }
}
