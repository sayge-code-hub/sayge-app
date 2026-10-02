part of 'company_details_bloc.dart';

abstract class CompanyDetailsEvent extends Equatable {
  const CompanyDetailsEvent();

  @override
  List<Object?> get props => [];
}

class CompanyDetailsStarted extends CompanyDetailsEvent {
  const CompanyDetailsStarted();
}

class CompanyDetailsFieldChanged extends CompanyDetailsEvent {
  const CompanyDetailsFieldChanged({
    this.displayName,
    this.address,
    this.gstin,
    this.pan,
    this.sacCode,
    this.telephone,
    this.email,
    this.bankName,
    this.bankAccountNo,
    this.bankBranch,
    this.bankIfsc,
  });

  final String? displayName;
  final String? address;
  final String? gstin;
  final String? pan;
  final String? sacCode;
  final String? telephone;
  final String? email;
  final String? bankName;
  final String? bankAccountNo;
  final String? bankBranch;
  final String? bankIfsc;

  @override
  List<Object?> get props => [
        displayName,
        address,
        gstin,
        pan,
        sacCode,
        telephone,
        email,
        bankName,
        bankAccountNo,
        bankBranch,
        bankIfsc,
      ];
}

class CompanyDetailsSubmitted extends CompanyDetailsEvent {
  const CompanyDetailsSubmitted();
}
