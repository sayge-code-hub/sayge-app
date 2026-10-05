import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/proposal.dart';
import '../repositories/proposal_repository.dart';

class GetProposalsUseCase {
  const GetProposalsUseCase(this._repository);

  final ProposalRepository _repository;

  Future<Either<Failure, List<Proposal>>> call() {
    return _repository.getProposals();
  }
}

class GetProposalUseCase {
  const GetProposalUseCase(this._repository);

  final ProposalRepository _repository;

  Future<Either<Failure, Proposal>> call(String id) {
    return _repository.getProposal(id);
  }
}

class CreateProposalUseCase {
  const CreateProposalUseCase(this._repository);

  final ProposalRepository _repository;

  Future<Either<Failure, Proposal>> call(Proposal proposal) {
    return _repository.createProposal(proposal);
  }
}

class UpdateProposalUseCase {
  const UpdateProposalUseCase(this._repository);

  final ProposalRepository _repository;

  Future<Either<Failure, Proposal>> call(Proposal proposal) {
    return _repository.updateProposal(proposal);
  }
}

class UpdateProposalStatusUseCase {
  const UpdateProposalStatusUseCase(this._repository);

  final ProposalRepository _repository;

  Future<Either<Failure, Proposal>> call({
    required String id,
    required ProposalPoStatus status,
  }) {
    return _repository.updateProposalStatus(id: id, status: status);
  }
}
