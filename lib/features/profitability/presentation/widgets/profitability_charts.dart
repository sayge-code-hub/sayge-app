import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../domain/entities/profitability.dart';

class ProfitabilityChartLegend extends StatelessWidget {
  const ProfitabilityChartLegend({
    super.key,
    required this.items,
  });

  final List<({Color color, String label})> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                item.label,
                style: textTheme.labelLarge?.copyWith(
                  fontSize: 11,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Small sparkline + monthly profit bars in one compact card.
class ProfitabilityCompactTrendCard extends StatelessWidget {
  const ProfitabilityCompactTrendCard({
    super.key,
    required this.months,
  });

  final List<MonthlyProfitability> months;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (months.isEmpty) return const SizedBox.shrink();

    final monthFormat = DateFormat('MMM');
    final labels = months
        .map((m) => monthFormat.format(DateTime(m.year, m.month)))
        .toList();
    final profits = months.map((m) => m.profit).toList();

    return AppListCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Profit by month',
            style: textTheme.titleMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: CustomPaint(
              painter: _SimpleBarPainter(
                values: profits,
                color: AppColors.success,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 6),
          _BottomMonthLabels(labels: labels),
        ],
      ),
    );
  }
}

/// Compact FY / overview chart (bars only, no stacked mega card).
class ProfitabilityMonthlyChartCard extends StatelessWidget {
  const ProfitabilityMonthlyChartCard({
    super.key,
    required this.months,
    this.title = 'Monthly overview',
  });

  final List<MonthlyProfitability> months;
  final String title;

  static const billingColor = AppColors.text;
  static const packageColor = Color(0xFFD1D5DB);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (months.isEmpty) {
      return AppListCard(
        child: Text(
          'No data to chart.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textLight),
        ),
      );
    }

    final monthFormat = DateFormat('MMM');
    final labels = months
        .map((m) => monthFormat.format(DateTime(m.year, m.month)))
        .toList();

    return AppListCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _GroupedBarPainter(
                billing: months.map((m) => m.billing).toList(),
                package: months.map((m) => m.packageAmount).toList(),
                billingColor: billingColor,
                packageColor: packageColor,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 6),
          _BottomMonthLabels(labels: labels),
          const SizedBox(height: 8),
          const ProfitabilityChartLegend(
            items: [
              (color: billingColor, label: 'Billing'),
              (color: packageColor, label: 'Package'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleBarPainter extends CustomPainter {
  _SimpleBarPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxY = values.fold<double>(0, (a, b) => b.abs() > a ? b.abs() : a);
    final chartMax = maxY <= 0 ? 1.0 : maxY * 1.1;
    final n = values.length;
    final gap = 4.0;
    final barW = ((size.width - gap * (n - 1)) / n).clamp(6.0, 28.0);
    final totalW = barW * n + gap * (n - 1);
    final startX = (size.width - totalW) / 2;

    for (var i = 0; i < n; i++) {
      final h = (values[i].abs() / chartMax) * size.height;
      final x = startX + i * (barW + gap);
      final top = size.height - h;
      final r = Radius.circular(barW.clamp(2, 5));
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, top, barW, h),
          topLeft: r,
          topRight: r,
        ),
        Paint()
          ..color = values[i] >= 0
              ? color
              : AppColors.error.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleBarPainter old) =>
      old.values != values || old.color != color;
}

class _BottomMonthLabels extends StatelessWidget {
  const _BottomMonthLabels({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final showEvery = labels.length > 8 ? 2 : 1;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Text(
              i % showEvery == 0 ? labels[i] : '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AppColors.textLight),
            ),
          ),
      ],
    );
  }
}

class _GroupedBarPainter extends CustomPainter {
  _GroupedBarPainter({
    required this.billing,
    required this.package,
    required this.billingColor,
    required this.packageColor,
  });

  final List<double> billing;
  final List<double> package;
  final Color billingColor;
  final Color packageColor;

  static const _leftPad = 4.0;
  static const _bottomPad = 4.0;
  static const _topPad = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (billing.isEmpty) return;

    final maxY = [
      ...billing,
      ...package,
    ].fold<double>(0, (a, b) => b > a ? b : a);
    final chartMax = maxY <= 0 ? 1.0 : maxY * 1.08;
    final chartH = size.height - _bottomPad - _topPad;
    final chartW = size.width - _leftPad;
    final n = billing.length;
    final groupW = chartW / n;
    final barW = (groupW * 0.28).clamp(4.0, 14.0);

    final gridPaint = Paint()..color = AppColors.border;
    for (var i = 0; i <= 4; i++) {
      final y = _topPad + chartH * (1 - i / 4);
      canvas.drawLine(
        Offset(_leftPad, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    for (var i = 0; i < n; i++) {
      final cx = _leftPad + groupW * i + groupW / 2;
      _drawBar(
        canvas,
        cx - barW / 2 - 2,
        barW,
        billing[i],
        chartMax,
        chartH,
        billingColor,
      );
      _drawBar(
        canvas,
        cx + 2,
        barW,
        package[i],
        chartMax,
        chartH,
        packageColor,
      );
    }
  }

  void _drawBar(
    Canvas canvas,
    double x,
    double w,
    double value,
    double maxY,
    double chartH,
    Color color,
  ) {
    final h = (value / maxY) * chartH;
    final top = _topPad + chartH - h;
    final r = Radius.circular(w.clamp(2, 6));
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x, top, w, h),
        topLeft: r,
        topRight: r,
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _GroupedBarPainter old) =>
      old.billing != billing || old.package != package;
}

class ProfitabilityClientShareCard extends StatelessWidget {
  const ProfitabilityClientShareCard({
    super.key,
    required this.clients,
  });

  final List<ClientProfitability> clients;

  static const _palette = [
    AppColors.text,
    AppColors.highlight,
    AppColors.success,
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final withProfit = clients.where((c) => c.grossProfit > 0).toList();
    if (withProfit.isEmpty) return const SizedBox.shrink();

    final total = withProfit.fold<double>(0, (s, c) => s + c.grossProfit);
    final slices = [
      for (var i = 0; i < withProfit.length; i++)
        _DonutSlice(
          value: withProfit[i].grossProfit,
          color: _palette[i % _palette.length],
        ),
    ];

    return AppListCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Profit mix',
            style: textTheme.titleMedium?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _DonutPainter(slices: slices),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          MoneyFormat.format(total),
                          style: textTheme.titleMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'monthly',
                          style: textTheme.labelLarge?.copyWith(
                            fontSize: 10,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < withProfit.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _palette[i % _palette.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                withProfit[i].clientName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              '${((withProfit[i].grossProfit / total) * 100).toStringAsFixed(0)}%',
                              style: textTheme.labelLarge?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutSlice {
  _DonutSlice({required this.value, required this.color});
  final double value;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices});

  final List<_DonutSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outer = math.min(size.width, size.height) / 2 - 2;
    const inner = 0.58;
    var start = -math.pi / 2;

    for (final slice in slices) {
      final sweep = (slice.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = outer * (1 - inner)
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outer - paint.strokeWidth / 2),
        start,
        sweep - 0.02,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.slices != slices;
}

class ProfitabilityStatTile extends StatelessWidget {
  const ProfitabilityStatTile({
    super.key,
    required this.label,
    required this.value,
    this.accent = AppColors.text,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: 11,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfitabilityMarginBar extends StatelessWidget {
  const ProfitabilityMarginBar({super.key, required this.marginPercent});

  final double marginPercent;

  @override
  Widget build(BuildContext context) {
    final positive = marginPercent >= 0;
    final fill = (marginPercent.abs() / 50).clamp(0.0, 1.0);
    final color = positive ? AppColors.success : AppColors.error;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 6,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.surfaceMuted),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fill,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.5), color],
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

class ProfitabilityBillingProfitBar extends StatelessWidget {
  const ProfitabilityBillingProfitBar({
    super.key,
    required this.billing,
    required this.profit,
  });

  final double billing;
  final double profit;

  @override
  Widget build(BuildContext context) {
    if (billing <= 0) return const SizedBox.shrink();
    final profitShare = (profit / billing).clamp(0.0, 1.0);
    final packageShare = (1 - profitShare).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        width: double.infinity,
        child: Row(
          children: [
            if (packageShare > 0)
              Expanded(
                flex: (packageShare * 1000).round(),
                child: Container(color: const Color(0xFFE5E7EB)),
              ),
            if (profitShare > 0)
              Expanded(
                flex: (profitShare * 1000).round(),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.success.withValues(alpha: 0.75),
                        AppColors.success,
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
