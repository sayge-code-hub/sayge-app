import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/client.dart';
import '../../../domain/usecases/add_client.dart';
import '../../../domain/usecases/client_lifecycle.dart';
import '../../../domain/usecases/get_clients.dart';

part 'clients_event.dart';
part 'clients_state.dart';

class ClientsBloc extends Bloc<ClientsEvent, ClientsState> {
  ClientsBloc({
    required this.getClientsUseCase,
    required this.addClientUseCase,
    required this.updateClientUseCase,
    required this.setClientActiveUseCase,
    required this.deleteClientUseCase,
  }) : super(const ClientsState()) {
    on<ClientsRequested>(_onRequested);
    on<ClientSubmitted>(_onSubmitted);
    on<ClientActiveToggled>(_onActiveToggled);
    on<ClientDeleted>(_onDeleted);
  }

  final GetClientsUseCase getClientsUseCase;
  final AddClientUseCase addClientUseCase;
  final UpdateClientUseCase updateClientUseCase;
  final SetClientActiveUseCase setClientActiveUseCase;
  final DeleteClientUseCase deleteClientUseCase;

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
    final editingId = event.clientId?.trim();
    final draft = Client(
      id: editingId ?? '',
      name: event.name,
      vendorCode: event.vendorCode,
      entityCode: event.entityCode,
      contactName: event.contactName,
      address: event.address,
      gstin: event.gstin,
    );
    final result = editingId == null || editingId.isEmpty
        ? await addClientUseCase(draft)
        : await updateClientUseCase(draft);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ClientsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (client) {
        final List<Client> updated;
        if (editingId == null || editingId.isEmpty) {
          updated = [...state.clients, client]
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
        } else {
          updated = [
            for (final existing in state.clients)
              if (existing.id == client.id) client else existing,
          ];
        }
        emit(
          state.copyWith(
            status: ClientsStatus.success,
            clients: updated,
          ),
        );
      },
    );
  }

  Future<void> _onActiveToggled(
    ClientActiveToggled event,
    Emitter<ClientsState> emit,
  ) async {
    emit(state.copyWith(status: ClientsStatus.saving, clearError: true));
    final result = await setClientActiveUseCase(
      id: event.clientId,
      isActive: event.isActive,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ClientsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (updated) {
        emit(
          state.copyWith(
            status: ClientsStatus.ready,
            clients: [
              for (final client in state.clients)
                if (client.id == updated.id) updated else client,
            ],
          ),
        );
      },
    );
  }

  Future<void> _onDeleted(
    ClientDeleted event,
    Emitter<ClientsState> emit,
  ) async {
    emit(state.copyWith(status: ClientsStatus.saving, clearError: true));
    final result = await deleteClientUseCase(event.clientId);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ClientsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (_) {
        emit(
          state.copyWith(
            status: ClientsStatus.ready,
            clients: [
              for (final client in state.clients)
                if (client.id != event.clientId) client,
            ],
          ),
        );
      },
    );
  }
}
