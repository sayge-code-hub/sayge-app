import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/proposal.dart';
import '../../domain/repositories/proposal_repository.dart';
import '../datasources/proposal_remote_datasource.dart';
import '../models/proposal_model.dart';

class ProposalRepositoryImpl implements ProposalRepository {
  const ProposalRepositoryImpl({required this.remoteDataSource});

  final ProposalRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<Proposal>>> getProposals() async {
    try {
      final list = await remoteDataSource.getProposals();
      return Right(list);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to load proposals.'));
    }
  }

  @override
  Future<Either<Failure, Proposal>> getProposal(String id) async {
    try {
      final item = await remoteDataSource.getProposal(id);
      return Right(item);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to load proposal.'));
    }
  }

  @override
  Future<Either<Failure, Proposal>> createProposal(Proposal proposal) async {
    try {
      final created = await remoteDataSource.createProposal(
        ProposalModel.fromEntity(proposal),
      );
      return Right(created);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to create proposal.'));
    }
  }

  @override
  Future<Either<Failure, Proposal>> updateProposal(Proposal proposal) async {
    try {
      final updated = await remoteDataSource.updateProposal(
        ProposalModel.fromEntity(proposal),
      );
      return Right(updated);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to update proposal.'));
    }
  }

  @override
  Future<Either<Failure, Proposal>> updateProposalStatus({
    required String id,
    required ProposalPoStatus status,
  }) async {
    try {
      final updated = await remoteDataSource.updateProposalStatus(
        id: id,
        status: status,
      );
      return Right(updated);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to update proposal status.'));
    }
  }
}
