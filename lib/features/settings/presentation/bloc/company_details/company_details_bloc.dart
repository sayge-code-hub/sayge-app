import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/settings_entities.dart';
import '../../../domain/usecases/settings_usecases.dart';

part 'company_details_event.dart';
part 'company_details_state.dart';

class CompanyDetailsBloc
    extends Bloc<CompanyDetailsEvent, CompanyDetailsState> {
  CompanyDetailsBloc({
    required this.getCompanyDetailsUseCase,
    required this.updateCompanyDetailsUseCase,
  }) : super(const CompanyDetailsState()) {
    on<CompanyDetailsStarted>(_onStarted);
    on<CompanyDetailsFieldChanged>(_onFieldChanged);
    on<CompanyDetailsSubmitted>(_onSubmitted);
    on<CompanyDetailsLogoUpdated>(_onLogoUpdated);
  }

  final GetCompanyDetailsUseCase getCompanyDetailsUseCase;
  final UpdateCompanyDetailsUseCase updateCompanyDetailsUseCase;

  Future<void> _onStarted(
    CompanyDetailsStarted event,
    Emitter<CompanyDetailsState> emit,
  ) async {
    emit(state.copyWith(status: CompanyDetailsStatus.loading, clearError: true));
    final result = await getCompanyDetailsUseCase();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CompanyDetailsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (details) => emit(
        state.copyWith(
          status: CompanyDetailsStatus.ready,
          details: details,
          formEpoch: state.formEpoch + 1,
        ),
      ),
    );
  }

  void _onFieldChanged(
    CompanyDetailsFieldChanged event,
    Emitter<CompanyDetailsState> emit,
  ) {
    final current = state.details;
    if (current == null) return;
    emit(
      state.copyWith(
        status: CompanyDetailsStatus.ready,
        clearError: true,
        details: CompanyDetails(
          id: current.id,
          name: current.name,
          displayName: event.displayName ?? current.displayName,
          address: event.address ?? current.address,
          gstin: event.gstin ?? current.gstin,
          pan: event.pan ?? current.pan,
          sacCode: event.sacCode ?? current.sacCode,
          telephone: event.telephone ?? current.telephone,
          email: event.email ?? current.email,
          bankName: event.bankName ?? current.bankName,
          bankAccountNo: event.bankAccountNo ?? current.bankAccountNo,
          bankBranch: event.bankBranch ?? current.bankBranch,
          bankIfsc: event.bankIfsc ?? current.bankIfsc,
          logoPath: current.logoPath,
          logoUrl: current.logoUrl,
        ),
      ),
    );
  }

  void _onLogoUpdated(
    CompanyDetailsLogoUpdated event,
    Emitter<CompanyDetailsState> emit,
  ) {
    emit(
      state.copyWith(
        status: CompanyDetailsStatus.ready,
        clearError: true,
        details: event.details,
      ),
    );
  }

  Future<void> _onSubmitted(
    CompanyDetailsSubmitted event,
    Emitter<CompanyDetailsState> emit,
  ) async {
    final details = state.details;
    if (details == null) return;
    if (details.displayName.trim().isEmpty) {
      emit(
        state.copyWith(
          status: CompanyDetailsStatus.failure,
          errorMessage: 'Display name is required',
        ),
      );
      return;
    }
    emit(state.copyWith(status: CompanyDetailsStatus.saving, clearError: true));
    final result = await updateCompanyDetailsUseCase(details);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CompanyDetailsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (saved) => emit(
        state.copyWith(
          status: CompanyDetailsStatus.success,
          details: saved,
        ),
      ),
    );
  }
}
