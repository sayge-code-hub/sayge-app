import '../../domain/entities/client.dart';

class ClientModel extends Client {
  const ClientModel({
    required super.id,
    required super.name,
  });

  factory ClientModel.fromEntity(Client client) {
    return ClientModel(id: client.id, name: client.name);
  }

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: (json['id'] ?? json['client_id'] ?? '').toString(),
      name: (json['name'] ?? json['client_name'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
