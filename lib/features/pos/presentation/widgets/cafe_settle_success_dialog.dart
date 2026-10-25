import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/cafe_entities.dart';

/// Confirmation after a bill is settled — green check pulse.
Future<String?> showCafeSettleSuccessDialog(
  BuildContext context, {
  required CafeOrder order,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SettleSuccessDialog(order: order),
  );
}

class _SettleSuccessDialog extends StatefulWidget {
  const _SettleSuccessDialog({required this.order});

  final CafeOrder order;

  @override
  State<_SettleSuccessDialog> createState() => _SettleSuccessDialogState();
}

class _SettleSuccessDialogState extends State<_SettleSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return AlertDialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: Tween(begin: 0.6, end: 1.0).animate(
              CurvedAnimation(parent: _pulse, curve: Curves.elasticOut),
            ),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.check_rounded,
                size: 40,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Bill settled',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            [
              'Order ${order.orderNo}',
              if (order.tableNo.trim().isNotEmpty)
                ' · Table ${order.tableNo.trim()}',
              '\n${MoneyFormat.format(order.totalAmount)} paid',
            ].join(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                  height: 1.35,
                ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'ok'),
          child: const Text('Done'),
        ),
        AppButton(
          label: 'Receipt PDF',
          expand: false,
          onPressed: () => Navigator.pop(context, 'pdf'),
        ),
      ],
    );
  }
}

/// Cash tendered numpad — returns amount handed by the customer.
Future<double?> showCafeCashTenderDialog(
  BuildContext context, {
  required double due,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _CashTenderSheet(due: due),
  );
}

class _CashTenderSheet extends StatefulWidget {
  const _CashTenderSheet({required this.due});

  final double due;

  @override
  State<_CashTenderSheet> createState() => _CashTenderSheetState();
}

class _CashTenderSheetState extends State<_CashTenderSheet> {
  String _digits = '';

  /// Whole-rupee due matching [MoneyFormat] (0 decimal places).
  int get _dueRupees => widget.due.round();

  int get _tenderedRupees {
    if (_digits.isEmpty) return 0;
    final parsed = double.tryParse(_digits) ?? 0;
    return parsed.round();
  }

  double get _tendered => _tenderedRupees.toDouble();

  int get _changeRupees =>
      (_tenderedRupees - _dueRupees).clamp(0, 1 << 30);

  double get _change => _changeRupees.toDouble();

  void _press(String key) {
    setState(() {
      if (key == 'C') {
        _digits = '';
        return;
      }
      if (key == '⌫') {
        if (_digits.isNotEmpty) {
          _digits = _digits.substring(0, _digits.length - 1);
        }
        return;
      }
      if (key == '.' && _digits.contains('.')) return;
      if (_digits.replaceAll('.', '').length >= 8) return;
      _digits += key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enough = _tenderedRupees >= _dueRupees;
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', '⌫'],
    ];
    final bottomPad = MediaQuery.paddingOf(context).bottom + 28;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Cash received',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Due ${MoneyFormat.format(_dueRupees)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              _digits.isEmpty ? '0' : _digits,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 40,
                    letterSpacing: -1,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              enough
                  ? 'Change ${MoneyFormat.format(_change)}'
                  : 'Enter amount handed by customer',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: enough ? AppColors.success : AppColors.textLight,
              ),
            ),
            const SizedBox(height: 16),
            for (final row in keys) ...[
              Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Material(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _press(key),
                            child: SizedBox(
                              height: 56,
                              child: Center(
                                child: Text(
                                  key,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _press('C'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: AppColors.text,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: enough ? 'Confirm cash' : 'Amount too low',
                    onPressed: enough
                        ? () => Navigator.pop(context, _tendered)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
