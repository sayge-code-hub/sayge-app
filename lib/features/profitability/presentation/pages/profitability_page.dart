import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../injection_container.dart';
import '../../../settings/presentation/widgets/client_name_label.dart';
import '../../domain/entities/profitability.dart';
import '../../domain/services/profitability_calculator.dart';
import '../bloc/profitability_bloc.dart';
import '../widgets/profitability_charts.dart';

class ProfitabilityPage extends StatelessWidget {
  const ProfitabilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<ProfitabilityBloc>()..add(const ProfitabilityStarted()),
      child: const _ProfitabilityBody(),
    );
  }
}

class _ProfitabilityBody extends StatelessWidget {
  const _ProfitabilityBody();

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;

    return BlocBuilder<ProfitabilityBloc, ProfitabilityState>(
      builder: (context, state) {
        if (state.status == ProfitabilityStatus.initial ||
            state.status == ProfitabilityStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        if (state.status == ProfitabilityStatus.failure) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(horizontal),
              child: Text(
                state.errorMessage ?? 'Could not load profitability.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                    ),
              ),
            ),
          );
        }

        final clients = state.filteredClients;
        final textTheme = Theme.of(context).textTheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 12),
              child: AppListSearchField(
                hintText: 'Search clients or employees…',
                onChanged: (value) => context.read<ProfitabilityBloc>().add(
                      ProfitabilitySearchChanged(value),
                    ),
              ),
            ),
            Expanded(
              child: clients.isEmpty
                  ? Center(
                      child: Text(
                        state.employees.isEmpty
                            ? 'No active client-assigned employees yet.'
                            : 'No matches.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 12.0;
                        final cols = constraints.maxWidth >= 900 ? 3 : 2;
                        final tileW = (constraints.maxWidth -
                                horizontal * 2 -
                                gap * (cols - 1)) /
                            cols;

                        return SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            0,
                            horizontal,
                            24,
                          ),
                          child: Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final client in clients)
                                SizedBox(
                                  width: tileW,
                                  child: _ClientProfitCard(client: client),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ClientProfitCard extends StatelessWidget {
  const _ClientProfitCard({required this.client});

  final ClientProfitability client;

  static const _projectionBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final months = ProfitabilityCalculator.monthWiseForClient(
      client,
      expenses: context.read<ProfitabilityBloc>().state.expenses,
    );
    final profitTillDate =
        months.fold<double>(0, (s, m) => s + m.profit).roundToDouble();
    final billingTillDate =
        months.fold<double>(0, (s, m) => s + m.billing).roundToDouble();
    final marginTillDate = billingTillDate > 0
        ? ((profitTillDate / billingTillDate) * 1000).roundToDouble() / 10
        : client.marginPercent;

    return AppListCard(
      onTap: () => context.go(AppRoutes.profitabilityClient(client.clientId)),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClientNameLabel(
                  name: client.clientName,
                  style: textTheme.titleMedium?.copyWith(fontSize: 13),
                  logoRadius: 10,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.go(
                  AppRoutes.profitabilityProjections(client.clientId),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.show_chart_rounded,
                        size: 14,
                        color: _projectionBlue,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Projection',
                        style: textTheme.labelLarge?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _projectionBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: _EmployeeCountChip(count: client.employeeCount),
          ),
          const SizedBox(height: 10),
          _MetricRow(
            label: 'Profit till date',
            value: MoneyFormat.format(profitTillDate),
            color: profitTillDate >= 0 ? AppColors.success : AppColors.error,
          ),
          const SizedBox(height: 6),
          _MetricRow(
            label: 'Profit %',
            value: '${marginTillDate.toStringAsFixed(1)}%',
            color: marginTillDate >= 0 ? AppColors.success : AppColors.error,
          ),
          const SizedBox(height: 6),
          _MetricRow(
            label: 'Monthly billing',
            value: MoneyFormat.format(client.billingMonthly),
          ),
          const SizedBox(height: 6),
          _MetricRow(
            label: 'Monthly expenses',
            value: MoneyFormat.format(client.expensesMonthly),
          ),
          const SizedBox(height: 6),
          _MetricRow(
            label: 'Monthly profit',
            value: MoneyFormat.format(client.grossProfit),
            color: client.grossProfit >= 0 ? AppColors.success : AppColors.error,
          ),
          const SizedBox(height: 8),
          ProfitabilityMarginBar(marginPercent: marginTillDate),
        ],
      ),
    );
  }
}

class _EmployeeCountChip extends StatelessWidget {
  const _EmployeeCountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = count == 0
        ? 'No employees'
        : '$count ${count == 1 ? 'employee' : 'employees'}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            count == 0
                ? Icons.apartment_outlined
                : Icons.people_outline_rounded,
            size: 13,
            color: AppColors.textLight,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              fontSize: 10,
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 11,
              color: AppColors.textLight,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}
