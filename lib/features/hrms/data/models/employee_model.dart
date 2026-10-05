import '../../domain/entities/employee.dart';

class EmployeeModel extends Employee {
  const EmployeeModel({
    required super.employeeId,
    required super.employeeName,
    required super.dateOfJoining,
    required super.designation,
    required super.department,
    required super.annualCtc,
    required super.monthlyCtc,
    super.monthlyRate,
    required super.pfApplicable,
    required super.ptApplicable,
    required super.medicalInsurance,
    required super.retentionAmount,
    super.tdsAmount,
    super.specialAllowance,
    required super.bankAccount,
    required super.ifsc,
    required super.pan,
    required super.uan,
    super.contactNo,
    super.residentialAddress,
    super.alternateContact,
    super.personalEmail,
    super.gender,
    super.fatherName,
    super.motherName,
    super.nationality,
    super.pincode,
    required super.isActive,
    super.isDraft,
    super.dateOfExit,
    required super.location,
    required super.grade,
    required super.clientId,
    required super.client,
    super.dateOfBirth,
    super.photoPath,
    super.photoUrl,
  });

  factory EmployeeModel.fromEntity(Employee employee) {
    return EmployeeModel(
      employeeId: employee.employeeId,
      employeeName: employee.employeeName,
      dateOfJoining: employee.dateOfJoining,
      dateOfBirth: employee.dateOfBirth,
      designation: employee.designation,
      department: employee.department,
      annualCtc: employee.annualCtc,
      monthlyCtc: employee.monthlyCtc,
      monthlyRate: employee.monthlyRate,
      pfApplicable: employee.pfApplicable,
      ptApplicable: employee.ptApplicable,
      medicalInsurance: employee.medicalInsurance,
      retentionAmount: employee.retentionAmount,
      tdsAmount: employee.tdsAmount,
      specialAllowance: employee.specialAllowance,
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
      isDraft: employee.isDraft,
      dateOfExit: employee.dateOfExit,
      location: employee.location,
      grade: employee.grade,
      clientId: employee.clientId,
      client: employee.client,
      photoPath: employee.photoPath,
      photoUrl: employee.photoUrl,
    );
  }

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    String readString(String snake, [String? camel]) {
      final value = json[snake] ?? (camel == null ? null : json[camel]);
      return (value ?? '').toString();
    }

    num readNum(String snake, [String? camel]) {
      final value = json[snake] ?? (camel == null ? null : json[camel]);
      if (value is num) return value;
      return num.tryParse(value?.toString() ?? '') ?? 0;
    }

    bool readBool(String snake, [String? camel]) {
      final value = json[snake] ?? (camel == null ? null : json[camel]);
      if (value is bool) return value;
      return value?.toString().toLowerCase() == 'true';
    }

    DateTime? readDate(String snake, [String? camel]) {
      final raw = json[snake] ?? (camel == null ? null : json[camel]);
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      final text = raw.toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    final doj = readDate('date_of_joining', 'dateOfJoining') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final clientJoin = json['clients'];
    final clientMap =
        clientJoin is Map<String, dynamic> ? clientJoin : <String, dynamic>{};
    final clientId = readString('client_id', 'clientId');
    final clientName = (clientMap['name'] as String?)?.trim().isNotEmpty == true
        ? (clientMap['name'] as String).trim()
        : readString('client');

    final photoPathRaw = readString('photo_path', 'photoPath');
    final photoPath = photoPathRaw.isEmpty ? null : photoPathRaw;
    final photoUrlRaw = readString('photo_url', 'photoUrl');
    final photoUrl = photoUrlRaw.isEmpty ? null : photoUrlRaw;

    return EmployeeModel(
      employeeId: readString('employee_id', 'employeeId'),
      employeeName: readString('employee_name', 'employeeName'),
      dateOfJoining: doj,
      dateOfBirth: readDate('date_of_birth', 'dateOfBirth'),
      designation: readString('designation'),
      department: readString('department'),
      annualCtc: readNum('annual_ctc', 'annualCtc').toDouble(),
      monthlyCtc: readNum('monthly_ctc', 'monthlyCtc').toDouble(),
      monthlyRate: readNum('monthly_rate', 'monthlyRate').toDouble(),
      pfApplicable: readBool('pf_applicable', 'pfApplicable'),
      ptApplicable: readBool('pt_applicable', 'ptApplicable'),
      medicalInsurance:
          readNum('medical_insurance', 'medicalInsurance').toDouble(),
      retentionAmount:
          readNum('retention_amount', 'retentionAmount').toDouble(),
      tdsAmount: readNum('tds_amount', 'tdsAmount').toDouble(),
      specialAllowance:
          readNum('special_allowance', 'specialAllowance').toDouble(),
      bankAccount: readString('bank_account', 'bankAccount'),
      ifsc: readString('ifsc'),
      pan: readString('pan'),
      uan: readString('uan'),
      contactNo: readString('contact_no', 'contactNo'),
      residentialAddress:
          readString('residential_address', 'residentialAddress'),
      alternateContact: readString('alternate_contact', 'alternateContact'),
      personalEmail: readString('personal_email', 'personalEmail'),
      gender: readString('gender'),
      fatherName: readString('father_name', 'fatherName'),
      motherName: readString('mother_name', 'motherName'),
      nationality: readString('nationality'),
      pincode: readString('pincode'),
      isActive: readBool('is_active', 'isActive'),
      isDraft: readBool('is_draft', 'isDraft'),
      dateOfExit: readDate('date_of_exit', 'dateOfExit'),
      location: readString('location'),
      grade: readString('grade'),
      clientId: clientId.isNotEmpty
          ? clientId
          : (clientMap['id'] as String?)?.toString() ?? '',
      client: clientName,
      photoPath: photoPath,
      photoUrl: photoUrl,
    );
  }

  /// Persist shape — FK only; name comes from clients join on read.
  Map<String, dynamic> toJson() {
    final photo = photoPath?.trim() ?? '';
    return {
      'employee_id': employeeId,
      'employee_name': employeeName,
      'date_of_joining':
          dateOfJoining.toIso8601String().split('T').first,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'designation': designation,
      'department': department,
      'annual_ctc': annualCtc,
      'monthly_ctc': monthlyCtc,
      'monthly_rate': monthlyRate,
      'pf_applicable': pfApplicable,
      'pt_applicable': ptApplicable,
      'medical_insurance': medicalInsurance,
      'retention_amount': retentionAmount,
      'tds_amount': tdsAmount,
      'special_allowance': specialAllowance,
      'bank_account': bankAccount,
      'ifsc': ifsc,
      'pan': pan,
      'uan': uan,
      'contact_no': contactNo,
      'residential_address': residentialAddress,
      'alternate_contact': alternateContact,
      'personal_email': personalEmail,
      'gender': gender,
      'father_name': fatherName,
      'mother_name': motherName,
      'nationality': nationality,
      'pincode': pincode,
      'is_active': isActive,
      'is_draft': isDraft,
      'date_of_exit': dateOfExit?.toIso8601String().split('T').first,
      'location': location,
      'grade': grade,
      'client_id': clientId.isEmpty ? null : clientId,
      if (photo.isNotEmpty) 'photo_path': photo,
    };
  }
}
