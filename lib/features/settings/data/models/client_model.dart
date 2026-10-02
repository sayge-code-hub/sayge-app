import '../../domain/entities/client.dart';

class ClientModel extends Client {
  const ClientModel({
    required super.id,
    required super.name,
    super.vendorCode,
    super.entityCode,
    super.contactName,
    super.address,
    super.gstin,
  });

  factory ClientModel.fromEntity(Client client) {
    return ClientModel(
      id: client.id,
      name: client.name,
      vendorCode: client.vendorCode,
      entityCode: client.entityCode,
      contactName: client.contactName,
      address: client.address,
      gstin: client.gstin,
    );
  }

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: (json['id'] ?? json['client_id'] ?? '').toString(),
      name: (json['name'] ?? json['client_name'] ?? '').toString(),
      vendorCode: (json['vendor_code'] ?? '').toString(),
      entityCode: (json['entity_code'] ?? '').toString(),
      contactName: (json['contact_name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      gstin: (json['gstin'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'vendor_code': vendorCode,
      'entity_code': entityCode,
      'contact_name': contactName,
      'address': address,
      'gstin': gstin,
    };
  }
}
