import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/proposal.dart';
import '../models/proposal_model.dart';

abstract class ProposalRemoteDataSource {
  Future<List<ProposalModel>> getProposals();

  Future<ProposalModel> getProposal(String id);

  Future<ProposalModel> createProposal(ProposalModel proposal);

  Future<ProposalModel> updateProposal(ProposalModel proposal);

  Future<ProposalModel> updateProposalStatus({
    required String id,
    required ProposalPoStatus status,
  });
}

class ProposalRemoteDataSourceImpl implements ProposalRemoteDataSource {
  ProposalRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'proposals';
  static const _lines = 'proposal_line_items';
  static const _select =
      '*, proposal_line_items(*)';

  @override
  Future<List<ProposalModel>> getProposals() async {
    try {
      final rows = await _client
          .from(_table)
          .select(_select)
          .order('quote_date', ascending: false);
      return (rows as List<dynamic>)
          .map((row) => ProposalModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load proposals.');
    }
  }

  @override
  Future<ProposalModel> getProposal(String id) async {
    try {
      final row = await _client
          .from(_table)
          .select(_select)
          .eq('id', id)
          .single();
      return ProposalModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load proposal.');
    }
  }

  @override
  Future<ProposalModel> createProposal(ProposalModel proposal) async {
    try {
      await _client.from(_table).insert(proposal.toHeaderJson());

      if (proposal.lineItems.isNotEmpty) {
        final rows = proposal.lineItems.map((line) {
          return ProposalLineItemModel(
            id: line.id,
            description: line.description,
            monthlyRate: line.monthlyRate,
            months: line.months,
            days: line.days,
            totalRate: line.totalRate,
            sortOrder: line.sortOrder,
          ).toJson(proposalId: proposal.id);
        }).toList();
        await _client.from(_lines).insert(rows);
      }

      return getProposal(proposal.id);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ServerException('Proposal reference already exists.');
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to create proposal.');
    }
  }

  @override
  Future<ProposalModel> updateProposal(ProposalModel proposal) async {
    try {
      await _client
          .from(_table)
          .update(proposal.toHeaderJson())
          .eq('id', proposal.id);

      await _client.from(_lines).delete().eq('proposal_id', proposal.id);

      if (proposal.lineItems.isNotEmpty) {
        final rows = proposal.lineItems.map((line) {
          return ProposalLineItemModel(
            id: line.id,
            description: line.description,
            monthlyRate: line.monthlyRate,
            months: line.months,
            days: line.days,
            totalRate: line.totalRate,
            sortOrder: line.sortOrder,
          ).toJson(proposalId: proposal.id);
        }).toList();
        await _client.from(_lines).insert(rows);
      }

      return getProposal(proposal.id);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ServerException('Proposal reference already exists.');
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to update proposal.');
    }
  }

  @override
  Future<ProposalModel> updateProposalStatus({
    required String id,
    required ProposalPoStatus status,
  }) async {
    try {
      await _client
          .from(_table)
          .update({'status': status.storageValue})
          .eq('id', id);
      return getProposal(id);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to update proposal status.');
    }
  }
}
