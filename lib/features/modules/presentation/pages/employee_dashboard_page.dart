import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../hrms/domain/entities/employee.dart';
import '../../../hrms/presentation/bloc/employees/employees_bloc.dart';
import '../../../payroll/domain/services/payslip_period.dart';
import '../../../payroll/presentation/bloc/payroll_bloc.dart';

/// Employee home. Dashboard = profile only; Salary Slips = download only.
class EmployeeDashboardPage extends StatelessWidget {
  const EmployeeDashboardPage({
    super.key,
    this.showSalarySlips = false,
  });

  final bool showSalarySlips;

  @override
  Widget build(BuildContext context) {
    if (!showSalarySlips) {
      return const _DashboardBody(isSlips: false);
    }
    return BlocProvider(
      create: (_) => sl<PayrollBloc>()..add(const PayrollStarted()),
      child: const _DashboardBody(isSlips: true),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.isSlips});

  final bool isSlips;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmployeesBloc, EmployeesState>(
      builder: (context, empState) {
        if (empState.status == EmployeesStatus.loading ||
            empState.status == EmployeesStatus.initial) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        final user = sl<AuthSession>().user;
        final id = user?.employeeId?.trim();
        Employee? me;
        if (id != null && id.isNotEmpty) {
          for (final e in empState.employees) {
            if (e.employeeId == id) {
              me = e;
              break;
            }
          }
        }

        if (isSlips) {
          return _SalarySlipsView(employee: me);
        }
        return _ProfileView(employee: me, user: user);
      },
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({this.employee, this.user});

  final Employee? employee;
  final User? user;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;
    final linked = employee != null;
    final dateFormat = AppDates.compact;

    final displayName = linked
        ? employee!.employeeName
        : (user?.name?.trim().isNotEmpty == true
            ? user!.name!.trim()
            : (user?.email ?? 'Profile'));

    final fields = linked
        ? <({String label, String value})>[
            (label: 'Employee ID', value: employee!.employeeId),
            (label: 'Client', value: employee!.client),
            (label: 'Grade', value: employee!.grade),
            (label: 'Email', value: user?.email ?? '—'),
            (label: 'Department', value: employee!.department),
            (
              label: 'Joining date',
              value: dateFormat.format(employee!.dateOfJoining),
            ),
            (
              label: 'Birth date',
              value: employee!.dateOfBirth == null
                  ? '—'
                  : dateFormat.format(employee!.dateOfBirth!),
            ),
          ]
        : <({String label, String value})>[
            (label: 'Email', value: user?.email ?? '—'),
            (label: 'Role', value: user?.roleLabel ?? '—'),
          ];

    return Align(
      alignment: Alignment.topCenter,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          isDesktop ? 16 : 12,
          horizontal,
          40,
        ),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 720 : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileHero(
                  name: displayName,
                  employeeId: linked ? employee!.employeeId : null,
                  isDesktop: isDesktop,
                ),
                const SizedBox(height: 16),
                _DetailsGrid(fields: fields, isDesktop: isDesktop),
                if (!linked) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Your profile is not linked to an employee record yet. '
                    'Ask an owner to link your account, then you can view your '
                    'details, compensation, and salary slips here.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textLight,
                          height: 1.45,
                          fontSize: 13,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SalarySlipsView extends StatelessWidget {
  const _SalarySlipsView({this.employee});

  final Employee? employee;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textLight,
          fontSize: 13,
          height: 1.45,
        );

    if (employee == null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 32),
        child: Text(
          'Your profile is not linked to an employee record yet.',
          style: textStyle,
        ),
      );
    }

    final options = PayslipPeriod.optionsForEmployee(employee!.dateOfJoining);
    if (options.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 32),
        child: Text(
          'No salary slips are available yet. Slips unlock after the month ends.',
            style: textStyle,
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          isDesktop ? 24 : 16,
          horizontal,
          32,
        ),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 420 : double.infinity,
            ),
            child: _SalarySlipDownload(monthOptions: options),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.isDesktop,
    this.employeeId,
  });

  final String name;
  final String? employeeId;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final id = employeeId?.trim();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 22 : 16,
        isDesktop ? 20 : 16,
        isDesktop ? 22 : 16,
        isDesktop ? 20 : 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: isDesktop ? 56 : 48,
            height: isDesktop ? 56 : 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              _initials(name),
              style: textTheme.titleMedium?.copyWith(
                fontSize: isDesktop ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontSize: isDesktop ? 20 : 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (id != null && id.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'ID $id',
                      style: textTheme.labelLarge?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLight,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({
    required this.fields,
    required this.isDesktop,
  });

  final List<({String label, String value})> fields;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final columns = isDesktop && fields.length > 1 ? 2 : 1;

    Widget cell(({String label, String value}) field) {
      final value = field.value.trim().isEmpty ? '—' : field.value.trim();
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              field.label,
              style: textTheme.labelLarge?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: textTheme.bodyLarge?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.text,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: columns == 1
          ? Column(
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.border),
                  cell(fields[i]),
                ],
              ],
            )
          : Column(
              children: [
                for (var i = 0; i < fields.length; i += 2) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.border),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cell(fields[i])),
                        Container(width: 1, color: AppColors.border),
                        Expanded(
                          child: i + 1 < fields.length
                              ? cell(fields[i + 1])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _SalarySlipDownload extends StatelessWidget {
  const _SalarySlipDownload({required this.monthOptions});

  final List<DateTime> monthOptions;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);

    return BlocConsumer<PayrollBloc, PayrollState>(
      listenWhen: (prev, next) =>
          prev.errorMessage != next.errorMessage && next.errorMessage != null,
      listener: (context, state) {
        final message = state.errorMessage;
        if (message != null) {
          showAppMessageDialog(context, message: message);
        }
      },
      builder: (context, state) {
        final generating = state.status == PayrollStatus.generating;
        final options = monthOptions;
        final selected = DateTime(state.year, state.month, 1);
        final value = options.any(
          (d) => d.year == selected.year && d.month == selected.month,
        )
            ? selected
            : options.last;

        if (value.year != state.year || value.month != state.month) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            context.read<PayrollBloc>().add(
                  PayrollMonthChanged(month: value.month, year: value.year),
                );
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDropdown<DateTime>(
              label: 'Month',
              value: value,
              items: options,
              itemLabel: (d) => DateFormat('MMMM yyyy').format(d),
              enabled: !generating,
              onChanged: (picked) {
                if (picked == null) return;
                context.read<PayrollBloc>().add(
                      PayrollMonthChanged(
                        month: picked.month,
                        year: picked.year,
                      ),
                    );
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: isDesktop ? Alignment.centerRight : Alignment.center,
              child: SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: generating || state.employees.isEmpty
                      ? null
                      : () => context
                          .read<PayrollBloc>()
                          .add(const PayrollDownloadSelected()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.text,
                    foregroundColor: AppColors.background,
                    disabledBackgroundColor: AppColors.textLight,
                    disabledForegroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: generating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.background,
                            ),
                          ),
                        )
                      : const Text(
                          'Download slip',
                          style: TextStyle(fontSize: 13),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

String _initials(String source) {
  final parts = source.trim().split(RegExp(r'\s+|@'));
  if (parts.isEmpty || parts.first.isEmpty) return 'S';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
