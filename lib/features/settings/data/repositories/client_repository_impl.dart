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
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Client>> addClient(String name) async {
    try {
      final created = await remoteDataSource.addClient(name);
      return Right(created);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }
}
