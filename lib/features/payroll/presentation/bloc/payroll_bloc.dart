import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/pdf_saver.dart';
import '../../../hrms/domain/entities/employee.dart';
import '../../../hrms/domain/usecases/get_employees.dart';
import '../../data/payslip_pdf_builder.dart';
import '../../domain/services/payslip_calculator.dart';

part 'payroll_event.dart';
part 'payroll_state.dart';

class PayrollBloc extends Bloc<PayrollEvent, PayrollState> {
  PayrollBloc({required this.getEmployeesUseCase})
      : super(PayrollState(
          month: DateTime.now().month,
          year: DateTime.now().year,
        )) {
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
        final active = employees.where((e) => e.isActive).toList()
          ..sort((a, b) => a.employeeName.compareTo(b.employeeName));
        emit(
          state.copyWith(
            status: PayrollStatus.ready,
            employees: active,
            selectedIds: {},
          ),
        );
      },
    );
  }

  void _onMonthChanged(
    PayrollMonthChanged event,
    Emitter<PayrollState> emit,
  ) {
    emit(state.copyWith(month: event.month, year: event.year));
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
          selectedIds: state.employees.map((e) => e.employeeId).toSet(),
        ),
      );
    }
  }

  Future<void> _onDownloadSelected(
    PayrollDownloadSelected event,
    Emitter<PayrollState> emit,
  ) async {
    final selected = state.employees
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
    if (state.employees.isEmpty) {
      emit(
        state.copyWith(
          status: PayrollStatus.failure,
          errorMessage: 'No active employees to download.',
        ),
      );
      emit(state.copyWith(status: PayrollStatus.ready, clearError: true));
      return;
    }
    await _download(state.employees, emit);
  }

  Future<void> _download(
    List<Employee> employees,
    Emitter<PayrollState> emit,
  ) async {
    emit(state.copyWith(status: PayrollStatus.generating, clearError: true));
    try {
      final slips = employees
          .map(
            (e) => PayslipCalculator.fromEmployee(
              employee: e,
              month: state.month,
              year: state.year,
            ),
          )
          .toList();
      final doc = await PayslipPdfBuilder.build(slips);
      final bytes = await doc.save();
      final label = employees.length == 1
          ? 'Payslip_${employees.first.employeeId}_'
              '${slips.first.periodLabel}.pdf'
          : 'Payslips_${slips.first.periodLabel}.pdf';

      await savePdfBytes(bytes: bytes, filename: label);
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
