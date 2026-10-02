import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/client.dart';
import '../repositories/client_repository.dart';

class AddClientUseCase {
  const AddClientUseCase(this._repository);

  final ClientRepository _repository;

  Future<Either<Failure, Client>> call(Client client) {
    return _repository.addClient(client);
  }
}
