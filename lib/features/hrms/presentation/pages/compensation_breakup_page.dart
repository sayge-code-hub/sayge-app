import 'package:flutter/material.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../payroll/domain/services/payslip_calculator.dart';
import '../../domain/entities/employee.dart';
import '../widgets/employee_form_layout.dart';

/// Monthly compensation breakup derived from CTC + payroll config.
class CompensationBreakupPage extends StatelessWidget {
  const CompensationBreakupPage({
    super.key,
    required this.employee,
    this.embedded = false,
    this.onBack,
  });

  final Employee employee;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final now = DateTime.now();
    final slip = PayslipCalculator.fromEmployee(
      employee: employee,
      month: now.month,
      year: now.year,
    );
    final horizontal = isDesktop ? 32.0 : 16.0;

    final overview = EmployeeDetailSection(
      title: 'Overview',
      isDesktop: isDesktop,
      children: [
        EmployeeDetailField(
          label: 'Employee',
          value: employee.employeeName,
        ),
        EmployeeDetailField(
          label: 'Employee ID',
          value: employee.employeeId,
        ),
        EmployeeDetailField(
          label: 'Annual CTC',
          value: MoneyFormat.format(employee.annualCtc),
        ),
        EmployeeDetailField(
          label: 'Monthly CTC',
          value: MoneyFormat.format(employee.monthlyCtc),
        ),
        EmployeeDetailField(
          label: 'Gross earnings',
          value: MoneyFormat.format(slip.grossEarnings),
        ),
      ],
    );

    final earnings = EmployeeDetailSection(
      title: 'Earnings',
      isDesktop: isDesktop,
      children: [
        for (final line in slip.earnings)
          EmployeeDetailField(
            label: line.description,
            value: MoneyFormat.format(line.amount),
          ),
        EmployeeDetailField(
          label: 'Gross earnings',
          value: MoneyFormat.format(slip.grossEarnings),
        ),
      ],
    );

    final deductions = EmployeeDetailSection(
      title: 'Deductions',
      isDesktop: isDesktop,
      children: [
        for (final line in slip.deductions)
          EmployeeDetailField(
            label: line.description,
            value: MoneyFormat.format(line.amount),
          ),
        EmployeeDetailField(
          label: 'Total deductions',
          value: MoneyFormat.format(slip.totalDeductions),
        ),
      ],
    );

    final netPay = EmployeeDetailSection(
      title: 'Net pay',
      isDesktop: isDesktop,
      children: [
        EmployeeDetailField(
          label: 'Net in hand',
          value: MoneyFormat.format(slip.netPay),
        ),
        EmployeeDetailField(
          label: 'In words',
          value: slip.netPayInWords,
        ),
      ],
    );

    final body = Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              embedded ? (isDesktop ? 12 : 8) : 16,
              horizontal,
              24,
            ),
            children: [
              EmployeeDetailSectionRow(
                isDesktop: isDesktop,
                left: overview,
                right: earnings,
              ),
              const SizedBox(height: 12),
              EmployeeDetailSectionRow(
                isDesktop: isDesktop,
                left: deductions,
                right: netPay,
              ),
            ],
          ),
        ),
        EmployeeStickyActions(
          children: [
            OutlinedButton(
              onPressed: () {
                if (embedded) {
                  onBack?.call();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
              child: const Text('Back'),
            ),
            AppButton(
              label: 'Done',
              onPressed: () {
                if (embedded) {
                  onBack?.call();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
            ),
          ],
        ),
      ],
    );

    if (embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(toolbarHeight: 72),
      body: body,
    );
  }
}
