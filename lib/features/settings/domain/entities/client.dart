import 'package:equatable/equatable.dart';

class Client extends Equatable {
  const Client({
    required this.id,
    required this.name,
    this.vendorCode = '',
    this.entityCode = '',
    this.contactName = '',
    this.address = '',
    this.gstin = '',
  });

  final String id;
  /// Company / client display name.
  final String name;
  final String vendorCode;
  final String entityCode;
  final String contactName;
  final String address;
  final String gstin;

  /// Dropdown label: "Mahindra Finance — Ketan Jain".
  String get displayLabel {
    final contact = contactName.trim();
    if (contact.isEmpty) return name;
    return '$name — $contact';
  }

  @override
  List<Object?> get props => [
        id,
        name,
        vendorCode,
        entityCode,
        contactName,
        address,
        gstin,
      ];
}
