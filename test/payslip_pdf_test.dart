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
    tdsAmount: 19549,
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

  test('Sachin July-2026 slip matches CTC → gross payroll formula', () {
    final slip = PayslipCalculator.fromEmployee(
      employee: _sampleEmployee(),
      month: 7,
      year: 2026,
      lopDays: 0,
    );

    expect(slip.payableDays, 31);
    expect(slip.lopDays, 0);
    expect(slip.grossEarnings, 167901);
    expect(slip.earnings[0].description, 'Basic');
    expect(slip.earnings[0].amount, 111934);
    expect(slip.earnings[1].description, 'HRA');
    expect(slip.earnings[1].amount, 55967);
    expect(slip.earnings[2].amount, 0);

    final byName = {
      for (final line in slip.deductions) line.description: line.amount,
    };
    expect(byName['Provident Fund'], 13432);
    expect(byName['Professional Tax'], 200);
    expect(byName['Medical Insurance'], 650);
    expect(byName['Income Tax (TDS)'], 19549);
    expect(byName['Retirals'], 2000);
    expect(slip.totalDeductions, 35831);
    expect(slip.netPay, 132070);
  });

  test('Akshat full-month slip matches PF structure (net 36528)', () {
    final employee = Employee(
      employeeId: '2126',
      employeeName: 'Akshat Srivastava',
      dateOfJoining: DateTime(2025, 11, 13),
      designation: 'QA Analyst',
      department: 'Digital Applications',
      annualCtc: 578712,
      monthlyCtc: 48226,
      pfApplicable: true,
      ptApplicable: true,
      medicalInsurance: 650,
      retentionAmount: 2000,
      specialAllowance: 0,
      tdsAmount: 0,
      bankAccount: '50100637300562',
      ifsc: 'HDFC0000722',
      pan: 'KHDPS5180M',
      uan: '',
      isActive: true,
      location: 'Mumbai HO',
      grade: 'L11',
      clientId: 'mahindra-finance-ketan-jain',
      client: 'Mahindra Finance',
    );

    final slip = PayslipCalculator.fromEmployee(
      employee: employee,
      month: 9,
      year: 2026,
      lopDays: 0,
    );

    expect(slip.grossEarnings, 42802);
    expect(slip.earnings[0].amount, 28535);
    expect(slip.earnings[1].amount, 14268);
    expect(slip.earnings[2].amount, 0);

    final byName = {
      for (final line in slip.deductions) line.description: line.amount,
    };
    expect(byName['Provident Fund'], 3424);
    expect(byName['Professional Tax'], 200);
    expect(byName['Medical Insurance'], 650);
    expect(byName['Income Tax (TDS)'], 0);
    expect(byName['Retirals'], 2000);
    expect(slip.totalDeductions, 6274);
    expect(slip.netPay, 36528);
  });

  test('Praful full-month slip matches PF structure (net 45138)', () {
    final employee = Employee(
      employeeId: '2125',
      employeeName: 'Praful Dohatare',
      dateOfJoining: DateTime(2025, 10, 22),
      designation: 'Software Development Engineer',
      department: 'Digital Applications',
      annualCtc: 700008,
      monthlyCtc: 58334,
      pfApplicable: true,
      ptApplicable: true,
      medicalInsurance: 650,
      retentionAmount: 2000,
      specialAllowance: 0,
      tdsAmount: 0,
      bankAccount: '',
      ifsc: '',
      pan: 'ELEPD9739J',
      uan: '102052995260',
      isActive: true,
      location: 'Mumbai HO',
      grade: 'L11',
      clientId: 'mahindra-finance-ketan-jain',
      client: 'Mahindra Finance',
    );

    final slip = PayslipCalculator.fromEmployee(
      employee: employee,
      month: 9,
      year: 2026,
      lopDays: 0,
    );

    expect(slip.grossEarnings, 52161);
    expect(slip.earnings[0].amount, 34774);
    expect(slip.earnings[1].amount, 17387);
    expect(slip.earnings[2].amount, 0);

    final byName = {
      for (final line in slip.deductions) line.description: line.amount,
    };
    expect(byName['Provident Fund'], 4173);
    expect(byName['Professional Tax'], 200);
    expect(byName['Medical Insurance'], 650);
    expect(byName['Retirals'], 2000);
    expect(slip.totalDeductions, 7023);
    expect(slip.netPay, 45138);
  });

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
        annualCtc: 524559.60,
        monthlyCtc: 43713.30,
        pfApplicable: false,
        ptApplicable: true,
        medicalInsurance: 650,
        retentionAmount: 3167.65,
        specialAllowance: 950,
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
    final slip = PayslipCalculator.fromEmployee(
      employee: _sampleEmployee(),
      month: 10,
      year: 2026,
    );
    final doc = await PayslipPdfBuilder.build([slip]);
    final bytes = await doc.save();
    expect(bytes.isNotEmpty, isTrue);
  });
}
