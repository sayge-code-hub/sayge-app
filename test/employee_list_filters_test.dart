import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/features/hrms/domain/employee_list_filters.dart';
import 'package:sayge_app/features/hrms/domain/entities/employee.dart';

Employee _employee({
  String id = 'E1',
  String name = 'Ada',
  String client = 'Acme',
  bool isActive = true,
  bool isDraft = false,
  DateTime? dateOfExit,
  DateTime? dateOfJoining,
}) {
  final doj = dateOfJoining ?? DateTime(2024, 1, 1);
  return Employee(
    employeeId: id,
    employeeName: name,
    dateOfJoining: doj,
    designation: 'Engineer',
    department: 'Eng',
    annualCtc: 1200000,
    monthlyCtc: 100000,
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
    dateOfExit: dateOfExit,
    location: 'BLR',
    grade: 'L1',
    clientId: 'c1',
    client: client,
  );
}

void main() {
  group('EmployeeListFilters.matchesStatus', () {
    test('active requires !draft && isActive', () {
      expect(
        EmployeeListFilters.matchesStatus(
          _employee(),
          EmployeeListStatusFilter.active,
        ),
        isTrue,
      );
      expect(
        EmployeeListFilters.matchesStatus(
          _employee(isDraft: true),
          EmployeeListStatusFilter.active,
        ),
        isFalse,
      );
      expect(
        EmployeeListFilters.matchesStatus(
          _employee(isActive: false),
          EmployeeListStatusFilter.active,
        ),
        isFalse,
      );
    });

    test('draft matches isDraft', () {
      expect(
        EmployeeListFilters.matchesStatus(
          _employee(isDraft: true, isActive: false),
          EmployeeListStatusFilter.draft,
        ),
        isTrue,
      );
    });

    test('exited matches !isActive or dateOfExit', () {
      expect(
        EmployeeListFilters.matchesStatus(
          _employee(isActive: false),
          EmployeeListStatusFilter.exited,
        ),
        isTrue,
      );
      expect(
        EmployeeListFilters.matchesStatus(
          _employee(dateOfExit: DateTime(2025, 6, 1)),
          EmployeeListStatusFilter.exited,
        ),
        isTrue,
      );
      expect(
        EmployeeListFilters.matchesStatus(
          _employee(),
          EmployeeListStatusFilter.exited,
        ),
        isFalse,
      );
    });
  });

  group('EmployeeListFilters.statusLabel', () {
    test('labels exited not inactive', () {
      expect(
        EmployeeListFilters.statusLabel(_employee(isActive: false)),
        'Exited',
      );
      expect(EmployeeListFilters.statusLabel(_employee(isDraft: true)), 'Draft');
      expect(EmployeeListFilters.statusLabel(_employee()), 'Active');
    });
  });

  group('EmployeeListFilters.apply', () {
    test('combines status, client, and search', () {
      final employees = [
        _employee(id: 'A', name: 'Ada Lovelace', client: 'Acme'),
        _employee(id: 'B', name: 'Bob', client: 'Beta', isActive: false),
        _employee(id: 'C', name: 'Ada Draft', client: 'Acme', isDraft: true),
      ];

      final filtered = EmployeeListFilters.apply(
        employees: employees,
        status: EmployeeListStatusFilter.active,
        client: 'Acme',
        query: 'ada',
      );

      expect(filtered.map((e) => e.employeeId), ['A']);
    });
  });

  group('rehire mapping shape', () {
    test('copyWith clearDateOfExit restores active employment fields', () {
      final exited = _employee(
        isActive: false,
        dateOfExit: DateTime(2025, 3, 1),
      );
      final rejoined = DateTime(2026, 1, 15);
      final rehired = exited.copyWith(
        isActive: true,
        clearDateOfExit: true,
        dateOfJoining: rejoined,
      );

      expect(rehired.isActive, isTrue);
      expect(rehired.dateOfExit, isNull);
      expect(rehired.dateOfJoining, rejoined);
    });
  });
}
