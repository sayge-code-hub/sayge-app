part of 'clients_bloc.dart';

abstract class ClientsEvent extends Equatable {
  const ClientsEvent();

  @override
  List<Object?> get props => [];
}

class ClientsRequested extends ClientsEvent {
  const ClientsRequested();
}

class ClientSubmitted extends ClientsEvent {
  const ClientSubmitted({
    this.clientId,
    required this.name,
    this.vendorCode = '',
    this.entityCode = '',
    this.contactName = '',
    this.address = '',
    this.gstin = '',
  });

  /// When set, updates an existing client instead of creating one.
  final String? clientId;
  final String name;
  final String vendorCode;
  final String entityCode;
  final String contactName;
  final String address;
  final String gstin;

  @override
  List<Object?> get props => [
        clientId,
        name,
        vendorCode,
        entityCode,
        contactName,
        address,
        gstin,
      ];
}

class ClientActiveToggled extends ClientsEvent {
  const ClientActiveToggled({
    required this.clientId,
    required this.isActive,
  });

  final String clientId;
  final bool isActive;

  @override
  List<Object?> get props => [clientId, isActive];
}

class ClientDeleted extends ClientsEvent {
  const ClientDeleted(this.clientId);

  final String clientId;

  @override
  List<Object?> get props => [clientId];
}
