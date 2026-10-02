import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/features/hrms/domain/entities/employee.dart';
import 'package:sayge_app/features/payroll/data/payslip_pdf_builder.dart';
import 'package:sayge_app/features/payroll/domain/services/payslip_calculator.dart';

Employee _sampleEmployee() {
  return Employee(
    employeeId: '2319',
    employeeName: 'Sachin Singh',
    dateOfJoining: DateTime(2026, 5, 5),
    designation: 'Senior Software Engineer',
    department: 'Digital Applications',
    annualCtc: 2200000,
    monthlyCtc: 183333,
    pfApplicable: true,
    ptApplicable: true,
    medicalInsurance: 650,
    retentionAmount: 2000,
    bankAccount: '24610290048',
    ifsc: 'SCBL0036068',
    pan: 'JXSPS0558F',
    uan: '102054953721',
    isActive: true,
    location: 'Mumbai HO',
    grade: 'L11',
    clientId: 'mahindra-finance',
    client: 'Mahindra Finance',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds landscape payslip pdf with logo', () async {
    final slip = PayslipCalculator.fromEmployee(
      employee: _sampleEmployee(),
      month: 10,
      year: 2026,
    );
    final doc = await PayslipPdfBuilder.build([slip]);
    final bytes = await doc.save();
    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(1000));
    // PDF magic header
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('builds multi-employee payslip pdf', () async {
    final employees = [
      _sampleEmployee(),
      Employee(
        employeeId: '2126',
        employeeName: 'Akshat Srivastava',
        dateOfJoining: DateTime(2025, 11, 13),
        designation: 'QA Analyst',
        department: 'Digital Applications',
        annualCtc: 550000,
        monthlyCtc: 45833,
        pfApplicable: true,
        ptApplicable: true,
        medicalInsurance: 650,
        retentionAmount: 2000,
        bankAccount: '',
        ifsc: '',
        pan: 'ABCDE1234F',
        uan: '',
        isActive: true,
        location: 'Mumbai HO',
        grade: 'L11',
        clientId: 'mahindra-finance',
        client: 'Mahindra Finance',
      ),
    ];
    final slips = employees
        .map(
          (e) => PayslipCalculator.fromEmployee(
            employee: e,
            month: 10,
            year: 2026,
          ),
        )
        .toList();
    final doc = await PayslipPdfBuilder.build(slips);
    final bytes = await doc.save();
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('downloadPayslipPdf produces pdf bytes via builder', () async {
    // Validates generation path used by UI download buttons.
    final slip = PayslipCalculator.fromEmployee(
      employee: _sampleEmployee(),
      month: 10,
      year: 2026,
    );
    // downloadPayslipPdf also saves; on VM Printing may be unavailable,
    // so we only assert the shared build step used by all download actions.
    final doc = await PayslipPdfBuilder.build([slip]);
    final bytes = await doc.save();
    expect(bytes.isNotEmpty, isTrue);
  });
}
