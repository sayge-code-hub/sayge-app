import 'package:flutter/material.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';

class CafeReportsPage extends StatefulWidget {
  const CafeReportsPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<CafeReportsPage> createState() => _CafeReportsPageState();
}

class _CafeReportsPageState extends State<CafeReportsPage> {
  CafeDailyReport? _report;
  bool _loading = true;
  String? _error;
  DateTime _day = DateTime.now();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await sl<GetCafeDailyReport>()(
      cafeId: widget.cafeId,
      day: _day,
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (report) => setState(() {
        _report = report;
        _loading = false;
      }),
    );
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() => _day = picked);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (!AppAccess.canViewCafeReports(user, widget.cafeId)) {
      return const Center(child: Text('Reports access denied.'));
    }
    final isDesktop = Breakpoints.isDesktop(context);
    final report = _report;

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
            children: [
              TextButton.icon(
                onPressed: _pickDay,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(AppDates.medium.format(_day)),
              ),
              const Spacer(),
              IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.text),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          const SizedBox(height: 12),
                          AppButton(
                            label: 'Retry',
                            expand: false,
                            onPressed: _reload,
                          ),
                        ],
                      ),
                    )
                  : report == null
                      ? const SizedBox.shrink()
                      : ListView(
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 32 : 16,
                            8,
                            isDesktop ? 32 : 16,
                            24,
                          ),
                          children: [
                            AppListCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Daily sales',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  _metric(
                                    context,
                                    'Paid orders',
                                    '${report.orderCount}',
                                  ),
                                  _metric(
                                    context,
                                    'Gross sales',
                                    MoneyFormat.format(report.totalSales),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            AppListCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payment mix',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  for (final e
                                      in report.byPaymentMethod.entries)
                                    if (e.value > 0)
                                      _metric(
                                        context,
                                        e.key.label,
                                        MoneyFormat.format(e.value),
                                      ),
                                  if (report.byPaymentMethod.values
                                      .every((v) => v <= 0))
                                    Text(
                                      'No payments recorded.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textLight,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            AppListCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Item-wise',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  if (report.itemSales.isEmpty)
                                    Text(
                                      'No item sales.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textLight,
                                          ),
                                    )
                                  else
                                    for (final item in report.itemSales)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${item.itemName} × ${item.quantity.toStringAsFixed(0)}',
                                              ),
                                            ),
                                            Text(
                                              MoneyFormat.format(item.value),
                                            ),
                                          ],
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
  }

  Widget _metric(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 14,
                ),
          ),
        ],
      ),
    );
  }
}
