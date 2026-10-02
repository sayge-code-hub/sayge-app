import '../../domain/entities/invoice.dart';

class InvoiceLineItemModel extends InvoiceLineItem {
  const InvoiceLineItemModel({
    required super.id,
    required super.particulars,
    required super.amount,
    super.sortOrder,
  });

  factory InvoiceLineItemModel.fromEntity(InvoiceLineItem item) {
    return InvoiceLineItemModel(
      id: item.id,
      particulars: item.particulars,
      amount: item.amount,
      sortOrder: item.sortOrder,
    );
  }

  factory InvoiceLineItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItemModel(
      id: (json['id'] ?? '').toString(),
      particulars: (json['particulars'] ?? '').toString(),
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toJson({required String invoiceId}) {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'sort_order': sortOrder,
      'particulars': particulars,
      'amount': amount,
    };
  }
}

class InvoiceModel extends Invoice {
  const InvoiceModel({
    required super.id,
    required super.invoiceNo,
    required super.invoiceDate,
    required super.poNumber,
    required super.placeOfSupply,
    required super.buyerName,
    required super.buyerCompany,
    required super.buyerAddress,
    required super.buyerGstin,
    required super.buyerContact,
    required super.intraState,
    required super.lineItems,
    required super.taxableAmount,
    required super.cgstAmount,
    required super.sgstAmount,
    required super.igstAmount,
    required super.totalAmount,
    required super.amountInWords,
  });

  factory InvoiceModel.fromEntity(Invoice invoice) {
    return InvoiceModel(
      id: invoice.id,
      invoiceNo: invoice.invoiceNo,
      invoiceDate: invoice.invoiceDate,
      poNumber: invoice.poNumber,
      placeOfSupply: invoice.placeOfSupply,
      buyerName: invoice.buyerName,
      buyerCompany: invoice.buyerCompany,
      buyerAddress: invoice.buyerAddress,
      buyerGstin: invoice.buyerGstin,
      buyerContact: invoice.buyerContact,
      intraState: invoice.intraState,
      lineItems: invoice.lineItems
          .map(InvoiceLineItemModel.fromEntity)
          .toList(growable: false),
      taxableAmount: invoice.taxableAmount,
      cgstAmount: invoice.cgstAmount,
      sgstAmount: invoice.sgstAmount,
      igstAmount: invoice.igstAmount,
      totalAmount: invoice.totalAmount,
      amountInWords: invoice.amountInWords,
    );
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      return DateTime.parse(value.toString());
    }

    final linesRaw = json['invoice_line_items'];
    final lines = <InvoiceLineItem>[];
    if (linesRaw is List) {
      for (final row in linesRaw) {
        if (row is Map<String, dynamic>) {
          lines.add(InvoiceLineItemModel.fromJson(row));
        }
      }
      lines.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    return InvoiceModel(
      id: (json['id'] ?? '').toString(),
      invoiceNo: (json['invoice_no'] ?? '').toString(),
      invoiceDate: parseDate(json['invoice_date']),
      poNumber: (json['po_number'] ?? '').toString(),
      placeOfSupply: (json['place_of_supply'] ?? '').toString(),
      buyerName: (json['buyer_name'] ?? '').toString(),
      buyerCompany: (json['buyer_company'] ?? '').toString(),
      buyerAddress: (json['buyer_address'] ?? '').toString(),
      buyerGstin: (json['buyer_gstin'] ?? '').toString(),
      buyerContact: (json['buyer_contact'] ?? '').toString(),
      intraState: json['intra_state'] == true || json['intra_state'] == 'true',
      lineItems: lines,
      taxableAmount: double.tryParse('${json['taxable_amount'] ?? 0}') ?? 0,
      cgstAmount: double.tryParse('${json['cgst_amount'] ?? 0}') ?? 0,
      sgstAmount: double.tryParse('${json['sgst_amount'] ?? 0}') ?? 0,
      igstAmount: double.tryParse('${json['igst_amount'] ?? 0}') ?? 0,
      totalAmount: double.tryParse('${json['total_amount'] ?? 0}') ?? 0,
      amountInWords: (json['amount_in_words'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toHeaderJson() {
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    return {
      'id': id,
      'invoice_no': invoiceNo,
      'invoice_date': ymd(invoiceDate),
      'po_number': poNumber,
      'place_of_supply': placeOfSupply,
      'buyer_name': buyerName,
      'buyer_company': buyerCompany,
      'buyer_address': buyerAddress,
      'buyer_gstin': buyerGstin,
      'buyer_contact': buyerContact,
      'intra_state': intraState,
      'taxable_amount': taxableAmount,
      'cgst_amount': cgstAmount,
      'sgst_amount': sgstAmount,
      'igst_amount': igstAmount,
      'total_amount': totalAmount,
      'amount_in_words': amountInWords,
    };
  }
}
