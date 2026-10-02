import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/client.dart';
import '../../../domain/usecases/add_client.dart';
import '../../../domain/usecases/get_clients.dart';

part 'clients_event.dart';
part 'clients_state.dart';

class ClientsBloc extends Bloc<ClientsEvent, ClientsState> {
  ClientsBloc({
    required this.getClientsUseCase,
    required this.addClientUseCase,
  }) : super(const ClientsState()) {
    on<ClientsRequested>(_onRequested);
    on<ClientSubmitted>(_onSubmitted);
  }

  final GetClientsUseCase getClientsUseCase;
  final AddClientUseCase addClientUseCase;

  Future<void> _onRequested(
    ClientsRequested event,
    Emitter<ClientsState> emit,
  ) async {
    emit(state.copyWith(status: ClientsStatus.loading, clearError: true));
    final result = await getClientsUseCase();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ClientsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (clients) => emit(
        state.copyWith(
          status: ClientsStatus.ready,
          clients: clients,
        ),
      ),
    );
  }

  Future<void> _onSubmitted(
    ClientSubmitted event,
    Emitter<ClientsState> emit,
  ) async {
    if (event.name.trim().isEmpty) {
      emit(
        state.copyWith(
          status: ClientsStatus.failure,
          errorMessage: 'Client name is required',
        ),
      );
      return;
    }

    emit(state.copyWith(status: ClientsStatus.saving, clearError: true));
    final result = await addClientUseCase(
      Client(
        id: '',
        name: event.name,
        vendorCode: event.vendorCode,
        entityCode: event.entityCode,
        contactName: event.contactName,
        address: event.address,
        gstin: event.gstin,
      ),
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ClientsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (client) {
        final updated = [...state.clients, client]
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        emit(
          state.copyWith(
            status: ClientsStatus.success,
            clients: updated,
          ),
        );
      },
    );
  }
}
