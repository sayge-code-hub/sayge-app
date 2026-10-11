part of 'invoices_bloc.dart';

abstract class InvoicesEvent extends Equatable {
  const InvoicesEvent();

  @override
  List<Object?> get props => [];
}

class InvoicesStarted extends InvoicesEvent {
  const InvoicesStarted();
}

class InvoiceListRequested extends InvoicesEvent {
  const InvoiceListRequested();
}

class InvoiceFormOpened extends InvoicesEvent {
  const InvoiceFormOpened();
}

class InvoiceEditOpened extends InvoicesEvent {
  const InvoiceEditOpened(this.invoice);

  final Invoice invoice;

  @override
  List<Object?> get props => [invoice];
}

class InvoiceCloneOpened extends InvoicesEvent {
  const InvoiceCloneOpened(this.invoice);

  final Invoice invoice;

  @override
  List<Object?> get props => [invoice];
}

/// Opens a new invoice draft prefilled from a proposal (quote → invoice).
class InvoiceFromProposalOpened extends InvoicesEvent {
  const InvoiceFromProposalOpened(this.proposal);

  final Proposal proposal;

  @override
  List<Object?> get props => [proposal];
}

class InvoiceDraftLine extends Equatable {
  const InvoiceDraftLine({
    required this.particulars,
    required this.amount,
  });

  final String particulars;
  final String amount;

  @override
  List<Object?> get props => [particulars, amount];
}

class InvoiceSubmitted extends InvoicesEvent {
  const InvoiceSubmitted({
    required this.invoiceNo,
    required this.invoiceDate,
    required this.poNumber,
    required this.placeOfSupply,
    required this.buyerName,
    required this.buyerCompany,
    required this.buyerAddress,
    required this.buyerGstin,
    required this.buyerContact,
    required this.intraState,
    required this.lines,
    this.paymentStatus = InvoicePaymentStatus.unpaid,
    this.amountPaid = 0,
    this.dueDate,
    this.paidAt,
  });

  final String invoiceNo;
  final DateTime invoiceDate;
  final String poNumber;
  final String placeOfSupply;
  final String buyerName;
  final String buyerCompany;
  final String buyerAddress;
  final String buyerGstin;
  final String buyerContact;
  final bool intraState;
  final List<InvoiceDraftLine> lines;
  final InvoicePaymentStatus paymentStatus;
  final double amountPaid;
  final DateTime? dueDate;
  final DateTime? paidAt;

  @override
  List<Object?> get props => [
        invoiceNo,
        invoiceDate,
        poNumber,
        placeOfSupply,
        buyerName,
        buyerCompany,
        buyerAddress,
        buyerGstin,
        buyerContact,
        intraState,
        lines,
        paymentStatus,
        amountPaid,
        dueDate,
        paidAt,
      ];
}

class InvoiceDownloadRequested extends InvoicesEvent {
  const InvoiceDownloadRequested(this.invoice);

  final Invoice invoice;

  @override
  List<Object?> get props => [invoice];
}

class InvoicePaymentUpdated extends InvoicesEvent {
  const InvoicePaymentUpdated({
    required this.invoice,
    required this.paymentStatus,
    required this.amountPaid,
    this.dueDate,
    this.paidAt,
    this.clearDueDate = false,
    this.clearPaidAt = false,
  });

  final Invoice invoice;
  final InvoicePaymentStatus paymentStatus;
  final double amountPaid;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final bool clearDueDate;
  final bool clearPaidAt;

  @override
  List<Object?> get props => [
        invoice,
        paymentStatus,
        amountPaid,
        dueDate,
        paidAt,
        clearDueDate,
        clearPaidAt,
      ];
}
