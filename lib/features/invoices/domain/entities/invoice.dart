import 'package:equatable/equatable.dart';

class InvoiceLineItem extends Equatable {
  const InvoiceLineItem({
    required this.id,
    required this.particulars,
    required this.amount,
    this.sortOrder = 0,
  });

  final String id;
  final String particulars;
  final double amount;
  final int sortOrder;

  @override
  List<Object?> get props => [id, particulars, amount, sortOrder];
}

class Invoice extends Equatable {
  const Invoice({
    required this.id,
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
    required this.lineItems,
    required this.taxableAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.totalAmount,
    required this.amountInWords,
  });

  final String id;
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
  final List<InvoiceLineItem> lineItems;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalAmount;
  final String amountInWords;

  @override
  List<Object?> get props => [id, invoiceNo, invoiceDate, totalAmount, lineItems];
}
