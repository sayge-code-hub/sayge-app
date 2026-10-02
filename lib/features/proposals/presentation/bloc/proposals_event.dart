part of 'proposals_bloc.dart';

abstract class ProposalsEvent extends Equatable {
  const ProposalsEvent();

  @override
  List<Object?> get props => [];
}

class ProposalsStarted extends ProposalsEvent {
  const ProposalsStarted();
}

class ProposalListRequested extends ProposalsEvent {
  const ProposalListRequested();
}

class ProposalFormOpened extends ProposalsEvent {
  const ProposalFormOpened();
}

class ProposalEditOpened extends ProposalsEvent {
  const ProposalEditOpened(this.proposal);

  final Proposal proposal;

  @override
  List<Object?> get props => [proposal];
}

class ProposalCloneOpened extends ProposalsEvent {
  const ProposalCloneOpened(this.proposal);

  final Proposal proposal;

  @override
  List<Object?> get props => [proposal];
}

class ProposalFormFieldChanged extends ProposalsEvent {
  const ProposalFormFieldChanged({
    this.referenceNo,
    this.quoteDate,
    this.expiryDate,
    this.placeOfSupply,
    this.vendorCode,
    this.entityCode,
    this.billToName,
    this.billToCompany,
    this.billToAddress,
    this.billToGstin,
    this.shipToName,
    this.shipToCompany,
    this.shipToAddress,
    this.shipToGstin,
    this.notes,
  });

  final String? referenceNo;
  final DateTime? quoteDate;
  final DateTime? expiryDate;
  final String? placeOfSupply;
  final String? vendorCode;
  final String? entityCode;
  final String? billToName;
  final String? billToCompany;
  final String? billToAddress;
  final String? billToGstin;
  final String? shipToName;
  final String? shipToCompany;
  final String? shipToAddress;
  final String? shipToGstin;
  final String? notes;

  @override
  List<Object?> get props => [
        referenceNo,
        quoteDate,
        expiryDate,
        placeOfSupply,
        vendorCode,
        entityCode,
        billToName,
        billToCompany,
        billToAddress,
        billToGstin,
        shipToName,
        shipToCompany,
        shipToAddress,
        shipToGstin,
        notes,
      ];
}

class ProposalLineChanged extends ProposalsEvent {
  const ProposalLineChanged({
    required this.index,
    this.description,
    this.monthlyRate,
    this.months,
    this.days,
  });

  final int index;
  final String? description;
  final String? monthlyRate;
  final String? months;
  final String? days;

  @override
  List<Object?> get props => [index, description, monthlyRate, months, days];
}

class ProposalLineAdded extends ProposalsEvent {
  const ProposalLineAdded();
}

class ProposalLineRemoved extends ProposalsEvent {
  const ProposalLineRemoved(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

class ProposalCopyShipFromBill extends ProposalsEvent {
  const ProposalCopyShipFromBill();
}

class ProposalSubmitted extends ProposalsEvent {
  const ProposalSubmitted({
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
    required this.lines,
  });

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
  final List<DraftLine> lines;

  @override
  List<Object?> get props => [
        referenceNo,
        quoteDate,
        expiryDate,
        placeOfSupply,
        vendorCode,
        entityCode,
        billToName,
        billToCompany,
        billToAddress,
        billToGstin,
        shipToName,
        shipToCompany,
        shipToAddress,
        shipToGstin,
        notes,
        lines,
      ];
}

class ProposalDownloadRequested extends ProposalsEvent {
  const ProposalDownloadRequested(this.proposal);

  final Proposal proposal;

  @override
  List<Object?> get props => [proposal];
}
