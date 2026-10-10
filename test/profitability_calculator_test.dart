import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/features/expenses/domain/entities/expense.dart';
import 'package:sayge_app/features/hrms/domain/entities/employee.dart';
import 'package:sayge_app/features/invoices/domain/entities/invoice.dart';
import 'package:sayge_app/features/profitability/domain/services/profitability_calculator.dart';

Employee _employee({
  required String id,
  required String client,
  required String clientId,
  double monthlyRate = 100000,
  double annualCtc = 600000,
  DateTime? joining,
  DateTime? exit,
  bool isActive = true,
  bool isDraft = false,
}) {
  return Employee(
    employeeId: id,
    employeeName: 'Emp $id',
    dateOfJoining: joining ?? DateTime(2025, 1, 1),
    designation: 'Engineer',
    department: 'Eng',
    annualCtc: annualCtc,
    monthlyCtc: annualCtc / 12,
    monthlyRate: monthlyRate,
    pfApplicable: true,
    ptApplicable: true,
    medicalInsurance: 0,
    retentionAmount: 0,
    bankAccount: '',
    ifsc: '',
    pan: '',
    uan: '',
    isActive: isActive,
    isDraft: isDraft,
    dateOfExit: exit,
    location: 'Pune',
    grade: 'A',
    clientId: clientId,
    client: client,
  );
}

Invoice _invoice({
  required String company,
  required DateTime date,
  required double taxable,
}) {
  return Invoice(
    id: 'inv-$taxable-${date.month}',
    invoiceNo: 'INV-$taxable',
    invoiceDate: date,
    poNumber: '',
    placeOfSupply: '',
    buyerName: '',
    buyerCompany: company,
    buyerAddress: '',
    buyerGstin: '',
    buyerContact: '',
    intraState: true,
    lineItems: const [],
    taxableAmount: taxable,
    cgstAmount: 0,
    sgstAmount: 0,
    igstAmount: 0,
    totalAmount: taxable,
    amountInWords: '',
  );
}

void main() {
  group('ProfitabilityCalculator invoice billing', () {
    test('client monthly billing uses invoices, not contracted rates', () {
      final employees = [
        _employee(
          id: 'E1',
          client: 'Mahindra Finance',
          clientId: 'c1',
          monthlyRate: 245833,
        ),
      ];
      final rows = ProfitabilityCalculator.forEmployees(employees);
      final clients = ProfitabilityCalculator.rollUpByClient(
        rows,
        invoices: [
          _invoice(
            company: 'Mahindra Finance',
            date: DateTime(2026, 10, 5),
            taxable: 200000,
          ),
        ],
        now: DateTime(2026, 10, 9),
      );

      expect(clients, hasLength(1));
      expect(clients.first.billingMonthly, 200000);
      // Package = 600000/12 = 50000
      expect(clients.first.packageMonthly, 50000);
      expect(clients.first.grossProfit, 150000);
    });

    test('month-wise past months ignore contracted rate when no invoice', () {
      final rows = ProfitabilityCalculator.forEmployees([
        _employee(
          id: 'E1',
          client: 'Acme',
          clientId: 'c1',
          monthlyRate: 100000,
        ),
      ]);
      final client = ProfitabilityCalculator.rollUpByClient(
        rows,
        invoices: [
          _invoice(
            company: 'Acme',
            date: DateTime(2026, 9, 1),
            taxable: 90000,
          ),
        ],
        now: DateTime(2026, 10, 9),
      ).first;

      final months = ProfitabilityCalculator.monthWiseForClient(
        client,
        invoices: [
          _invoice(
            company: 'Acme',
            date: DateTime(2026, 9, 1),
            taxable: 90000,
          ),
        ],
        now: DateTime(2026, 10, 9),
      );

      final sept = months.firstWhere((m) => m.month == 9 && m.year == 2026);
      final oct = months.firstWhere((m) => m.month == 10 && m.year == 2026);
      expect(sept.billing, 90000);
      expect(oct.billing, 0);
    });

    test('FY projection forecasts future months from contracted rates', () {
      final rows = ProfitabilityCalculator.forEmployees([
        _employee(
          id: 'E1',
          client: 'Acme',
          clientId: 'c1',
          monthlyRate: 100000,
        ),
      ]);
      final client = ProfitabilityCalculator.rollUpByClient(
        rows,
        now: DateTime(2026, 10, 9),
      ).first;

      final months = ProfitabilityCalculator.financialYearProjection(
        client,
        fyStartYear: 2026,
        now: DateTime(2026, 10, 9),
      );

      final oct = months.firstWhere((m) => m.month == 10);
      final nov = months.firstWhere((m) => m.month == 11);
      expect(oct.billing, 0); // current month, no invoice yet
      expect(nov.billing, 100000); // future forecast
    });

    test('includes invoice-only clients without employees', () {
      final clients = ProfitabilityCalculator.rollUpByClient(
        const [],
        invoices: [
          _invoice(
            company: 'Solo Client',
            date: DateTime(2026, 10, 1),
            taxable: 50000,
          ),
        ],
        now: DateTime(2026, 10, 9),
      );
      expect(clients.single.clientName, 'Solo Client');
      expect(clients.single.billingMonthly, 50000);
    });

    test('export CSV includes invoiced FY totals', () {
      final rows = ProfitabilityCalculator.forEmployees([
        _employee(
          id: 'E1',
          client: 'Acme',
          clientId: 'c1',
          monthlyRate: 100000,
          annualCtc: 600000,
        ),
      ]);
      final clients = ProfitabilityCalculator.rollUpByClient(
        rows,
        invoices: [
          _invoice(
            company: 'Acme',
            date: DateTime(2026, 5, 1),
            taxable: 120000,
          ),
        ],
        now: DateTime(2026, 10, 9),
      );

      final csv = ProfitabilityCalculator.exportCsv(
        clients,
        fyStartYear: 2026,
        invoices: [
          _invoice(
            company: 'Acme',
            date: DateTime(2026, 5, 1),
            taxable: 120000,
          ),
        ],
        now: DateTime(2026, 10, 9),
      );

      expect(csv, contains('Client,Employees,Invoiced,Package,Expenses,Profit'));
      expect(csv, contains('Acme'));
      expect(csv, contains('120000.00'));
    });

    test('FY filter on monthWise restricts months', () {
      final rows = ProfitabilityCalculator.forEmployees([
        _employee(
          id: 'E1',
          client: 'Acme',
          clientId: 'c1',
          joining: DateTime(2024, 1, 1),
        ),
      ]);
      final client = ProfitabilityCalculator.rollUpByClient(
        rows,
        now: DateTime(2026, 10, 9),
      ).first;

      final fy26 = ProfitabilityCalculator.monthWiseForClient(
        client,
        fyStartYear: 2026,
        now: DateTime(2026, 10, 9),
      );
      expect(fy26.every((m) {
        if (m.month >= 4) return m.year == 2026;
        return m.year == 2027;
      }), isTrue);
    });

    test('draft employees are excluded', () {
      final rows = ProfitabilityCalculator.forEmployees([
        _employee(
          id: 'E1',
          client: 'Acme',
          clientId: 'c1',
          isDraft: true,
        ),
      ]);
      expect(rows, isEmpty);
    });

    test('approved expenses still reduce profit', () {
      final rows = ProfitabilityCalculator.forEmployees([
        _employee(id: 'E1', client: 'Acme', clientId: 'c1'),
      ]);
      final clients = ProfitabilityCalculator.rollUpByClient(
        rows,
        invoices: [
          _invoice(
            company: 'Acme',
            date: DateTime(2026, 10, 1),
            taxable: 100000,
          ),
        ],
        expenses: [
          Expense(
            id: 'x1',
            madeFor: 'Tools',
            amount: 10000,
            paidFrom: 'Company',
            category: 'Software Tools',
            clientId: 'c1',
            clientName: 'Acme',
            approvalStatus: ExpenseApprovalStatus.approved,
            createdAt: DateTime(2026, 10, 2),
          ),
        ],
        now: DateTime(2026, 10, 9),
      );
      // 100000 - 50000 package - 10000 expense
      expect(clients.first.grossProfit, 40000);
    });
  });
}
