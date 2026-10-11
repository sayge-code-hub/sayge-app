import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/payslip.dart';

/// Persists payroll runs + payslip snapshots. Soft-fails when tables are missing.
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
      // Soft-fail when migration has not been applied yet.
      final msg = e.message.toLowerCase();
      if (msg.contains('payroll_runs') ||
          msg.contains('payslip_records') ||
          msg.contains('does not exist') ||
          msg.contains('schema cache')) {
        debugPrint('Payroll persistence skipped (tables missing): ${e.message}');
        return;
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      debugPrint('Payroll persistence soft-failed: $e');
    }
  }
}
