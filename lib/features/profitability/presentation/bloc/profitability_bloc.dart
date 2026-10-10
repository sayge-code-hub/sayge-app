import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/pdf_saver.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/domain/usecases/expense_usecases.dart';
import '../../../hrms/domain/usecases/get_employees.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/usecases/invoice_usecases.dart';
import '../../domain/entities/profitability.dart';
import '../../domain/services/profitability_calculator.dart';

part 'profitability_event.dart';
part 'profitability_state.dart';

class ProfitabilityBloc extends Bloc<ProfitabilityEvent, ProfitabilityState> {
  ProfitabilityBloc({
    required this.getEmployeesUseCase,
    required this.getExpensesUseCase,
    required this.getInvoicesUseCase,
  }) : super(
          ProfitabilityState(
            fyStartYear: ProfitabilityCalculator.currentFinancialYearStart(),
          ),
        ) {
    on<ProfitabilityStarted>(_onStarted);
    on<ProfitabilitySearchChanged>(_onSearchChanged);
    on<ProfitabilityFyChanged>(_onFyChanged);
    on<ProfitabilityExportRequested>(_onExportRequested);
  }

  final GetEmployeesUseCase getEmployeesUseCase;
  final GetExpensesUseCase getExpensesUseCase;
  final GetInvoicesUseCase getInvoicesUseCase;

  Future<void> _onStarted(
    ProfitabilityStarted event,
    Emitter<ProfitabilityState> emit,
  ) async {
    emit(state.copyWith(status: ProfitabilityStatus.loading, clearError: true));

    final employeesResult = await getEmployeesUseCase();
    final expensesResult = await getExpensesUseCase();
    final invoicesResult = await getInvoicesUseCase();

    List<Expense> expenses = const [];
    expensesResult.fold((_) {}, (list) => expenses = list);

    List<Invoice> invoices = const [];
    invoicesResult.fold((_) {}, (list) => invoices = list);

    employeesResult.fold(
      (failure) => emit(
        state.copyWith(
          status: ProfitabilityStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (employees) {
        final rows = ProfitabilityCalculator.forEmployees(employees);
        final clients = ProfitabilityCalculator.rollUpByClient(
          rows,
          expenses: expenses,
          invoices: invoices,
        );
        emit(
          state.copyWith(
            status: ProfitabilityStatus.ready,
            employees: rows,
            clients: clients,
            expenses: expenses,
            invoices: invoices,
          ),
        );
      },
    );
  }

  void _onSearchChanged(
    ProfitabilitySearchChanged event,
    Emitter<ProfitabilityState> emit,
  ) {
    emit(state.copyWith(query: event.query));
  }

  void _onFyChanged(
    ProfitabilityFyChanged event,
    Emitter<ProfitabilityState> emit,
  ) {
    emit(state.copyWith(fyStartYear: event.fyStartYear));
  }

  Future<void> _onExportRequested(
    ProfitabilityExportRequested event,
    Emitter<ProfitabilityState> emit,
  ) async {
    if (state.status != ProfitabilityStatus.ready) return;
    final csv = ProfitabilityCalculator.exportCsv(
      state.filteredClients,
      fyStartYear: state.fyStartYear,
      expenses: state.expenses,
      invoices: state.invoices,
    );
    final label = ProfitabilityCalculator.financialYearLabel(state.fyStartYear)
        .replaceAll(' ', '_');
    await saveDownloadBytes(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      filename: 'profitability_$label.csv',
      mimeType: 'text/csv',
    );
  }
}
