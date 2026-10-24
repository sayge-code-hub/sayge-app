import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/features/payroll/data/datasources/payroll_run_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('soft-fails only when the relation is missing', () {
    expect(
      isMissingPayrollTableError(
        const PostgrestException(
          message: 'relation "public.payroll_runs" does not exist',
          code: '42P01',
        ),
      ),
      isTrue,
    );
    expect(
      isMissingPayrollTableError(
        const PostgrestException(
          message:
              'Could not find the table public.payroll_runs in the schema cache',
          code: 'PGRST205',
        ),
      ),
      isTrue,
    );
  });

  test('does not soft-fail on RLS or permission errors', () {
    expect(
      isMissingPayrollTableError(
        const PostgrestException(
          message: 'permission denied for table payroll_runs',
          code: '42501',
        ),
      ),
      isFalse,
    );
    expect(
      isMissingPayrollTableError(
        const PostgrestException(
          message:
              'new row violates row-level security policy for table "payroll_runs"',
          code: '42501',
        ),
      ),
      isFalse,
    );
  });
}
