part of 'company_details_bloc.dart';

enum CompanyDetailsStatus { initial, loading, ready, saving, success, failure }

class CompanyDetailsState extends Equatable {
  const CompanyDetailsState({
    this.status = CompanyDetailsStatus.initial,
    this.details,
    this.errorMessage,
    this.formEpoch = 0,
  });

  final CompanyDetailsStatus status;
  final CompanyDetails? details;
  final String? errorMessage;
  final int formEpoch;

  CompanyDetailsState copyWith({
    CompanyDetailsStatus? status,
    CompanyDetails? details,
    String? errorMessage,
    bool clearError = false,
    int? formEpoch,
  }) {
    return CompanyDetailsState(
      status: status ?? this.status,
      details: details ?? this.details,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      formEpoch: formEpoch ?? this.formEpoch,
    );
  }

  @override
  List<Object?> get props => [status, details, errorMessage, formEpoch];
}
