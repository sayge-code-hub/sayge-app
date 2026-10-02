import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/settings_entities.dart';
import '../../../domain/usecases/settings_usecases.dart';

part 'roles_event.dart';
part 'roles_state.dart';

class RolesBloc extends Bloc<RolesEvent, RolesState> {
  RolesBloc({required this.getRolesUseCase}) : super(const RolesState()) {
    on<RolesStarted>(_onStarted);
  }

  final GetRolesUseCase getRolesUseCase;

  Future<void> _onStarted(RolesStarted event, Emitter<RolesState> emit) async {
    emit(state.copyWith(status: RolesStatus.loading, clearError: true));
    final result = await getRolesUseCase();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: RolesStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (roles) => emit(
        state.copyWith(status: RolesStatus.ready, roles: roles),
      ),
    );
  }
}
