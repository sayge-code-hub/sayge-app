import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/employee.dart';
import '../widgets/employee_form_layout.dart';

class EmployeeDetailPage extends StatelessWidget {
  const EmployeeDetailPage({
    super.key,
    required this.employee,
    this.embedded = false,
    this.onBack,
    this.onEdit,
  });

  final Employee employee;
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final dateFormat = AppDates.compact;
    final horizontal = isDesktop ? 32.0 : 16.0;

    final identity = EmployeeDetailSection(
      title: 'Identity',
      isDesktop: isDesktop,
      children: [
        EmployeeDetailField(
          label: 'Employee ID',
          value: employee.employeeId,
        ),
        EmployeeDetailField(
          label: 'Employee name',
          value: employee.employeeName,
        ),
        EmployeeDetailField(
          label: 'Active',
          value: employee.isActive ? 'Yes' : 'No',
        ),
        EmployeeDetailField(
          label: 'Location',
          value: employee.location,
        ),
      ],
    );

    final role = EmployeeDetailSection(
      title: 'Role & allocation',
      isDesktop: isDesktop,
      children: [
        EmployeeDetailField(
          label: 'Client',
          value: employee.client,
        ),
        EmployeeDetailField(
          label: 'Designation',
          value: employee.designation,
        ),
        EmployeeDetailField(
          label: 'Department',
          value: employee.department,
        ),
        EmployeeDetailField(
          label: 'Grade',
          value: employee.grade,
        ),
        EmployeeDetailField(
          label: 'Date of joining',
          value: dateFormat.format(employee.dateOfJoining),
        ),
      ],
    );

    final compensation = EmployeeDetailSection(
      title: 'Compensation',
      isDesktop: isDesktop,
      trailing: TextButton(
        onPressed: () => context.go(
          AppRoutes.employeeCompensation(employee.employeeId),
        ),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.success,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Breakdown',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.success,
              ),
        ),
      ),
      children: [
        EmployeeDetailField(
          label: 'Annual CTC',
          value: MoneyFormat.format(employee.annualCtc),
        ),
        EmployeeDetailField(
          label: 'Monthly CTC',
          value: MoneyFormat.format(employee.monthlyCtc),
        ),
        EmployeeDetailField(
          label: 'Medical insurance',
          value: MoneyFormat.format(employee.medicalInsurance),
        ),
        EmployeeDetailField(
          label: 'Retention amount',
          value: MoneyFormat.format(employee.retentionAmount),
        ),
      ],
    );

    final compliance = EmployeeDetailSection(
      title: 'Compliance & bank',
      isDesktop: isDesktop,
      children: [
        EmployeeDetailField(
          label: 'PF applicable',
          value: employee.pfApplicable ? 'Yes' : 'No',
        ),
        EmployeeDetailField(
          label: 'PT applicable',
          value: employee.ptApplicable ? 'Yes' : 'No',
        ),
        EmployeeDetailField(
          label: 'PAN',
          value: employee.pan,
        ),
        EmployeeDetailField(
          label: 'UAN',
          value: employee.uan,
        ),
        EmployeeDetailField(
          label: 'Bank A/C',
          value: employee.bankAccount,
        ),
        EmployeeDetailField(
          label: 'IFSC',
          value: employee.ifsc,
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
                left: identity,
                right: role,
              ),
              const SizedBox(height: 12),
              EmployeeDetailSectionRow(
                isDesktop: isDesktop,
                left: compensation,
                right: compliance,
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
              label: 'Edit',
              expand: false,
              onPressed: () {
                if (embedded) {
                  onEdit?.call();
                }
              },
            ),
          ],
        ),
      ],
    );

    if (embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(toolbarHeight: 72),
      body: body,
    );
  }
}
