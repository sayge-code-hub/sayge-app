import 'package:equatable/equatable.dart';

class Employee extends Equatable {
  const Employee({
    required this.employeeId,
    required this.employeeName,
    required this.dateOfJoining,
    required this.designation,
    required this.department,
    required this.annualCtc,
    required this.monthlyCtc,
    this.monthlyRate = 0,
    required this.pfApplicable,
    required this.ptApplicable,
    required this.medicalInsurance,
    required this.retentionAmount,
    this.tdsAmount = 0,
    this.specialAllowance = 0,
    required this.bankAccount,
    required this.ifsc,
    required this.pan,
    required this.uan,
    required this.isActive,
    this.dateOfExit,
    required this.location,
    required this.grade,
    required this.clientId,
    required this.client,
    this.dateOfBirth,
  });

  final String employeeId;
  final String employeeName;
  final DateTime dateOfJoining;
  final DateTime? dateOfBirth;
  final String designation;
  final String department;
  final double annualCtc;
  final double monthlyCtc;
  /// Client billing monthly rate (proposals); distinct from payroll monthly CTC.
  final double monthlyRate;
  final bool pfApplicable;
  final bool ptApplicable;
  final double medicalInsurance;
  final double retentionAmount;
  /// Monthly income tax (TDS) deduction; stored on employee master.
  final double tdsAmount;
  /// Fixed special allowance carved from gross before Basic/HRA split.
  final double specialAllowance;
  final String bankAccount;
  final String ifsc;
  final String pan;
  final String uan;
  final bool isActive;
  /// Last working day when exited from the organisation; null if still employed.
  final DateTime? dateOfExit;
  final String location;
  final String grade;
  /// FK to [clients.id].
  final String clientId;
  /// Resolved client display name (from join).
  final String client;

  Employee copyWith({
    String? employeeId,
    String? employeeName,
    DateTime? dateOfJoining,
    DateTime? dateOfBirth,
    String? designation,
    String? department,
    double? annualCtc,
    double? monthlyCtc,
    double? monthlyRate,
    bool? pfApplicable,
    bool? ptApplicable,
    double? medicalInsurance,
    double? retentionAmount,
    double? tdsAmount,
    double? specialAllowance,
    String? bankAccount,
    String? ifsc,
    String? pan,
    String? uan,
    bool? isActive,
    DateTime? dateOfExit,
    bool clearDateOfExit = false,
    String? location,
    String? grade,
    String? clientId,
    String? client,
  }) {
    return Employee(
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      dateOfJoining: dateOfJoining ?? this.dateOfJoining,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      annualCtc: annualCtc ?? this.annualCtc,
      monthlyCtc: monthlyCtc ?? this.monthlyCtc,
      monthlyRate: monthlyRate ?? this.monthlyRate,
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
      dateOfExit: clearDateOfExit ? null : (dateOfExit ?? this.dateOfExit),
      location: location ?? this.location,
      grade: grade ?? this.grade,
      clientId: clientId ?? this.clientId,
      client: client ?? this.client,
    );
  }

  @override
  List<Object?> get props => [
        employeeId,
        employeeName,
        dateOfJoining,
        dateOfBirth,
        designation,
        department,
        annualCtc,
        monthlyCtc,
        monthlyRate,
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
        dateOfExit,
        location,
        grade,
        clientId,
        client,
      ];
}
