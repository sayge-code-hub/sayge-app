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
    this.contactNo = '',
    this.residentialAddress = '',
    this.alternateContact = '',
    this.personalEmail = '',
    this.gender = '',
    this.fatherName = '',
    this.motherName = '',
    this.nationality = '',
    this.pincode = '',
    required this.isActive,
    this.isDraft = false,
    this.dateOfExit,
    required this.location,
    required this.grade,
    required this.clientId,
    required this.client,
    this.dateOfBirth,
    this.photoPath,
    this.photoUrl,
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
  /// Mobile / contact phone number.
  final String contactNo;
  final String residentialAddress;
  final String alternateContact;
  final String personalEmail;
  final String gender;
  final String fatherName;
  final String motherName;
  final String nationality;
  final String pincode;
  final bool isActive;
  /// Incomplete profile kept for invite linking / later completion.
  final bool isDraft;
  /// Last working day when exited from the organisation; null if still employed.
  final DateTime? dateOfExit;
  final String location;
  final String grade;
  /// FK to [clients.id].
  final String clientId;
  /// Resolved client display name (from join).
  final String client;
  final String? photoPath;
  final String? photoUrl;

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
    String? contactNo,
    String? residentialAddress,
    String? alternateContact,
    String? personalEmail,
    String? gender,
    String? fatherName,
    String? motherName,
    String? nationality,
    String? pincode,
    bool? isActive,
    bool? isDraft,
    DateTime? dateOfExit,
    bool clearDateOfExit = false,
    String? location,
    String? grade,
    String? clientId,
    String? client,
    String? photoPath,
    String? photoUrl,
    bool clearPhotoPath = false,
    bool clearPhotoUrl = false,
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
      contactNo: contactNo ?? this.contactNo,
      residentialAddress: residentialAddress ?? this.residentialAddress,
      alternateContact: alternateContact ?? this.alternateContact,
      personalEmail: personalEmail ?? this.personalEmail,
      gender: gender ?? this.gender,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      nationality: nationality ?? this.nationality,
      pincode: pincode ?? this.pincode,
      isActive: isActive ?? this.isActive,
      isDraft: isDraft ?? this.isDraft,
      dateOfExit: clearDateOfExit ? null : (dateOfExit ?? this.dateOfExit),
      location: location ?? this.location,
      grade: grade ?? this.grade,
      clientId: clientId ?? this.clientId,
      client: client ?? this.client,
      photoPath: clearPhotoPath ? null : (photoPath ?? this.photoPath),
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
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
        isDraft,
        dateOfExit,
        location,
        grade,
        clientId,
        client,
        photoPath,
        photoUrl,
      ];
}
