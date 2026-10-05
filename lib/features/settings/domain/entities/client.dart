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
    this.isActive = true,
    this.logoPath = '',
    this.logoUrl,
  });

  final String id;
  /// Company / client display name.
  final String name;
  final String vendorCode;
  final String entityCode;
  final String contactName;
  final String address;
  final String gstin;
  final bool isActive;
  final String logoPath;
  final String? logoUrl;

  /// Dropdown label: "Mahindra Finance — Ketan Jain".
  String get displayLabel {
    final contact = contactName.trim();
    final base = contact.isEmpty ? name : '$name — $contact';
    if (isActive) return base;
    return '$base (Inactive)';
  }

  Client copyWith({
    String? id,
    String? name,
    String? vendorCode,
    String? entityCode,
    String? contactName,
    String? address,
    String? gstin,
    bool? isActive,
    String? logoPath,
    String? logoUrl,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      vendorCode: vendorCode ?? this.vendorCode,
      entityCode: entityCode ?? this.entityCode,
      contactName: contactName ?? this.contactName,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      isActive: isActive ?? this.isActive,
      logoPath: logoPath ?? this.logoPath,
      logoUrl: logoUrl ?? this.logoUrl,
    );
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
        isActive,
        logoPath,
        logoUrl,
      ];
}
