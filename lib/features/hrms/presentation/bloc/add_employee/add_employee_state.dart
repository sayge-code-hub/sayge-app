part of 'add_employee_bloc.dart';

enum AddEmployeeStatus { initial, editing, loading, success, failure }

class AddEmployeeState extends Equatable {
  const AddEmployeeState({
    this.status = AddEmployeeStatus.initial,
    this.isEditMode = false,
    this.employeeId = '',
    this.employeeName = '',
    this.dateOfJoining,
    this.dateOfBirth,
    this.designation = '',
    this.department = '',
    this.annualCtc = '',
    this.monthlyCtc = '',
    this.pfApplicable,
    this.ptApplicable,
    this.medicalInsurance = '650',
    this.retentionAmount = '2000',
    this.tdsAmount = '0',
    this.specialAllowance = '0',
    this.bankAccount = '',
    this.ifsc = '',
    this.pan = '',
    this.uan = '',
    this.isActive = true,
    this.location = '',
    this.grade = '',
    this.clientId,
    this.availableClients = const [],
    this.errorMessage,
  });

  final AddEmployeeStatus status;
  final bool isEditMode;
  final String employeeId;
  final String employeeName;
  final DateTime? dateOfJoining;
  final DateTime? dateOfBirth;
  final String designation;
  final String department;
  final String annualCtc;
  final String monthlyCtc;
  final bool? pfApplicable;
  final bool? ptApplicable;
  final String medicalInsurance;
  final String retentionAmount;
  final String tdsAmount;
  final String specialAllowance;
  final String bankAccount;
  final String ifsc;
  final String pan;
  final String uan;
  final bool? isActive;
  final String location;
  final String grade;
  final String? clientId;
  final List<Client> availableClients;
  final String? errorMessage;

  Client? get selectedClient {
    final id = clientId;
    if (id == null) return null;
    for (final client in availableClients) {
      if (client.id == id) return client;
    }
    return null;
  }

  String? validate() {
    if (employeeId.trim().isEmpty) return 'Employee ID is required';
    if (employeeName.trim().isEmpty) return 'Employee name is required';
    if (dateOfJoining == null) return 'Date of joining is required';
    if (designation.trim().isEmpty) return 'Designation is required';
    if (department.trim().isEmpty) return 'Department is required';
    if (double.tryParse(annualCtc.trim()) == null) {
      return 'Enter a valid annual CTC';
    }
    if (double.tryParse(monthlyCtc.trim()) == null) {
      return 'Enter a valid monthly CTC';
    }
    if (pfApplicable == null) return 'Select PF applicable';
    if (ptApplicable == null) return 'Select PT applicable';
    if (double.tryParse(medicalInsurance.trim()) == null) {
      return 'Enter a valid medical insurance amount';
    }
    if (double.tryParse(retentionAmount.trim()) == null) {
      return 'Enter a valid retention amount';
    }
    if (double.tryParse(tdsAmount.trim()) == null) {
      return 'Enter a valid TDS amount';
    }
    if (double.tryParse(specialAllowance.trim()) == null) {
      return 'Enter a valid special allowance';
    }
    if (pan.trim().isEmpty) return 'PAN is required';
    if (isActive == null) return 'Select active status';
    if (location.trim().isEmpty) return 'Location is required';
    if (grade.trim().isEmpty) return 'Grade is required';
    if (clientId == null || clientId!.trim().isEmpty) {
      return 'Select a client';
    }
    return null;
  }

  AddEmployeeState copyWith({
    AddEmployeeStatus? status,
    bool? isEditMode,
    String? employeeId,
    String? employeeName,
    DateTime? dateOfJoining,
    DateTime? dateOfBirth,
    String? designation,
    String? department,
    String? annualCtc,
    String? monthlyCtc,
    bool? pfApplicable,
    bool? ptApplicable,
    String? medicalInsurance,
    String? retentionAmount,
    String? tdsAmount,
    String? specialAllowance,
    String? bankAccount,
    String? ifsc,
    String? pan,
    String? uan,
    bool? isActive,
    String? location,
    String? grade,
    String? clientId,
    List<Client>? availableClients,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AddEmployeeState(
      status: status ?? this.status,
      isEditMode: isEditMode ?? this.isEditMode,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      dateOfJoining: dateOfJoining ?? this.dateOfJoining,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      annualCtc: annualCtc ?? this.annualCtc,
      monthlyCtc: monthlyCtc ?? this.monthlyCtc,
      pfApplicable: pfApplicable ?? this.pfApplicable,
      ptApplicable: ptApplicable ?? this.ptApplicable,
      medicalInsurance: medicalInsurance ?? this.medicalInsurance,
      retentionAmount: retentionAmount ?? this.retentionAmount,
      tdsAmount: tdsAmount ?? this.tdsAmount,
      specialAllowance: specialAllowance ?? this.specialAllowance,
      bankAccount: bankAccount ?? this.bankAccount,
      ifsc: ifsc ?? this.ifsc,
      pan: pan ?? this.pan,
      uan: uan ?? this.uan,
      isActive: isActive ?? this.isActive,
      location: location ?? this.location,
      grade: grade ?? this.grade,
      clientId: clientId ?? this.clientId,
      availableClients: availableClients ?? this.availableClients,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        isEditMode,
        employeeId,
        employeeName,
        dateOfJoining,
        dateOfBirth,
        designation,
        department,
        annualCtc,
        monthlyCtc,
        pfApplicable,
        ptApplicable,
        medicalInsurance,
        retentionAmount,
        tdsAmount,
        specialAllowance,
        bankAccount,
        ifsc,
        pan,
        uan,
        isActive,
        location,
        grade,
        clientId,
        availableClients,
        errorMessage,
      ];
}
