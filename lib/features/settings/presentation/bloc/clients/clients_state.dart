part of 'clients_bloc.dart';

enum ClientsStatus { initial, loading, ready, saving, success, failure }

class ClientsState extends Equatable {
  const ClientsState({
    this.status = ClientsStatus.initial,
    this.clients = const [],
    this.name = '',
    this.errorMessage,
  });

  final ClientsStatus status;
  final List<Client> clients;
  final String name;
  final String? errorMessage;

  ClientsState copyWith({
    ClientsStatus? status,
    List<Client>? clients,
    String? name,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ClientsState(
      status: status ?? this.status,
      clients: clients ?? this.clients,
      name: name ?? this.name,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, clients, name, errorMessage];
}
