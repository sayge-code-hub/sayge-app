part of 'clients_bloc.dart';

abstract class ClientsEvent extends Equatable {
  const ClientsEvent();

  @override
  List<Object?> get props => [];
}

class ClientsRequested extends ClientsEvent {
  const ClientsRequested();
}

class ClientNameChanged extends ClientsEvent {
  const ClientNameChanged(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

class ClientSubmitted extends ClientsEvent {
  const ClientSubmitted();
}
