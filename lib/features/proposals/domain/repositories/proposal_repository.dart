import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/proposal.dart';

abstract class ProposalRepository {
  Future<Either<Failure, List<Proposal>>> getProposals();

  Future<Either<Failure, Proposal>> getProposal(String id);

  Future<Either<Failure, Proposal>> createProposal(Proposal proposal);

  Future<Either<Failure, Proposal>> updateProposal(Proposal proposal);

  Future<Either<Failure, Proposal>> updateProposalStatus({
    required String id,
    required ProposalPoStatus status,
  });
}
