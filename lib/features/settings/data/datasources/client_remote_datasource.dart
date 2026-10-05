import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/client.dart';
import '../models/client_model.dart';

abstract class ClientRemoteDataSource {
  Future<List<ClientModel>> getClients();

  Future<ClientModel> addClient(Client client);

  Future<ClientModel> updateClient(Client client);

  Future<ClientModel> setClientActive({
    required String id,
    required bool isActive,
  });

  Future<void> deleteClient(String id);
}

class ClientRemoteDataSourceImpl implements ClientRemoteDataSource {
  ClientRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'clients';

  @override
  Future<List<ClientModel>> getClients() async {
    try {
      final rows = await _client.from(_table).select().order('name');
      return (rows as List<dynamic>)
          .map((row) => ClientModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load clients from Supabase.');
    }
  }

  @override
  Future<ClientModel> addClient(Client client) async {
    final trimmed = client.name.trim();
    if (trimmed.isEmpty) {
      throw const ServerException('Client name is required.');
    }

    final contact = client.contactName.trim();
    final base = contact.isEmpty ? trimmed : '$trimmed $contact';
    final id = base
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    try {
      final row = await _client
          .from(_table)
          .insert(
            ClientModel(
              id: id.isEmpty ? 'client' : id,
              name: trimmed,
              vendorCode: client.vendorCode.trim(),
              entityCode: client.entityCode.trim(),
              contactName: contact,
              address: client.address.trim(),
              gstin: client.gstin.trim(),
              isActive: true,
            ).toJson(),
          )
          .select()
          .single();
      return ClientModel.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ServerException('Client already exists.');
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to add client.');
    }
  }

  @override
  Future<ClientModel> updateClient(Client client) async {
    final trimmed = client.name.trim();
    if (trimmed.isEmpty) {
      throw const ServerException('Client name is required.');
    }
    if (client.id.trim().isEmpty) {
      throw const ServerException('Client id is required.');
    }

    try {
      final previousRow = await _client
          .from(_table)
          .select()
          .eq('id', client.id)
          .maybeSingle();
      final previous = previousRow == null
          ? null
          : ClientModel.fromJson(previousRow);

      final row = await _client
          .from(_table)
          .update({
            'name': trimmed,
            'vendor_code': client.vendorCode.trim(),
            'entity_code': client.entityCode.trim(),
            'contact_name': client.contactName.trim(),
            'address': client.address.trim(),
            'gstin': client.gstin.trim(),
          })
          .eq('id', client.id)
          .select()
          .single();
      final updated = ClientModel.fromJson(row);
      if (previous != null) {
        await _cascadeClientToProposals(previous: previous, next: updated);
        await _cascadeClientToInvoices(previous: previous, next: updated);
      }
      return updated;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to update client.');
    }
  }

  /// Proposals snapshot party fields — keep them in sync when a client changes.
  Future<void> _cascadeClientToProposals({
    required Client previous,
    required Client next,
  }) async {
    final oldCompany = previous.name.trim();
    final oldContact = previous.contactName.trim();
    if (oldCompany.isEmpty && oldContact.isEmpty) return;

    var billQuery = _client.from('proposals').update({
      'bill_to_name': next.contactName.trim(),
      'bill_to_company': next.name.trim(),
      'bill_to_address': next.address.trim(),
      'bill_to_gstin': next.gstin.trim(),
      'vendor_code': next.vendorCode.trim(),
      'entity_code': next.entityCode.trim(),
    });
    if (oldCompany.isNotEmpty) {
      billQuery = billQuery.eq('bill_to_company', oldCompany);
    }
    billQuery = billQuery.eq('bill_to_name', oldContact);
    await billQuery;

    var shipQuery = _client.from('proposals').update({
      'ship_to_name': next.contactName.trim(),
      'ship_to_company': next.name.trim(),
      'ship_to_address': next.address.trim(),
      'ship_to_gstin': next.gstin.trim(),
    });
    if (oldCompany.isNotEmpty) {
      shipQuery = shipQuery.eq('ship_to_company', oldCompany);
    }
    shipQuery = shipQuery.eq('ship_to_name', oldContact);
    await shipQuery;
  }

  Future<void> _cascadeClientToInvoices({
    required Client previous,
    required Client next,
  }) async {
    final oldCompany = previous.name.trim();
    final oldContact = previous.contactName.trim();
    if (oldCompany.isEmpty && oldContact.isEmpty) return;

    var query = _client.from('invoices').update({
      'buyer_name': next.contactName.trim(),
      'buyer_company': next.name.trim(),
      'buyer_address': next.address.trim(),
      'buyer_gstin': next.gstin.trim(),
      'buyer_contact': next.contactName.trim(),
    });
    if (oldCompany.isNotEmpty) {
      query = query.eq('buyer_company', oldCompany);
    }
    query = query.eq('buyer_contact', oldContact);
    await query;
  }

  @override
  Future<ClientModel> setClientActive({
    required String id,
    required bool isActive,
  }) async {
    try {
      final row = await _client
          .from(_table)
          .update({'is_active': isActive})
          .eq('id', id)
          .select()
          .single();
      return ClientModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to update client.');
    }
  }

  @override
  Future<void> deleteClient(String id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to delete client.');
    }
  }
}
