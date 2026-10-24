import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../models/invoice_model.dart';

/// True when PostgREST reports invoice payment columns are absent.
/// Check-constraint failures must return false so status is never dropped.
bool isMissingInvoicePaymentColumn(PostgrestException e) {
  if (e.code == '23514') return false;
  final msg = e.message.toLowerCase();
  if (msg.contains('check constraint')) return false;
  final mentionsPayment = msg.contains('payment_status') ||
      msg.contains('amount_paid') ||
      msg.contains('due_date') ||
      msg.contains('paid_at');
  if (!mentionsPayment) return false;
  return e.code == '42703' ||
      e.code == 'PGRST204' ||
      msg.contains('does not exist') ||
      msg.contains('schema cache');
}

abstract class InvoiceRemoteDataSource {
  Future<List<InvoiceModel>> getInvoices();

  Future<InvoiceModel> createInvoice(InvoiceModel invoice);

  Future<InvoiceModel> updateInvoice(InvoiceModel invoice);

  /// Updates payment fields only — does not touch line items.
  Future<InvoiceModel> updatePaymentFields(InvoiceModel invoice);
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
      final header = invoice.toHeaderJson();
      try {
        await _client.from(_table).insert(header);
      } on PostgrestException catch (e) {
        if (isMissingInvoicePaymentColumn(e)) {
          throw const ServerException(
            'Invoice payment columns are missing. Run '
            'supabase/ops_completeness_pack.sql (then '
            'supabase/invoices_payment_status_sent.sql if needed) and '
            'supabase/security_hardening.sql in the Supabase SQL editor.',
          );
        }
        rethrow;
      }

      if (invoice.lineItems.isNotEmpty) {
        final rows = invoice.lineItems
            .map(
              (line) => InvoiceLineItemModel.fromEntity(
                line,
              ).toJson(invoiceId: invoice.id),
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
      if (e.code == '23514' &&
          e.message.toLowerCase().contains('payment_status')) {
        throw const ServerException(
          'Could not save that payment status. Run supabase/invoices_payment_status_sent.sql in the Supabase SQL editor, then try again.',
        );
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
      final header = invoice.toHeaderJson();
      try {
        await _client.from(_table).update(header).eq('id', invoice.id);
      } on PostgrestException catch (e) {
        if (isMissingInvoicePaymentColumn(e)) {
          throw const ServerException(
            'Invoice payment columns are missing. Run '
            'supabase/ops_completeness_pack.sql (then '
            'supabase/invoices_payment_status_sent.sql if needed) and '
            'supabase/security_hardening.sql in the Supabase SQL editor.',
          );
        }
        rethrow;
      }

      await _client.from(_lines).delete().eq('invoice_id', invoice.id);

      if (invoice.lineItems.isNotEmpty) {
        final rows = invoice.lineItems
            .map(
              (line) => InvoiceLineItemModel.fromEntity(
                line,
              ).toJson(invoiceId: invoice.id),
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
      if (e.code == '23514' &&
          e.message.toLowerCase().contains('payment_status')) {
        throw const ServerException(
          'Could not save that payment status. Run supabase/invoices_payment_status_sent.sql in the Supabase SQL editor, then try again.',
        );
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to update invoice.');
    }
  }

  @override
  Future<InvoiceModel> updatePaymentFields(InvoiceModel invoice) async {
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    try {
      await _client.from(_table).update({
        'payment_status': invoice.paymentStatus.dbValue,
        'amount_paid': invoice.amountPaid,
        'due_date': invoice.dueDate == null ? null : ymd(invoice.dueDate!),
        'paid_at': invoice.paidAt == null ? null : ymd(invoice.paidAt!),
      }).eq('id', invoice.id);

      final row = await _client
          .from(_table)
          .select(_select)
          .eq('id', invoice.id)
          .single();
      return InvoiceModel.fromJson(row);
    } on PostgrestException catch (e) {
      if (isMissingInvoicePaymentColumn(e)) {
        throw const ServerException(
          'Invoice payment columns are missing. Run '
          'supabase/ops_completeness_pack.sql (then '
          'supabase/invoices_payment_status_sent.sql if needed) and '
          'supabase/security_hardening.sql in the Supabase SQL editor.',
        );
      }
      if (e.code == '23514' &&
          e.message.toLowerCase().contains('payment_status')) {
        throw const ServerException(
          'Could not save that payment status. Run supabase/invoices_payment_status_sent.sql in the Supabase SQL editor, then try again.',
        );
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to update invoice payment.');
    }
  }
}
