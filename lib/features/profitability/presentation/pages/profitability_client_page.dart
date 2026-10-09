import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../injection_container.dart';
import '../../../hrms/presentation/widgets/employee_avatar.dart';
import '../../../settings/presentation/widgets/client_name_label.dart';
import '../../domain/entities/profitability.dart';
import '../../domain/services/profitability_calculator.dart';
import '../bloc/profitability_bloc.dart';
import '../widgets/profitability_charts.dart';

class ProfitabilityClientPage extends StatelessWidget {
  const ProfitabilityClientPage({
    super.key,
    required this.clientId,
  });

  final String clientId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<ProfitabilityBloc>()..add(const ProfitabilityStarted()),
      child: _ProfitabilityClientBody(clientId: clientId),
    );
  }
}

class _ProfitabilityClientBody extends StatelessWidget {
  const _ProfitabilityClientBody({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;
    final textTheme = Theme.of(context).textTheme;
    final monthFormat = DateFormat('MMM yyyy');

    return BlocBuilder<ProfitabilityBloc, ProfitabilityState>(
      builder: (context, state) {
        if (state.status == ProfitabilityStatus.initial ||
            state.status == ProfitabilityStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        final client = state.clientById(clientId);
        if (client == null) {
          return Center(
            child: Text(
              'Client not found.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textLight),
            ),
          );
        }

        final months = ProfitabilityCalculator.monthWiseForClient(
          client,
          expenses: state.expenses,
        );
        final profitTillDate =
            months.fold<double>(0, (s, m) => s + m.profit).roundToDouble();
        final billingTillDate =
            months.fold<double>(0, (s, m) => s + m.billing).roundToDouble();
        final expensesTillDate =
            months.fold<double>(0, (s, m) => s + m.expenses).roundToDouble();
        final marginTillDate = billingTillDate > 0
            ? ((profitTillDate / billingTillDate) * 1000).roundToDouble() / 10
            : client.marginPercent;

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
                children: [
                  AppListCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: ClientNameLabel(
                      name: client.clientName,
                      style: textTheme.titleMedium?.copyWith(fontSize: 15),
                      logoRadius: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MetricChunks(
                    profitTillDate: profitTillDate,
                    marginTillDate: marginTillDate,
                    expensesTillDate: expensesTillDate,
                    monthlyBilling: client.billingMonthly,
                    monthlyExpenses: client.expensesMonthly,
                    monthlyProfit: client.grossProfit,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Employees',
                    style: textTheme.titleMedium?.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  AppListCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < client.employees.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: AppColors.border),
                          _EmployeeRow(employee: client.employees[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Months',
                    style: textTheme.titleMedium?.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  if (months.isEmpty)
                    AppListCard(
                      child: Text(
                        'No months available yet.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                    )
                  else
                    AppListCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < months.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                color: AppColors.border,
                              ),
                            _MonthRow(
                              label: monthFormat.format(
                                DateTime(months[i].year, months[i].month),
                              ),
                              row: months[i],
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (!isDesktop)
              Material(
                color: AppColors.background,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: AppButton(
                      label: 'Projections',
                      onPressed: () => context.go(
                        AppRoutes.profitabilityProjections(clientId),
                      ),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 160,
                    child: AppButton(
                      label: 'Projections',
                      expand: false,
                      onPressed: () => context.go(
                        AppRoutes.profitabilityProjections(clientId),
                      ),
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

class _MetricChunks extends StatelessWidget {
  const _MetricChunks({
    required this.profitTillDate,
    required this.marginTillDate,
    required this.expensesTillDate,
    required this.monthlyBilling,
    required this.monthlyExpenses,
    required this.monthlyProfit,
  });

  final double profitTillDate;
  final double marginTillDate;
  final double expensesTillDate;
  final double monthlyBilling;
  final double monthlyExpenses;
  final double monthlyProfit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 10.0;
        final tileW = (constraints.maxWidth - gap) / 2;

        Widget chunk({
          required String label,
          required String value,
          Color? accent,
        }) {
          return SizedBox(
            width: tileW,
            child: ProfitabilityStatTile(
              label: label,
              value: value,
              accent: accent ?? AppColors.text,
            ),
          );
        }

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            chunk(
              label: 'Profit till date',
              value: MoneyFormat.format(profitTillDate),
              accent: profitTillDate >= 0 ? AppColors.success : AppColors.error,
            ),
            chunk(
              label: 'Total expenses',
              value: MoneyFormat.format(expensesTillDate),
            ),
            chunk(
              label: 'Profit %',
              value: '${marginTillDate.toStringAsFixed(1)}%',
              accent: marginTillDate >= 0 ? AppColors.success : AppColors.error,
            ),
            chunk(
              label: 'Monthly billing',
              value: MoneyFormat.format(monthlyBilling),
            ),
            chunk(
              label: 'Monthly expenses',
              value: MoneyFormat.format(monthlyExpenses),
            ),
            chunk(
              label: 'Monthly profit',
              value: MoneyFormat.format(monthlyProfit),
              accent: monthlyProfit >= 0 ? AppColors.success : AppColors.error,
            ),
          ],
        );
      },
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.label, required this.row});

  final String label;
  final MonthlyProfitability row;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(fontSize: 13),
            ),
          ),
          Text(
            MoneyFormat.format(row.profit),
            style: textTheme.titleMedium?.copyWith(
              fontSize: 13,
              color: row.profit >= 0 ? AppColors.success : AppColors.error,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            child: Text(
              '${row.marginPercent.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: AppColors.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({required this.employee});

  final EmployeeProfitability employee;

  static String _lpa(double annual) {
    final lpa = annual / 100000;
    final text = lpa == lpa.roundToDouble()
        ? lpa.toStringAsFixed(0)
        : lpa.toStringAsFixed(1);
    return '$text LPA';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final metaStyle = textTheme.bodyMedium?.copyWith(
      fontSize: 12,
      color: AppColors.textLight,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          EmployeeAvatar(
            name: employee.employeeName,
            radius: 16,
            fontSize: 11,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.employeeName,
                  style: textTheme.titleMedium?.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  employee.hasBillingRate
                      ? 'Billing ${MoneyFormat.format(employee.billingMonthly)}/mo · '
                          'Package ${_lpa(employee.packageAnnual)}'
                      : 'No billing rate',
                  style: metaStyle?.copyWith(
                    color: employee.hasBillingRate
                        ? AppColors.textLight
                        : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${employee.marginPercent.toStringAsFixed(0)}%',
            style: textTheme.titleMedium?.copyWith(
              fontSize: 13,
              color: employee.marginPercent >= 0
                  ? AppColors.success
                  : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
