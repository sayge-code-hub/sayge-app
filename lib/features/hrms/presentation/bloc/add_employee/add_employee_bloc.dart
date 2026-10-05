import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../settings/domain/entities/client.dart';
import '../../../../settings/domain/usecases/get_clients.dart';
import '../../../domain/entities/employee.dart';
import '../../../domain/usecases/add_employee.dart';
import '../../../domain/usecases/get_employees.dart';
import '../../../domain/usecases/update_employee.dart';

part 'add_employee_event.dart';
part 'add_employee_state.dart';

class AddEmployeeBloc extends Bloc<AddEmployeeEvent, AddEmployeeState> {
  AddEmployeeBloc({
    required this.addEmployeeUseCase,
    required this.updateEmployeeUseCase,
    required this.getClientsUseCase,
    required this.getEmployeesUseCase,
  }) : super(const AddEmployeeState()) {
    on<AddEmployeeStarted>(_onStarted);
    on<AddEmployeeFieldChanged>(_onFieldChanged);
    on<AddEmployeeSubmitted>(_onSubmitted);
  }

  /// First auto-assigned id when no higher numeric id exists yet.
  static const int employeeIdSequenceStart = 2127;

  final AddEmployeeUseCase addEmployeeUseCase;
  final UpdateEmployeeUseCase updateEmployeeUseCase;
  final GetClientsUseCase getClientsUseCase;
  final GetEmployeesUseCase getEmployeesUseCase;

  /// Formats money for form fields without forcing whole-rupee rounding.
  static String _moneyField(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(2);
  }

  Future<void> _onStarted(
    AddEmployeeStarted event,
    Emitter<AddEmployeeState> emit,
  ) async {
    final clientsResult = await getClientsUseCase();
    final allClients = clientsResult.fold(
      (_) => <Client>[],
      (list) => list,
    );

    final employee = event.employee;
    if (employee == null) {
      final nextId = await _nextEmployeeId();
      emit(
        AddEmployeeState(
          availableClients: [
            for (final client in allClients)
              if (client.isActive) client,
          ],
          employeeId: nextId,
          status: AddEmployeeStatus.editing,
        ),
      );
      return;
    }

    final linkedClientId = employee.clientId;
    emit(
      AddEmployeeState(
        isEditMode: true,
        status: AddEmployeeStatus.editing,
        availableClients: [
          for (final client in allClients)
            if (client.isActive || client.id == linkedClientId) client,
        ],
        employeeId: employee.employeeId,
        employeeName: employee.employeeName,
        dateOfJoining: employee.dateOfJoining,
        dateOfBirth: employee.dateOfBirth,
        designation: employee.designation,
        department: employee.department,
        annualCtc: _moneyField(employee.annualCtc),
        monthlyCtc: _moneyField(employee.monthlyCtc),
        monthlyRate: _moneyField(employee.monthlyRate),
        pfApplicable: employee.pfApplicable,
        ptApplicable: employee.ptApplicable,
        medicalInsurance: _moneyField(employee.medicalInsurance),
        retentionAmount: _moneyField(employee.retentionAmount),
        tdsAmount: _moneyField(employee.tdsAmount),
        specialAllowance: _moneyField(employee.specialAllowance),
        bankAccount: employee.bankAccount,
        ifsc: employee.ifsc,
        pan: employee.pan,
        uan: employee.uan,
        contactNo: employee.contactNo,
        residentialAddress: employee.residentialAddress,
        alternateContact: employee.alternateContact,
        personalEmail: employee.personalEmail,
        gender: employee.gender,
        fatherName: employee.fatherName,
        motherName: employee.motherName,
        nationality: employee.nationality,
        pincode: employee.pincode,
        isActive: employee.isActive,
        location: employee.location,
        grade: employee.grade,
        clientId: employee.clientId,
      ),
    );
  }

  Future<String> _nextEmployeeId() async {
    final result = await getEmployeesUseCase();
    var highest = employeeIdSequenceStart - 1;
    result.fold((_) {}, (employees) {
      for (final employee in employees) {
        final parsed = int.tryParse(employee.employeeId.trim());
        if (parsed != null && parsed > highest) {
          highest = parsed;
        }
      }
    });
    return '${highest + 1}';
  }

  void _onFieldChanged(
    AddEmployeeFieldChanged event,
    Emitter<AddEmployeeState> emit,
  ) {
    emit(
      state.copyWith(
        // Employee ID is allocated automatically on create; ignore edits.
        employeeId: state.isEditMode ? event.employeeId : null,
        employeeName: event.employeeName,
        dateOfJoining: event.dateOfJoining,
        dateOfBirth: event.dateOfBirth,
        designation: event.designation,
        department: event.department,
        annualCtc: event.annualCtc,
        monthlyCtc: event.monthlyCtc,
        monthlyRate: event.monthlyRate,
        pfApplicable: event.pfApplicable,
        ptApplicable: event.ptApplicable,
        medicalInsurance: event.medicalInsurance,
        retentionAmount: event.retentionAmount,
        tdsAmount: event.tdsAmount,
        specialAllowance: event.specialAllowance,
        bankAccount: event.bankAccount,
        ifsc: event.ifsc,
        pan: event.pan,
        uan: event.uan,
        contactNo: event.contactNo,
        residentialAddress: event.residentialAddress,
        alternateContact: event.alternateContact,
        personalEmail: event.personalEmail,
        gender: event.gender,
        fatherName: event.fatherName,
        motherName: event.motherName,
        nationality: event.nationality,
        pincode: event.pincode,
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

    var employeeId = state.employeeId.trim();
    if (!state.isEditMode) {
      // Re-allocate at submit to reduce collision if another hire was saved.
      employeeId = await _nextEmployeeId();
      emit(state.copyWith(employeeId: employeeId));
    }

    final selected = state.selectedClient;
    final employee = Employee(
      employeeId: employeeId,
      employeeName: state.employeeName.trim(),
      dateOfJoining: state.dateOfJoining!,
      dateOfBirth: state.dateOfBirth,
      designation: state.designation.trim(),
      department: state.department.trim(),
      annualCtc: double.parse(state.annualCtc.trim()),
      monthlyCtc: double.parse(state.monthlyCtc.trim()),
      monthlyRate: double.tryParse(state.monthlyRate.trim()) ?? 0,
      pfApplicable: state.pfApplicable!,
      ptApplicable: state.ptApplicable!,
      medicalInsurance: double.parse(state.medicalInsurance.trim()),
      retentionAmount: double.parse(state.retentionAmount.trim()),
      tdsAmount: double.parse(state.tdsAmount.trim()),
      specialAllowance: double.parse(state.specialAllowance.trim()),
      bankAccount: state.bankAccount.trim(),
      ifsc: state.ifsc.trim(),
      pan: state.pan.trim().toUpperCase(),
      uan: state.uan.trim(),
      contactNo: state.contactNo.trim(),
      residentialAddress: state.residentialAddress.trim(),
      alternateContact: state.alternateContact.trim(),
      personalEmail: state.personalEmail.trim(),
      gender: state.gender.trim(),
      fatherName: state.fatherName.trim(),
      motherName: state.motherName.trim(),
      nationality: state.nationality.trim(),
      pincode: state.pincode.trim(),
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
