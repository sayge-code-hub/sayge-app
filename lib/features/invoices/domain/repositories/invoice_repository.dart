import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/invoice.dart';

abstract class InvoiceRepository {
  Future<Either<Failure, List<Invoice>>> getInvoices();

  Future<Either<Failure, Invoice>> createInvoice(Invoice invoice);

  Future<Either<Failure, Invoice>> updateInvoice(Invoice invoice);
}
