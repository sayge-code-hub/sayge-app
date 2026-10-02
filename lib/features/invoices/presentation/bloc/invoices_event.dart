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
      ];
}

class InvoiceDownloadRequested extends InvoicesEvent {
  const InvoiceDownloadRequested(this.invoice);

  final Invoice invoice;

  @override
  List<Object?> get props => [invoice];
}
