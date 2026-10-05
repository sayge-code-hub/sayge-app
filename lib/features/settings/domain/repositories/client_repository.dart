import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/client.dart';

abstract class ClientRepository {
  Future<Either<Failure, List<Client>>> getClients();

  Future<Either<Failure, Client>> addClient(Client client);

  Future<Either<Failure, Client>> updateClient(Client client);

  Future<Either<Failure, Client>> setClientActive({
    required String id,
    required bool isActive,
  });

  Future<Either<Failure, void>> deleteClient(String id);
}
