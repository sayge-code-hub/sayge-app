import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/client.dart';
import '../../domain/repositories/client_repository.dart';
import '../datasources/client_remote_datasource.dart';

class ClientRepositoryImpl implements ClientRepository {
  const ClientRepositoryImpl({required this.remoteDataSource});

  final ClientRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<Client>>> getClients() async {
    try {
      final clients = await remoteDataSource.getClients();
      return Right(clients);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to load clients.'));
    }
  }

  @override
  Future<Either<Failure, Client>> addClient(Client client) async {
    try {
      final created = await remoteDataSource.addClient(client);
      return Right(created);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to add client.'));
    }
  }

  @override
  Future<Either<Failure, Client>> updateClient(Client client) async {
    try {
      final updated = await remoteDataSource.updateClient(client);
      return Right(updated);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to update client.'));
    }
  }

  @override
  Future<Either<Failure, Client>> setClientActive({
    required String id,
    required bool isActive,
  }) async {
    try {
      final updated = await remoteDataSource.setClientActive(
        id: id,
        isActive: isActive,
      );
      return Right(updated);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to update client.'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteClient(String id) async {
    try {
      await remoteDataSource.deleteClient(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to delete client.'));
    }
  }
}
