import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/employee_purchase_order.dart';
import '../../../domain/repositories/employee_purchase_order_repository.dart';
import '../../../domain/usecases/employee_purchase_order_usecases.dart';

part 'employee_po_event.dart';
part 'employee_po_state.dart';

class EmployeePoBloc extends Bloc<EmployeePoEvent, EmployeePoState> {
  EmployeePoBloc({
    required this.getPosUseCase,
    required this.createPoUseCase,
    required this.updatePoUseCase,
    required this.deletePoUseCase,
    required this.getDownloadUrlUseCase,
  }) : super(const EmployeePoState()) {
    on<EmployeePoRequested>(_onRequested);
    on<EmployeePoSubmitted>(_onSubmitted);
    on<EmployeePoUpdated>(_onUpdated);
    on<EmployeePoDeleted>(_onDeleted);
    on<EmployeePoDownloadRequested>(_onDownload);
  }

  final GetEmployeePurchaseOrdersUseCase getPosUseCase;
  final CreateEmployeePurchaseOrderUseCase createPoUseCase;
  final UpdateEmployeePurchaseOrderUseCase updatePoUseCase;
  final DeleteEmployeePurchaseOrderUseCase deletePoUseCase;
  final GetEmployeePurchaseOrderDownloadUrlUseCase getDownloadUrlUseCase;

  Future<void> _onRequested(
    EmployeePoRequested event,
    Emitter<EmployeePoState> emit,
  ) async {
    emit(
      state.copyWith(
        status: EmployeePoStatus.loading,
        employeeId: event.employeeId,
        clearError: true,
        clearMessage: true,
      ),
    );
    final result = await getPosUseCase(event.employeeId);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: EmployeePoStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (list) => emit(
        state.copyWith(
          status: EmployeePoStatus.ready,
          orders: list,
        ),
      ),
    );
  }

  Future<void> _refreshOrders(
    Emitter<EmployeePoState> emit, {
    required String successMessage,
    EmployeePurchaseOrder? fallbackOrder,
    bool prependFallback = false,
  }) async {
    final employeeId = state.employeeId;
    if (employeeId == null || employeeId.isEmpty) {
      emit(
        state.copyWith(
          status: EmployeePoStatus.ready,
          successMessage: successMessage,
        ),
      );
      return;
    }
    final refreshed = await getPosUseCase(employeeId);
    refreshed.fold(
      (_) {
        var orders = state.orders;
        if (fallbackOrder != null) {
          if (prependFallback) {
            orders = [fallbackOrder, ...orders];
          } else {
            orders = [
              for (final o in orders)
                if (o.id == fallbackOrder.id) fallbackOrder else o,
            ];
          }
        }
        emit(
          state.copyWith(
            status: EmployeePoStatus.ready,
            orders: orders,
            successMessage: successMessage,
          ),
        );
      },
      (list) => emit(
        state.copyWith(
          status: EmployeePoStatus.ready,
          orders: list,
          successMessage: successMessage,
        ),
      ),
    );
  }

  Future<void> _onSubmitted(
    EmployeePoSubmitted event,
    Emitter<EmployeePoState> emit,
  ) async {
    final employeeId = state.employeeId ?? event.employeeId;
    emit(state.copyWith(status: EmployeePoStatus.saving, clearError: true));

    final result = await createPoUseCase(
      CreateEmployeePurchaseOrderParams(
        employeeId: employeeId,
        poNumber: event.poNumber,
        startDate: event.startDate,
        endDate: event.endDate,
        fileName: event.fileName,
        fileBytes: event.fileBytes,
        mimeType: event.mimeType,
      ),
    );

    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: EmployeePoStatus.failure,
            errorMessage: failure.message,
          ),
        );
        emit(state.copyWith(status: EmployeePoStatus.ready, clearError: true));
      },
      (created) async {
        await _refreshOrders(
          emit,
          successMessage: 'Purchase order added.',
          fallbackOrder: created,
          prependFallback: true,
        );
      },
    );
  }

  Future<void> _onUpdated(
    EmployeePoUpdated event,
    Emitter<EmployeePoState> emit,
  ) async {
    emit(state.copyWith(status: EmployeePoStatus.saving, clearError: true));

    final result = await updatePoUseCase(
      UpdateEmployeePurchaseOrderParams(
        id: event.id,
        poNumber: event.poNumber,
        startDate: event.startDate,
        endDate: event.endDate,
        fileName: event.fileName,
        fileBytes: event.fileBytes,
        mimeType: event.mimeType,
      ),
    );

    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: EmployeePoStatus.failure,
            errorMessage: failure.message,
          ),
        );
        emit(state.copyWith(status: EmployeePoStatus.ready, clearError: true));
      },
      (updated) async {
        await _refreshOrders(
          emit,
          successMessage: 'Purchase order updated.',
          fallbackOrder: updated,
        );
      },
    );
  }

  Future<void> _onDeleted(
    EmployeePoDeleted event,
    Emitter<EmployeePoState> emit,
  ) async {
    emit(state.copyWith(status: EmployeePoStatus.saving, clearError: true));

    final result = await deletePoUseCase(event.id);

    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: EmployeePoStatus.failure,
            errorMessage: failure.message,
          ),
        );
        emit(state.copyWith(status: EmployeePoStatus.ready, clearError: true));
      },
      (_) async {
        final employeeId = state.employeeId;
        if (employeeId == null || employeeId.isEmpty) {
          emit(
            state.copyWith(
              status: EmployeePoStatus.ready,
              orders: [
                for (final o in state.orders)
                  if (o.id != event.id) o,
              ],
              successMessage: 'Purchase order deleted.',
            ),
          );
          return;
        }
        final refreshed = await getPosUseCase(employeeId);
        refreshed.fold(
          (_) => emit(
            state.copyWith(
              status: EmployeePoStatus.ready,
              orders: [
                for (final o in state.orders)
                  if (o.id != event.id) o,
              ],
              successMessage: 'Purchase order deleted.',
            ),
          ),
          (list) => emit(
            state.copyWith(
              status: EmployeePoStatus.ready,
              orders: list,
              successMessage: 'Purchase order deleted.',
            ),
          ),
        );
      },
    );
  }

  Future<void> _onDownload(
    EmployeePoDownloadRequested event,
    Emitter<EmployeePoState> emit,
  ) async {
    final result = await getDownloadUrlUseCase(event.order);
    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: EmployeePoStatus.failure,
            errorMessage: failure.message,
          ),
        );
        emit(state.copyWith(status: EmployeePoStatus.ready, clearError: true));
      },
      (url) {
        emit(state.copyWith(clearDownload: true));
        emit(
          state.copyWith(
            status: EmployeePoStatus.ready,
            downloadUrl: url,
            downloadFileName: event.order.fileName,
          ),
        );
      },
    );
  }
}
