import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../settings/domain/entities/client.dart';
import '../../../../settings/domain/usecases/get_clients.dart';
import '../../../domain/entities/employee.dart';
import '../../../domain/usecases/add_employee.dart';
import '../../../domain/usecases/update_employee.dart';

part 'add_employee_event.dart';
part 'add_employee_state.dart';

class AddEmployeeBloc extends Bloc<AddEmployeeEvent, AddEmployeeState> {
  AddEmployeeBloc({
    required this.addEmployeeUseCase,
    required this.updateEmployeeUseCase,
    required this.getClientsUseCase,
  }) : super(const AddEmployeeState()) {
    on<AddEmployeeStarted>(_onStarted);
    on<AddEmployeeFieldChanged>(_onFieldChanged);
    on<AddEmployeeSubmitted>(_onSubmitted);
  }

  final AddEmployeeUseCase addEmployeeUseCase;
  final UpdateEmployeeUseCase updateEmployeeUseCase;
  final GetClientsUseCase getClientsUseCase;

  Future<void> _onStarted(
    AddEmployeeStarted event,
    Emitter<AddEmployeeState> emit,
  ) async {
    final clientsResult = await getClientsUseCase();
    final clients = clientsResult.fold(
      (_) => <Client>[],
      (list) => list,
    );

    final employee = event.employee;
    if (employee == null) {
      emit(AddEmployeeState(availableClients: clients));
      return;
    }

    emit(
      AddEmployeeState(
        isEditMode: true,
        status: AddEmployeeStatus.editing,
        availableClients: clients,
        employeeId: employee.employeeId,
        employeeName: employee.employeeName,
        dateOfJoining: employee.dateOfJoining,
        designation: employee.designation,
        department: employee.department,
        annualCtc: employee.annualCtc.round().toString(),
        monthlyCtc: employee.monthlyCtc.round().toString(),
        pfApplicable: employee.pfApplicable,
        ptApplicable: employee.ptApplicable,
        medicalInsurance: employee.medicalInsurance.round().toString(),
        retentionAmount: employee.retentionAmount.round().toString(),
        bankAccount: employee.bankAccount,
        ifsc: employee.ifsc,
        pan: employee.pan,
        uan: employee.uan,
        isActive: employee.isActive,
        location: employee.location,
        grade: employee.grade,
        clientId: employee.clientId,
      ),
    );
  }

  void _onFieldChanged(
    AddEmployeeFieldChanged event,
    Emitter<AddEmployeeState> emit,
  ) {
    emit(
      state.copyWith(
        employeeId: event.employeeId,
        employeeName: event.employeeName,
        dateOfJoining: event.dateOfJoining,
        designation: event.designation,
        department: event.department,
        annualCtc: event.annualCtc,
        monthlyCtc: event.monthlyCtc,
        pfApplicable: event.pfApplicable,
        ptApplicable: event.ptApplicable,
        medicalInsurance: event.medicalInsurance,
        retentionAmount: event.retentionAmount,
        bankAccount: event.bankAccount,
        ifsc: event.ifsc,
        pan: event.pan,
        uan: event.uan,
        isActive: event.isActive,
        location: event.location,
        grade: event.grade,
        clientId: event.clientId,
        clearError: true,
        status: AddEmployeeStatus.editing,
      ),
    );
  }

  Future<void> _onSubmitted(
    AddEmployeeSubmitted event,
    Emitter<AddEmployeeState> emit,
  ) async {
    final validationError = state.validate();
    if (validationError != null) {
      emit(
        state.copyWith(
          status: AddEmployeeStatus.failure,
          errorMessage: validationError,
        ),
      );
      return;
    }

    emit(state.copyWith(status: AddEmployeeStatus.loading, clearError: true));

    final selected = state.selectedClient;
    final employee = Employee(
      employeeId: state.employeeId.trim(),
      employeeName: state.employeeName.trim(),
      dateOfJoining: state.dateOfJoining!,
      designation: state.designation.trim(),
      department: state.department.trim(),
      annualCtc: double.parse(state.annualCtc.trim()),
      monthlyCtc: double.parse(state.monthlyCtc.trim()),
      pfApplicable: state.pfApplicable!,
      ptApplicable: state.ptApplicable!,
      medicalInsurance: double.parse(state.medicalInsurance.trim()),
      retentionAmount: double.parse(state.retentionAmount.trim()),
      bankAccount: state.bankAccount.trim(),
      ifsc: state.ifsc.trim(),
      pan: state.pan.trim().toUpperCase(),
      uan: state.uan.trim(),
      isActive: state.isActive!,
      location: state.location.trim(),
      grade: state.grade.trim(),
      clientId: state.clientId!.trim(),
      client: selected?.name ?? '',
    );

    final result = state.isEditMode
        ? await updateEmployeeUseCase(employee)
        : await addEmployeeUseCase(employee);

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AddEmployeeStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (_) => emit(state.copyWith(status: AddEmployeeStatus.success)),
    );
  }
}
