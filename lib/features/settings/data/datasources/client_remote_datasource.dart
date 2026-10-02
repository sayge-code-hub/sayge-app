import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../models/client_model.dart';

abstract class ClientRemoteDataSource {
  Future<List<ClientModel>> getClients();

  Future<ClientModel> addClient(String name);
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
  Future<ClientModel> addClient(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ServerException('Client name is required.');
    }

    final id = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    try {
      final row = await _client
          .from(_table)
          .insert({'id': id.isEmpty ? 'client' : id, 'name': trimmed})
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
}
