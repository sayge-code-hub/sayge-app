import 'package:equatable/equatable.dart';

class ProposalLineItem extends Equatable {
  const ProposalLineItem({
    required this.id,
    required this.description,
    required this.monthlyRate,
    required this.months,
    required this.days,
    required this.totalRate,
    this.sortOrder = 0,
  });

  final String id;
  final String description;
  final double monthlyRate;
  final int months;
  final int days;
  final double totalRate;
  final int sortOrder;

  ProposalLineItem copyWith({
    String? id,
    String? description,
    double? monthlyRate,
    int? months,
    int? days,
    double? totalRate,
    int? sortOrder,
  }) {
    return ProposalLineItem(
      id: id ?? this.id,
      description: description ?? this.description,
      monthlyRate: monthlyRate ?? this.monthlyRate,
      months: months ?? this.months,
      days: days ?? this.days,
      totalRate: totalRate ?? this.totalRate,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [
        id,
        description,
        monthlyRate,
        months,
        days,
        totalRate,
        sortOrder,
      ];
}

class Proposal extends Equatable {
  const Proposal({
    required this.id,
    required this.referenceNo,
    required this.quoteDate,
    required this.expiryDate,
    required this.placeOfSupply,
    required this.vendorCode,
    required this.entityCode,
    required this.billToName,
    required this.billToCompany,
    required this.billToAddress,
    required this.billToGstin,
    required this.shipToName,
    required this.shipToCompany,
    required this.shipToAddress,
    required this.shipToGstin,
    required this.notes,
    required this.lineItems,
    required this.subtotal,
    required this.totalInWords,
  });

  final String id;
  final String referenceNo;
  final DateTime quoteDate;
  final DateTime expiryDate;
  final String placeOfSupply;
  final String vendorCode;
  final String entityCode;
  final String billToName;
  final String billToCompany;
  final String billToAddress;
  final String billToGstin;
  final String shipToName;
  final String shipToCompany;
  final String shipToAddress;
  final String shipToGstin;
  final String notes;
  final List<ProposalLineItem> lineItems;
  final double subtotal;
  final String totalInWords;

  @override
  List<Object?> get props => [
        id,
        referenceNo,
        quoteDate,
        expiryDate,
        subtotal,
        lineItems,
      ];
}
