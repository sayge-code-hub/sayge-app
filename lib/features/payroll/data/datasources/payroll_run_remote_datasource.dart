import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/payslip.dart';

/// True when PostgREST reports the payroll tables are absent (not RLS denial).
bool isMissingPayrollTableError(PostgrestException e) {
  final code = (e.code ?? '').toUpperCase();
  final msg = e.message.toLowerCase();
  return code == '42P01' ||
      code == 'PGRST205' ||
      ((msg.contains('payroll_runs') || msg.contains('payslip_records')) &&
          (msg.contains('does not exist') ||
              msg.contains('schema cache') ||
              msg.contains('could not find')));
}

/// Persists payroll runs + payslip snapshots.
/// Soft-fails only when the payroll tables are missing from the schema.
abstract class PayrollRunRemoteDataSource {
  Future<void> savePayrollRun({
    required int periodYear,
    required int periodMonth,
    required List<Payslip> slips,
    String notes = '',
  });
}

class PayrollRunRemoteDataSourceImpl implements PayrollRunRemoteDataSource {
  PayrollRunRemoteDataSourceImpl({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _runsTable = 'payroll_runs';
  static const _slipsTable = 'payslip_records';

  @override
  Future<void> savePayrollRun({
    required int periodYear,
    required int periodMonth,
    required List<Payslip> slips,
    String notes = '',
  }) async {
    if (slips.isEmpty) return;

    final runId = 'pr_${periodYear}_${periodMonth.toString().padLeft(2, '0')}';
    final uid = _client.auth.currentUser?.id;

    final runPayload = {
      'id': runId,
      'period_year': periodYear,
      'period_month': periodMonth,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      if (uid != null) 'generated_by': uid,
      'employee_count': slips.length,
      'notes': notes,
    };

    try {
      await _client.from(_runsTable).upsert(runPayload);

      final records = <Map<String, dynamic>>[];
      for (final slip in slips) {
        records.add({
          'id': 'ps_${runId}_${slip.employeeId}',
          'payroll_run_id': runId,
          'employee_id': slip.employeeId,
          'employee_name': slip.employeeName,
          'period_year': slip.year,
          'period_month': slip.month,
          'gross_earnings': slip.grossEarnings,
          'total_deductions': slip.totalDeductions,
          'net_pay': slip.netPay,
          'snapshot': {
            'period_label': slip.periodLabel,
            'gross_earnings': slip.grossEarnings,
            'total_deductions': slip.totalDeductions,
            'net_pay': slip.netPay,
            'earnings': [
              for (final line in slip.earnings)
                {'description': line.description, 'amount': line.amount},
            ],
            'deductions': [
              for (final line in slip.deductions)
                {'description': line.description, 'amount': line.amount},
            ],
          },
        });
      }

      await _client.from(_slipsTable).upsert(records);
    } on PostgrestException catch (e) {
      if (isMissingPayrollTableError(e)) {
        throw const ServerException(
          'Payslips downloaded, but payroll tables are missing. Run '
          'supabase/ops_completeness_pack.sql in the Supabase SQL editor to '
          'persist payroll runs.',
        );
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to persist payroll run.');
    }
  }
}
