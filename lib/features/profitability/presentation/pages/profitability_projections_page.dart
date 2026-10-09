import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../injection_container.dart';
import '../../../settings/presentation/widgets/client_name_label.dart';
import '../../domain/services/profitability_calculator.dart';
import '../bloc/profitability_bloc.dart';
import '../widgets/profitability_charts.dart';

class ProfitabilityProjectionsPage extends StatelessWidget {
  const ProfitabilityProjectionsPage({
    super.key,
    required this.clientId,
  });

  final String clientId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<ProfitabilityBloc>()..add(const ProfitabilityStarted()),
      child: _ProjectionsBody(clientId: clientId),
    );
  }
}

class _ProjectionsBody extends StatefulWidget {
  const _ProjectionsBody({required this.clientId});

  final String clientId;

  @override
  State<_ProjectionsBody> createState() => _ProjectionsBodyState();
}

class _ProjectionsBodyState extends State<_ProjectionsBody> {
  late int _fyStartYear;

  @override
  void initState() {
    super.initState();
    final options = ProfitabilityCalculator.financialYearOptions();
    _fyStartYear = options.length > 1 ? options[1] : options.first;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;
    final textTheme = Theme.of(context).textTheme;
    final monthFormat = DateFormat('MMM yyyy');
    final fyOptions = ProfitabilityCalculator.financialYearOptions();

    return BlocBuilder<ProfitabilityBloc, ProfitabilityState>(
      builder: (context, state) {
        if (state.status == ProfitabilityStatus.initial ||
            state.status == ProfitabilityStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        final client = state.clientById(widget.clientId);
        if (client == null) {
          return Center(
            child: Text(
              'Client not found.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textLight),
            ),
          );
        }

        final months = ProfitabilityCalculator.financialYearProjection(
          client,
          fyStartYear: _fyStartYear,
          expenses: state.expenses,
        );
        final totalBilling =
            months.fold<double>(0, (s, m) => s + m.billing).roundToDouble();
        final totalProfit =
            months.fold<double>(0, (s, m) => s + m.profit).roundToDouble();
        final totalMargin = totalBilling > 0
            ? ((totalProfit / totalBilling) * 1000).roundToDouble() / 10
            : 0.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 32),
          children: [
            AppListCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClientNameLabel(
                    name: client.clientName,
                    style: textTheme.titleMedium?.copyWith(fontSize: 15),
                    logoRadius: 12,
                  ),
                  const SizedBox(height: 14),
                  AppDropdown<int>(
                    label: 'Financial year',
                    value: fyOptions.contains(_fyStartYear)
                        ? _fyStartYear
                        : fyOptions.first,
                    items: fyOptions,
                    itemLabel: ProfitabilityCalculator.financialYearLabel,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _fyStartYear = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 520;
                      final tiles = [
                        ProfitabilityStatTile(
                          label: 'FY billing',
                          value: MoneyFormat.format(totalBilling),
                        ),
                        ProfitabilityStatTile(
                          label: 'FY profit',
                          value: MoneyFormat.format(totalProfit),
                          accent: totalProfit >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        ProfitabilityStatTile(
                          label: 'Profit margin',
                          value: '${totalMargin.toStringAsFixed(1)}%',
                          accent: totalMargin >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ];
                      if (wide) {
                        return Row(
                          children: [
                            for (var i = 0; i < tiles.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Expanded(child: tiles[i]),
                            ],
                          ],
                        );
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < tiles.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            tiles[i],
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ProfitabilityBillingProfitBar(
                    billing: totalBilling,
                    profit: totalProfit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ProfitabilityCompactTrendCard(months: months),
            const SizedBox(height: 10),
            ProfitabilityMonthlyChartCard(
              months: months,
              title: 'Billing vs package',
            ),
            const SizedBox(height: 18),
            Text(
              'Months',
              style: textTheme.titleMedium?.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 8),
            AppListCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < months.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppColors.border),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              monthFormat.format(
                                DateTime(months[i].year, months[i].month),
                              ),
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            MoneyFormat.format(months[i].profit),
                            style: textTheme.titleMedium?.copyWith(
                              fontSize: 13,
                              color: months[i].profit >= 0
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 52,
                            child: Text(
                              '${months[i].marginPercent.toStringAsFixed(0)}%',
                              textAlign: TextAlign.right,
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'FY total',
                            style: textTheme.titleMedium?.copyWith(fontSize: 13),
                          ),
                        ),
                        Text(
                          MoneyFormat.format(totalProfit),
                          style: textTheme.titleMedium?.copyWith(
                            fontSize: 13,
                            color: totalProfit >= 0
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 52,
                          child: Text(
                            '${totalMargin.toStringAsFixed(0)}%',
                            textAlign: TextAlign.right,
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

