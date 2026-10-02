import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_sticky_actions.dart';
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
                child: _PayrollPeriodPicker(state: state, isDesktop: isDesktop),
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
              _PayrollStickyActions(state: state),
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

class _PayrollPeriodPicker extends StatelessWidget {
  const _PayrollPeriodPicker({
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

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
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
      ),
    );
  }
}

class _PayrollStickyActions extends StatelessWidget {
  const _PayrollStickyActions({required this.state});

  final PayrollState state;

  @override
  Widget build(BuildContext context) {
    final generating = state.status == PayrollStatus.generating;
    final hasSelection = state.selectedIds.isNotEmpty;

    final downloadSelected = AppButton(
      label: state.selectedIds.length <= 1
          ? 'Download slip'
          : 'Download ${state.selectedIds.length} slips',
      isLoading: generating,
      enabled: !generating && hasSelection,
      onPressed: () =>
          context.read<PayrollBloc>().add(const PayrollDownloadSelected()),
    );

    if (hasSelection) {
      return AppStickyActions(children: [downloadSelected]);
    }

    return AppStickyActions(
      children: [
        OutlinedButton(
          onPressed: generating || state.employees.isEmpty
              ? null
              : () =>
                  context.read<PayrollBloc>().add(const PayrollDownloadAll()),
          child: const Text('Download all'),
        ),
        downloadSelected,
      ],
    );
  }
}

class _EmployeePicker extends StatefulWidget {
  const _EmployeePicker({
    required this.state,
    required this.isDesktop,
  });

  final PayrollState state;
  final bool isDesktop;

  @override
  State<_EmployeePicker> createState() => _EmployeePickerState();
}

class _EmployeePickerState extends State<_EmployeePicker> {
  String _query = '';

  List<Employee> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.state.employees;
    return widget.state.employees.where((e) {
      return e.employeeName.toLowerCase().contains(q) ||
          e.employeeId.toLowerCase().contains(q) ||
          e.designation.toLowerCase().contains(q) ||
          e.client.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final state = widget.state;
    final isDesktop = widget.isDesktop;
    final employees = _filtered;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 16,
            12,
            isDesktop ? 32 : 16,
            8,
          ),
          child: AppListSearchField(
            hintText: 'Search employees…',
            enabled: state.status != PayrollStatus.generating,
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 16,
            0,
            isDesktop ? 32 : 16,
            8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Match _EmployeeRow card left padding so checkboxes share one vertical axis.
              const SizedBox(width: 12),
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
          child: employees.isEmpty
              ? Center(
                  child: Text(
                    'No matching employees.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 32 : 16,
                    0,
                    isDesktop ? 32 : 16,
                    24,
                  ),
                  itemCount: employees.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final employee = employees[index];
                    return _EmployeeRow(
                      employee: employee,
                      selected:
                          state.selectedIds.contains(employee.employeeId),
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

    return AppListCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
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
          const SizedBox(width: 8),
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
                padding: const EdgeInsets.symmetric(vertical: 4),
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
                          const SizedBox(height: 4),
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
    );
  }
}
