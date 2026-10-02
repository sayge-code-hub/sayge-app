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
    required super.pfApplicable,
    required super.ptApplicable,
    required super.medicalInsurance,
    required super.retentionAmount,
    required super.bankAccount,
    required super.ifsc,
    required super.pan,
    required super.uan,
    required super.isActive,
    required super.location,
    required super.grade,
    required super.clientId,
    required super.client,
  });

  factory EmployeeModel.fromEntity(Employee employee) {
    return EmployeeModel(
      employeeId: employee.employeeId,
      employeeName: employee.employeeName,
      dateOfJoining: employee.dateOfJoining,
      designation: employee.designation,
      department: employee.department,
      annualCtc: employee.annualCtc,
      monthlyCtc: employee.monthlyCtc,
      pfApplicable: employee.pfApplicable,
      ptApplicable: employee.ptApplicable,
      medicalInsurance: employee.medicalInsurance,
      retentionAmount: employee.retentionAmount,
      bankAccount: employee.bankAccount,
      ifsc: employee.ifsc,
      pan: employee.pan,
      uan: employee.uan,
      isActive: employee.isActive,
      location: employee.location,
      grade: employee.grade,
      clientId: employee.clientId,
      client: employee.client,
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

    final dojRaw = json['date_of_joining'] ?? json['dateOfJoining'];
    final doj = dojRaw is DateTime
        ? dojRaw
        : DateTime.parse(dojRaw.toString());

    final clientJoin = json['clients'];
    final clientMap =
        clientJoin is Map<String, dynamic> ? clientJoin : <String, dynamic>{};
    final clientId = readString('client_id', 'clientId');
    final clientName = (clientMap['name'] as String?)?.trim().isNotEmpty == true
        ? (clientMap['name'] as String).trim()
        : readString('client');

    return EmployeeModel(
      employeeId: readString('employee_id', 'employeeId'),
      employeeName: readString('employee_name', 'employeeName'),
      dateOfJoining: doj,
      designation: readString('designation'),
      department: readString('department'),
      annualCtc: readNum('annual_ctc', 'annualCtc').toDouble(),
      monthlyCtc: readNum('monthly_ctc', 'monthlyCtc').toDouble(),
      pfApplicable: readBool('pf_applicable', 'pfApplicable'),
      ptApplicable: readBool('pt_applicable', 'ptApplicable'),
      medicalInsurance:
          readNum('medical_insurance', 'medicalInsurance').toDouble(),
      retentionAmount:
          readNum('retention_amount', 'retentionAmount').toDouble(),
      bankAccount: readString('bank_account', 'bankAccount'),
      ifsc: readString('ifsc'),
      pan: readString('pan'),
      uan: readString('uan'),
      isActive: readBool('is_active', 'isActive'),
      location: readString('location'),
      grade: readString('grade'),
      clientId: clientId.isNotEmpty
          ? clientId
          : (clientMap['id'] as String?)?.toString() ?? '',
      client: clientName,
    );
  }

  /// Persist shape — FK only; name comes from clients join on read.
  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'employee_name': employeeName,
      'date_of_joining':
          dateOfJoining.toIso8601String().split('T').first,
      'designation': designation,
      'department': department,
      'annual_ctc': annualCtc,
      'monthly_ctc': monthlyCtc,
      'pf_applicable': pfApplicable,
      'pt_applicable': ptApplicable,
      'medical_insurance': medicalInsurance,
      'retention_amount': retentionAmount,
      'bank_account': bankAccount,
      'ifsc': ifsc,
      'pan': pan,
      'uan': uan,
      'is_active': isActive,
      'location': location,
      'grade': grade,
      'client_id': clientId.isEmpty ? null : clientId,
    };
  }
}
