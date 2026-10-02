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
    required this.name,
    this.vendorCode = '',
    this.entityCode = '',
    this.contactName = '',
    this.address = '',
    this.gstin = '',
  });

  final String name;
  final String vendorCode;
  final String entityCode;
  final String contactName;
  final String address;
  final String gstin;

  @override
  List<Object?> get props => [
        name,
        vendorCode,
        entityCode,
        contactName,
        address,
        gstin,
      ];
}
