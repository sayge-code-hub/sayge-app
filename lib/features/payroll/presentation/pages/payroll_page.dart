import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../../hrms/domain/entities/employee.dart';
import '../bloc/payroll_bloc.dart';
import '../widgets/payslip_preview_dialog.dart';

class PayrollPage extends StatelessWidget {
  const PayrollPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PayrollBloc>()..add(const PayrollStarted()),
      child: const _PayrollBody(),
    );
  }
}

class _PayrollBody extends StatelessWidget {
  const _PayrollBody();

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);

    return BlocConsumer<PayrollBloc, PayrollState>(
      listenWhen: (prev, next) =>
          prev.errorMessage != next.errorMessage && next.errorMessage != null,
      listener: (context, state) {
        final message = state.errorMessage;
        if (message != null) {
          showAppMessageDialog(
            context,
            title: 'Payroll',
            message: message,
          );
        }
      },
      builder: (context, state) {
        if (state.status == PayrollStatus.initial ||
            state.status == PayrollStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        return Theme(
          data: Theme.of(context).copyWith(
            checkboxTheme: _payrollCheckboxTheme,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 16,
                  isDesktop ? 8 : 12,
                  isDesktop ? 32 : 16,
                  12,
                ),
                child: _PayrollToolbar(state: state, isDesktop: isDesktop),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: state.employees.isEmpty
                    ? Center(
                        child: Text(
                          'No active employees.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textLight,
                                  ),
                        ),
                      )
                    : _EmployeePicker(state: state, isDesktop: isDesktop),
              ),
            ],
          ),
        );
      },
    );
  }
}

final _payrollCheckboxTheme = CheckboxThemeData(
  side: const BorderSide(color: AppColors.border, width: 1.5),
  fillColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) {
      return AppColors.highlight;
    }
    return AppColors.background;
  }),
  checkColor: const WidgetStatePropertyAll(AppColors.background),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
);

class _PayrollToolbar extends StatelessWidget {
  const _PayrollToolbar({
    required this.state,
    required this.isDesktop,
  });

  final PayrollState state;
  final bool isDesktop;

  static List<DateTime> _monthOptions() {
    final options = <DateTime>[];
    for (var year = 2025; year <= 2030; year++) {
      for (var month = 1; month <= 12; month++) {
        options.add(DateTime(year, month, 1));
      }
    }
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final generating = state.status == PayrollStatus.generating;
    final options = _monthOptions();
    final selected = DateTime(state.year, state.month, 1);

    final period = SizedBox(
      width: isDesktop ? 220 : double.infinity,
      child: DropdownButtonFormField<DateTime>(
        // Controlled by PayrollBloc month/year.
        // ignore: deprecated_member_use
        value: options.any(
          (d) => d.year == selected.year && d.month == selected.month,
        )
            ? selected
            : options.last,
        decoration: const InputDecoration(
          prefixIcon: Icon(
            Icons.calendar_month_outlined,
            size: 20,
            color: AppColors.textLight,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: [
          for (final d in options)
            DropdownMenuItem(
              value: d,
              child: Text(DateFormat('MMMM yyyy').format(d)),
            ),
        ],
        onChanged: generating
            ? null
            : (value) {
                if (value == null) return;
                context.read<PayrollBloc>().add(
                      PayrollMonthChanged(
                        month: value.month,
                        year: value.year,
                      ),
                    );
              },
      ),
    );

    final hasSelection = state.selectedIds.isNotEmpty;

    final downloadSelected = AppButton(
      label: state.selectedIds.length <= 1
          ? 'Download slip'
          : 'Download ${state.selectedIds.length} slips',
      expand: !isDesktop,
      isLoading: generating,
      enabled: !generating && hasSelection,
      onPressed: () =>
          context.read<PayrollBloc>().add(const PayrollDownloadSelected()),
    );

    final downloadAll = OutlinedButton(
      onPressed: generating || state.employees.isEmpty
          ? null
          : () => context.read<PayrollBloc>().add(const PayrollDownloadAll()),
      child: const Text('Download all'),
    );

    if (isDesktop) {
      return Row(
        children: [
          period,
          const Spacer(),
          if (!hasSelection) ...[
            downloadAll,
            const SizedBox(width: 12),
          ],
          downloadSelected,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        period,
        const SizedBox(height: 12),
        Row(
          children: [
            if (!hasSelection) ...[
              Expanded(child: downloadAll),
              const SizedBox(width: 12),
            ],
            Expanded(child: downloadSelected),
          ],
        ),
      ],
    );
  }
}

class _EmployeePicker extends StatelessWidget {
  const _EmployeePicker({
    required this.state,
    required this.isDesktop,
  });

  final PayrollState state;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 16,
            12,
            isDesktop ? 32 : 16,
            8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Checkbox(
                  value: state.allSelected
                      ? true
                      : state.selectedIds.isEmpty
                          ? false
                          : null,
                  tristate: true,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (_) => context
                      .read<PayrollBloc>()
                      .add(const PayrollSelectAllToggled()),
                ),
              ),
              Text(
                'Employees',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.textLight,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Text(
                '${state.selectedIds.length} selected',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 32 : 16,
              0,
              isDesktop ? 32 : 16,
              24,
            ),
            itemCount: state.employees.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final employee = state.employees[index];
              return _EmployeeRow(
                employee: employee,
                selected: state.selectedIds.contains(employee.employeeId),
                enabled: state.status != PayrollStatus.generating,
                month: state.month,
                year: state.year,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({
    required this.employee,
    required this.selected,
    required this.enabled,
    required this.month,
    required this.year,
  });

  final Employee employee;
  final bool selected;
  final bool enabled;
  final int month;
  final int year;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              height: 24,
              child: Checkbox(
                value: selected,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: enabled
                    ? (_) => context.read<PayrollBloc>().add(
                          PayrollEmployeeToggled(employee.employeeId),
                        )
                    : null,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: enabled
                    ? () => showPayslipPreview(
                          context: context,
                          employee: employee,
                          month: month,
                          year: year,
                        )
                    : null,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employee.employeeName,
                              style: textTheme.titleMedium?.copyWith(
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${employee.employeeId} · ${employee.designation}',
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          employee.client,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
