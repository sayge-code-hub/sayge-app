part of 'add_employee_bloc.dart';

abstract class AddEmployeeEvent extends Equatable {
  const AddEmployeeEvent();

  @override
  List<Object?> get props => [];
}

class AddEmployeeStarted extends AddEmployeeEvent {
  const AddEmployeeStarted({this.employee});

  final Employee? employee;

  @override
  List<Object?> get props => [employee];
}

class AddEmployeeFieldChanged extends AddEmployeeEvent {
  const AddEmployeeFieldChanged({
    this.employeeId,
    this.employeeName,
    this.dateOfJoining,
    this.dateOfBirth,
    this.designation,
    this.department,
    this.annualCtc,
    this.monthlyCtc,
    this.monthlyRate,
    this.pfApplicable,
    this.ptApplicable,
    this.medicalInsurance,
    this.retentionAmount,
    this.tdsAmount,
    this.specialAllowance,
    this.bankAccount,
    this.ifsc,
    this.pan,
    this.uan,
    this.contactNo,
    this.residentialAddress,
    this.alternateContact,
    this.personalEmail,
    this.gender,
    this.fatherName,
    this.motherName,
    this.nationality,
    this.pincode,
    this.isActive,
    this.location,
    this.grade,
    this.clientId,
  });

  final String? employeeId;
  final String? employeeName;
  final DateTime? dateOfJoining;
  final DateTime? dateOfBirth;
  final String? designation;
  final String? department;
  final String? annualCtc;
  final String? monthlyCtc;
  final String? monthlyRate;
  final bool? pfApplicable;
  final bool? ptApplicable;
  final String? medicalInsurance;
  final String? retentionAmount;
  final String? tdsAmount;
  final String? specialAllowance;
  final String? bankAccount;
  final String? ifsc;
  final String? pan;
  final String? uan;
  final String? contactNo;
  final String? residentialAddress;
  final String? alternateContact;
  final String? personalEmail;
  final String? gender;
  final String? fatherName;
  final String? motherName;
  final String? nationality;
  final String? pincode;
  final bool? isActive;
  final String? location;
  final String? grade;
  final String? clientId;

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
        contactNo,
        residentialAddress,
        alternateContact,
        personalEmail,
        gender,
        fatherName,
        motherName,
        nationality,
        pincode,
        isActive,
        location,
        grade,
        clientId,
      ];
}

class AddEmployeeSubmitted extends AddEmployeeEvent {
  const AddEmployeeSubmitted({this.asDraft = false});

  final bool asDraft;

  @override
  List<Object?> get props => [asDraft];
}
