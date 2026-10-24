import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/features/invoices/data/datasources/invoice_remote_datasource.dart';
import 'package:sayge_app/features/payroll/data/datasources/payroll_run_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException _pg({
  required String message,
  String? code,
}) {
  return PostgrestException(message: message, code: code);
}

void main() {
  group('isMissingInvoicePaymentColumn', () {
    test('true for missing-column codes mentioning payment fields', () {
      expect(
        isMissingInvoicePaymentColumn(
          _pg(
            message: "Could not find the 'payment_status' column",
            code: 'PGRST204',
          ),
        ),
        isTrue,
      );
      expect(
        isMissingInvoicePaymentColumn(
          _pg(message: 'column amount_paid does not exist', code: '42703'),
        ),
        isTrue,
      );
    });

    test('false for check-constraint failures so status is never stripped', () {
      expect(
        isMissingInvoicePaymentColumn(
          _pg(
            message:
                'new row violates check constraint "invoices_payment_status_check"',
            code: '23514',
          ),
        ),
        isFalse,
      );
    });

    test('false for unrelated errors', () {
      expect(
        isMissingInvoicePaymentColumn(
          _pg(message: 'permission denied for table invoices', code: '42501'),
        ),
        isFalse,
      );
    });
  });

  group('isMissingPayrollTableError', () {
    test('true only when tables are missing', () {
      expect(
        isMissingPayrollTableError(
          _pg(message: 'relation "payroll_runs" does not exist', code: '42P01'),
        ),
        isTrue,
      );
      expect(
        isMissingPayrollTableError(
          _pg(
            message: "Could not find the table 'public.payslip_records'",
            code: 'PGRST205',
          ),
        ),
        isTrue,
      );
    });

    test('false for RLS / permission errors that mention table names', () {
      expect(
        isMissingPayrollTableError(
          _pg(
            message: 'permission denied for table payroll_runs',
            code: '42501',
          ),
        ),
        isFalse,
      );
      expect(
        isMissingPayrollTableError(
          _pg(message: 'new row violates row-level security policy', code: '42501'),
        ),
        isFalse,
      );
    });
  });
}
