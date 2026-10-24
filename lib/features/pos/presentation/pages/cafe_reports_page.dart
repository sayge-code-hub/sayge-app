import 'package:flutter/material.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';
import '../widgets/cafe_pos_chrome.dart';

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
      return const CafePosBackdrop(
        child: Center(child: Text('Reports access denied.')),
      );
    }
    final report = _report;

    return CafePosBackdrop(
      child: Column(
        children: [
          Padding(
            padding: CafePosSpace.page(context).copyWith(bottom: 8),
            child: CafePosPageHeader(
              title: 'Reports',
              subtitle: 'Daily sales snapshot',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: _pickDay,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.text,
                      backgroundColor: AppColors.background,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(AppDates.medium.format(_day)),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: _reload,
                    tooltip: 'Refresh',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.background,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.text),
                  )
                : _error != null
                    ? CafePosEmptyState(
                        icon: Icons.wifi_off_rounded,
                        title: 'Couldn’t load report',
                        message: _error!,
                        action: AppButton(
                          label: 'Retry',
                          expand: false,
                          onPressed: _reload,
                        ),
                      )
                    : report == null
                        ? const SizedBox.shrink()
                        : ListView(
                            padding:
                                CafePosSpace.page(context).copyWith(top: 4),
                            children: [
                              _SectionCard(
                                title: 'Overview',
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final wide = constraints.maxWidth >= 480;
                                    final metrics = [
                                      _MetricTile(
                                        label: 'Paid orders',
                                        value: '${report.orderCount}',
                                      ),
                                      _MetricTile(
                                        label: 'Gross sales',
                                        value: MoneyFormat.format(
                                          report.totalSales,
                                        ),
                                      ),
                                    ];
                                    if (wide) {
                                      return Row(
                                        children: [
                                          for (var i = 0;
                                              i < metrics.length;
                                              i++) ...[
                                            if (i > 0) const SizedBox(width: 12),
                                            Expanded(child: metrics[i]),
                                          ],
                                        ],
                                      );
                                    }
                                    return Column(
                                      children: [
                                        for (var i = 0;
                                            i < metrics.length;
                                            i++) ...[
                                          if (i > 0) const SizedBox(height: 10),
                                          metrics[i],
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              _SectionCard(
                                title: 'Payment mix',
                                child: Column(
                                  children: [
                                    for (final e
                                        in report.byPaymentMethod.entries)
                                      if (e.value > 0)
                                        _metricRow(
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
                                              fontSize: 13,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _SectionCard(
                                title: 'Item-wise',
                                child: Column(
                                  children: [
                                    if (report.itemSales.isEmpty)
                                      Text(
                                        'No item sales.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppColors.textLight,
                                              fontSize: 13,
                                            ),
                                      )
                                    else
                                      for (final item in report.itemSales)
                                        _metricRow(
                                          context,
                                          '${item.itemName} × ${item.quantity.toStringAsFixed(0)}',
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
    );
  }

  Widget _metricRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                    fontSize: 13,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CafePosSpace.radius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                  fontSize: 12,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  letterSpacing: -0.4,
                ),
          ),
        ],
      ),
    );
  }
}
