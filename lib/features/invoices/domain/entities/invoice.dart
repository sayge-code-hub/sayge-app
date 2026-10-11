import 'package:equatable/equatable.dart';

import 'invoice_payment_status.dart';

export 'invoice_payment_status.dart';

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
    this.paymentStatus = InvoicePaymentStatus.unpaid,
    this.amountPaid = 0,
    this.dueDate,
    this.paidAt,
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
  final InvoicePaymentStatus paymentStatus;
  final double amountPaid;
  final DateTime? dueDate;
  final DateTime? paidAt;

  /// Display status including aging (overdue when past due).
  InvoicePaymentStatus displayPaymentStatus({DateTime? today}) {
    return InvoicePaymentStatus.effective(
      stored: paymentStatus,
      dueDate: dueDate,
      today: today,
    );
  }

  bool get isPaymentOverdue => InvoicePaymentStatus.isOverdue(
        stored: paymentStatus,
        dueDate: dueDate,
      );

  Invoice copyWith({
    String? id,
    String? invoiceNo,
    DateTime? invoiceDate,
    String? poNumber,
    String? placeOfSupply,
    String? buyerName,
    String? buyerCompany,
    String? buyerAddress,
    String? buyerGstin,
    String? buyerContact,
    bool? intraState,
    List<InvoiceLineItem>? lineItems,
    double? taxableAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    double? totalAmount,
    String? amountInWords,
    InvoicePaymentStatus? paymentStatus,
    double? amountPaid,
    DateTime? dueDate,
    DateTime? paidAt,
    bool clearDueDate = false,
    bool clearPaidAt = false,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      poNumber: poNumber ?? this.poNumber,
      placeOfSupply: placeOfSupply ?? this.placeOfSupply,
      buyerName: buyerName ?? this.buyerName,
      buyerCompany: buyerCompany ?? this.buyerCompany,
      buyerAddress: buyerAddress ?? this.buyerAddress,
      buyerGstin: buyerGstin ?? this.buyerGstin,
      buyerContact: buyerContact ?? this.buyerContact,
      intraState: intraState ?? this.intraState,
      lineItems: lineItems ?? this.lineItems,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      igstAmount: igstAmount ?? this.igstAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      amountInWords: amountInWords ?? this.amountInWords,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amountPaid: amountPaid ?? this.amountPaid,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
    );
  }

  @override
  List<Object?> get props => [
        id,
        invoiceNo,
        invoiceDate,
        totalAmount,
        lineItems,
        paymentStatus,
        amountPaid,
        dueDate,
        paidAt,
      ];
}
