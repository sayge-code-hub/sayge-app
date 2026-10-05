import 'package:equatable/equatable.dart';

/// Lifecycle of a proposal / PO in the list.
enum ProposalPoStatus {
  active,
  archived;

  bool get isMuted => this == ProposalPoStatus.archived;

  bool get includeInBulkDownload => this == ProposalPoStatus.active;

  String get label {
    switch (this) {
      case ProposalPoStatus.active:
        return 'Active';
      case ProposalPoStatus.archived:
        return 'Archived';
    }
  }

  String get storageValue {
    switch (this) {
      case ProposalPoStatus.active:
        return 'active';
      case ProposalPoStatus.archived:
        return 'archived';
    }
  }

  static ProposalPoStatus fromStorage(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'archived':
      case 'voided':
      case 'null':
      case 'rejected':
        return ProposalPoStatus.archived;
      default:
        return ProposalPoStatus.active;
    }
  }
}

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
    this.poStatus = ProposalPoStatus.active,
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
  final ProposalPoStatus poStatus;

  Proposal copyWith({
    String? id,
    String? referenceNo,
    DateTime? quoteDate,
    DateTime? expiryDate,
    String? placeOfSupply,
    String? vendorCode,
    String? entityCode,
    String? billToName,
    String? billToCompany,
    String? billToAddress,
    String? billToGstin,
    String? shipToName,
    String? shipToCompany,
    String? shipToAddress,
    String? shipToGstin,
    String? notes,
    List<ProposalLineItem>? lineItems,
    double? subtotal,
    String? totalInWords,
    ProposalPoStatus? poStatus,
  }) {
    return Proposal(
      id: id ?? this.id,
      referenceNo: referenceNo ?? this.referenceNo,
      quoteDate: quoteDate ?? this.quoteDate,
      expiryDate: expiryDate ?? this.expiryDate,
      placeOfSupply: placeOfSupply ?? this.placeOfSupply,
      vendorCode: vendorCode ?? this.vendorCode,
      entityCode: entityCode ?? this.entityCode,
      billToName: billToName ?? this.billToName,
      billToCompany: billToCompany ?? this.billToCompany,
      billToAddress: billToAddress ?? this.billToAddress,
      billToGstin: billToGstin ?? this.billToGstin,
      shipToName: shipToName ?? this.shipToName,
      shipToCompany: shipToCompany ?? this.shipToCompany,
      shipToAddress: shipToAddress ?? this.shipToAddress,
      shipToGstin: shipToGstin ?? this.shipToGstin,
      notes: notes ?? this.notes,
      lineItems: lineItems ?? this.lineItems,
      subtotal: subtotal ?? this.subtotal,
      totalInWords: totalInWords ?? this.totalInWords,
      poStatus: poStatus ?? this.poStatus,
    );
  }

  @override
  List<Object?> get props => [
        id,
        referenceNo,
        quoteDate,
        expiryDate,
        subtotal,
        lineItems,
        poStatus,
      ];
}
