import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';

final _orderTime = DateFormat('h:mm a');

class CafeOrdersPage extends StatefulWidget {
  const CafeOrdersPage({super.key, required this.clientId});

  final String clientId;

  @override
  State<CafeOrdersPage> createState() => _CafeOrdersPageState();
}

class _CafeOrdersPageState extends State<CafeOrdersPage> {
  List<CafeOrder> _orders = const [];
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
    final result = await sl<GetCafeOrders>()(widget.clientId, day: _day);
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (list) => setState(() {
        _orders = list;
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

  Future<void> _cancel(CafeOrder order) async {
    if (order.prepStatus == CafePrepStatus.cancelled) return;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel ${order.orderNo}?'),
        content: AppTextField(
          label: 'Reason',
          controller: reason,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          AppButton(
            label: 'Cancel order',
            expand: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await sl<CancelCafeOrder>()(
      orderId: order.id,
      reason: reason.text,
    );
    if (!mounted) return;
    result.fold(
      (f) => showAppMessageDialog(context, title: 'Orders', message: f.message),
      (_) => _reload(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    final canTerminal = AppAccess.canRunCafeTerminal(user, widget.clientId);
    final canKitchen = AppAccess.canRunCafeKitchen(user, widget.clientId);
    if (!canTerminal && !canKitchen) {
      return const Center(child: Text('Orders access denied.'));
    }
    final isDesktop = Breakpoints.isDesktop(context);

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
              IconButton(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
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
                  : _orders.isEmpty
                      ? Center(
                          child: Text(
                            'No orders for this day.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textLight),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 32 : 16,
                            8,
                            isDesktop ? 32 : 16,
                            24,
                          ),
                          itemCount: _orders.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            final cancelled =
                                order.prepStatus == CafePrepStatus.cancelled;
                            return AppListCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          order.orderNo,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(fontSize: 14),
                                        ),
                                      ),
                                      Text(
                                        MoneyFormat.format(order.totalAmount),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      order.orderType.label,
                                      order.prepStatus.label,
                                      order.paymentStatus.label,
                                      _orderTime.format(
                                        order.createdAt.toLocal(),
                                      ),
                                    ].join(' · '),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.textLight),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    order.items
                                        .map(
                                          (i) =>
                                              '${i.quantity.toStringAsFixed(0)}× ${i.itemName}',
                                        )
                                        .join(', '),
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  if (cancelled &&
                                      order.cancelReason.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Cancelled: ${order.cancelReason}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.error),
                                    ),
                                  ],
                                  if (canTerminal && !cancelled) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => _cancel(order),
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
