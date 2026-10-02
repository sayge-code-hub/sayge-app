import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/invoice.dart';
import '../repositories/invoice_repository.dart';

class GetInvoicesUseCase {
  const GetInvoicesUseCase(this._repository);

  final InvoiceRepository _repository;

  Future<Either<Failure, List<Invoice>>> call() => _repository.getInvoices();
}

class CreateInvoiceUseCase {
  const CreateInvoiceUseCase(this._repository);

  final InvoiceRepository _repository;

  Future<Either<Failure, Invoice>> call(Invoice invoice) {
    return _repository.createInvoice(invoice);
  }
}

class UpdateInvoiceUseCase {
  const UpdateInvoiceUseCase(this._repository);

  final InvoiceRepository _repository;

  Future<Either<Failure, Invoice>> call(Invoice invoice) {
    return _repository.updateInvoice(invoice);
  }
}
