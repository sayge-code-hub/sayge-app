import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/pdf_saver.dart';
import '../../../hrms/domain/entities/employee.dart';
import '../../../hrms/domain/usecases/get_employees.dart';
import '../../data/payslip_pdf_builder.dart';
import '../../domain/services/payslip_calculator.dart';
import '../../domain/services/payslip_period.dart';

part 'payroll_event.dart';
part 'payroll_state.dart';

class PayrollBloc extends Bloc<PayrollEvent, PayrollState> {
  PayrollBloc({required this.getEmployeesUseCase})
      : super(() {
          final latest = PayslipPeriod.latestAvailable();
          return PayrollState(month: latest.month, year: latest.year);
        }()) {
    on<PayrollStarted>(_onStarted);
    on<PayrollMonthChanged>(_onMonthChanged);
    on<PayrollEmployeeToggled>(_onToggled);
    on<PayrollSelectAllToggled>(_onSelectAll);
    on<PayrollDownloadSelected>(_onDownloadSelected);
    on<PayrollDownloadAll>(_onDownloadAll);
  }

  final GetEmployeesUseCase getEmployeesUseCase;

  Future<void> _onStarted(
    PayrollStarted event,
    Emitter<PayrollState> emit,
  ) async {
    emit(state.copyWith(status: PayrollStatus.loading, clearError: true));
    final result = await getEmployeesUseCase();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: PayrollStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (employees) {
        final all = [...employees]
          ..sort((a, b) => a.employeeName.compareTo(b.employeeName));
        final ready = state.copyWith(
          status: PayrollStatus.ready,
          employees: all,
          selectedIds: const {},
        );
        // Self-service (single row): pre-select so Download slip works immediately.
        final visible = ready.employeesForPeriod;
        final selected = visible.length == 1
            ? {visible.first.employeeId}
            : <String>{};
        emit(ready.copyWith(selectedIds: selected));
      },
    );
  }

  void _onMonthChanged(
    PayrollMonthChanged event,
    Emitter<PayrollState> emit,
  ) {
    final next = state.copyWith(month: event.month, year: event.year);
    final visibleIds =
        next.employeesForPeriod.map((e) => e.employeeId).toSet();
    emit(
      next.copyWith(
        selectedIds: state.selectedIds.intersection(visibleIds),
      ),
    );
  }

  void _onToggled(
    PayrollEmployeeToggled event,
    Emitter<PayrollState> emit,
  ) {
    final next = Set<String>.from(state.selectedIds);
    if (next.contains(event.employeeId)) {
      next.remove(event.employeeId);
    } else {
      next.add(event.employeeId);
    }
    emit(state.copyWith(selectedIds: next));
  }

  void _onSelectAll(
    PayrollSelectAllToggled event,
    Emitter<PayrollState> emit,
  ) {
    if (state.allSelected) {
      emit(state.copyWith(selectedIds: {}));
    } else {
      emit(
        state.copyWith(
          selectedIds:
              state.employeesForPeriod.map((e) => e.employeeId).toSet(),
        ),
      );
    }
  }

  Future<void> _onDownloadSelected(
    PayrollDownloadSelected event,
    Emitter<PayrollState> emit,
  ) async {
    final selected = state.employeesForPeriod
        .where((e) => state.selectedIds.contains(e.employeeId))
        .toList();
    if (selected.isEmpty) {
      emit(
        state.copyWith(
          status: PayrollStatus.failure,
          errorMessage: 'Select at least one employee.',
        ),
      );
      emit(state.copyWith(status: PayrollStatus.ready, clearError: true));
      return;
    }
    await _download(selected, emit);
  }

  Future<void> _onDownloadAll(
    PayrollDownloadAll event,
    Emitter<PayrollState> emit,
  ) async {
    final visible = state.employeesForPeriod;
    if (visible.isEmpty) {
      emit(
        state.copyWith(
          status: PayrollStatus.failure,
          errorMessage: 'No employees had joined in this payroll month.',
        ),
      );
      emit(state.copyWith(status: PayrollStatus.ready, clearError: true));
      return;
    }
    await _download(visible, emit);
  }

  Future<void> _download(
    List<Employee> employees,
    Emitter<PayrollState> emit,
  ) async {
    final eligible = employees
        .where(
          (e) => PayslipPeriod.isEligible(
            e,
            month: state.month,
            year: state.year,
          ),
        )
        .toList(growable: false);

    if (eligible.isEmpty) {
      emit(
        state.copyWith(
          status: PayrollStatus.failure,
          errorMessage: employees.length == 1
              ? 'No salary slip for this month — joining date is later.'
              : 'No selected employees had joined in this payroll month.',
        ),
      );
      emit(state.copyWith(status: PayrollStatus.ready, clearError: true));
      return;
    }

    emit(state.copyWith(status: PayrollStatus.generating, clearError: true));
    try {
      for (var i = 0; i < eligible.length; i++) {
        final employee = eligible[i];
        final slip = PayslipCalculator.fromEmployee(
          employee: employee,
          month: state.month,
          year: state.year,
        );
        final doc = await PayslipPdfBuilder.build([slip]);
        final bytes = await doc.save();
        final filename =
            'Payslip_${employee.employeeId}_${slip.periodLabel}.pdf';
        await savePdfBytes(bytes: bytes, filename: filename);
        // Give the browser time between downloads so each file is saved.
        if (i < eligible.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
      emit(state.copyWith(status: PayrollStatus.ready));
    } catch (e, st) {
      debugPrint('Payslip download failed: $e\n$st');
      emit(
        state.copyWith(
          status: PayrollStatus.failure,
          errorMessage: 'Could not generate payslip. Try again.',
        ),
      );
      emit(state.copyWith(status: PayrollStatus.ready, clearError: true));
    }
  }
}