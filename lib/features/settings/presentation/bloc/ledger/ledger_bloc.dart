import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/settings_entities.dart';
import '../../../domain/usecases/settings_usecases.dart';

part 'ledger_event.dart';
part 'ledger_state.dart';

class LedgerBloc extends Bloc<LedgerEvent, LedgerState> {
  LedgerBloc({required this.getActivityLogUseCase})
      : super(const LedgerState()) {
    on<LedgerStarted>(_onStarted);
  }

  final GetActivityLogUseCase getActivityLogUseCase;

  Future<void> _onStarted(
    LedgerStarted event,
    Emitter<LedgerState> emit,
  ) async {
    emit(state.copyWith(status: LedgerStatus.loading, clearError: true));
    final result = await getActivityLogUseCase();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: LedgerStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (entries) => emit(
        state.copyWith(status: LedgerStatus.ready, entries: entries),
      ),
    );
  }
}
