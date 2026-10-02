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
    required this.pfApplicable,
    required this.ptApplicable,
    required this.medicalInsurance,
    required this.retentionAmount,
    required this.bankAccount,
    required this.ifsc,
    required this.pan,
    required this.uan,
    required this.isActive,
    required this.location,
    required this.grade,
    required this.clientId,
    required this.client,
  });

  final String employeeId;
  final String employeeName;
  final DateTime dateOfJoining;
  final String designation;
  final String department;
  final double annualCtc;
  final double monthlyCtc;
  final bool pfApplicable;
  final bool ptApplicable;
  final double medicalInsurance;
  final double retentionAmount;
  final String bankAccount;
  final String ifsc;
  final String pan;
  final String uan;
  final bool isActive;
  final String location;
  final String grade;
  /// FK to [clients.id].
  final String clientId;
  /// Resolved client display name (from join).
  final String client;

  @override
  List<Object?> get props => [
        employeeId,
        employeeName,
        dateOfJoining,
        designation,
        department,
        annualCtc,
        monthlyCtc,
        pfApplicable,
        ptApplicable,
        medicalInsurance,
        retentionAmount,
        bankAccount,
        ifsc,
        pan,
        uan,
        isActive,
        location,
        grade,
        clientId,
        client,
      ];
}
