import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../models/invoice_model.dart';

abstract class InvoiceRemoteDataSource {
  Future<List<InvoiceModel>> getInvoices();

  Future<InvoiceModel> createInvoice(InvoiceModel invoice);

  Future<InvoiceModel> updateInvoice(InvoiceModel invoice);
}

class InvoiceRemoteDataSourceImpl implements InvoiceRemoteDataSource {
  InvoiceRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'invoices';
  static const _lines = 'invoice_line_items';
  static const _select = '*, invoice_line_items(*)';

  @override
  Future<List<InvoiceModel>> getInvoices() async {
    try {
      final rows = await _client
          .from(_table)
          .select(_select)
          .order('invoice_date', ascending: false);
      return (rows as List<dynamic>)
          .map((row) => InvoiceModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load invoices.');
    }
  }

  @override
  Future<InvoiceModel> createInvoice(InvoiceModel invoice) async {
    try {
      await _client.from(_table).insert(invoice.toHeaderJson());

      if (invoice.lineItems.isNotEmpty) {
        final rows = invoice.lineItems
            .map(
              (line) => InvoiceLineItemModel.fromEntity(line).toJson(
                invoiceId: invoice.id,
              ),
            )
            .toList();
        await _client.from(_lines).insert(rows);
      }

      final row = await _client
          .from(_table)
          .select(_select)
          .eq('id', invoice.id)
          .single();
      return InvoiceModel.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ServerException('Invoice number already exists.');
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to create invoice.');
    }
  }

  @override
  Future<InvoiceModel> updateInvoice(InvoiceModel invoice) async {
    try {
      await _client
          .from(_table)
          .update(invoice.toHeaderJson())
          .eq('id', invoice.id);

      await _client.from(_lines).delete().eq('invoice_id', invoice.id);

      if (invoice.lineItems.isNotEmpty) {
        final rows = invoice.lineItems
            .map(
              (line) => InvoiceLineItemModel.fromEntity(line).toJson(
                invoiceId: invoice.id,
              ),
            )
            .toList();
        await _client.from(_lines).insert(rows);
      }

      final row = await _client
          .from(_table)
          .select(_select)
          .eq('id', invoice.id)
          .single();
      return InvoiceModel.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ServerException('Invoice number already exists.');
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to update invoice.');
    }
  }
}
