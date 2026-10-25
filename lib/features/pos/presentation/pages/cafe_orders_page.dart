import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';
import '../widgets/cafe_pos_chrome.dart';

final _orderTime = DateFormat('h:mm a');

class CafeOrdersPage extends StatefulWidget {
  const CafeOrdersPage({super.key, required this.cafeId});

  final String cafeId;

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
    CafePosListChrome.refreshTick.addListener(_onChromeRefresh);
    CafePosListChrome.deleteTick.addListener(_onChromeDelete);
    _reload();
  }

  @override
  void dispose() {
    CafePosListChrome.refreshTick.removeListener(_onChromeRefresh);
    CafePosListChrome.deleteTick.removeListener(_onChromeDelete);
    super.dispose();
  }

  void _onChromeRefresh() {
    if (!mounted) return;
    _reload();
  }

  void _onChromeDelete() {
    if (!mounted) return;
    _clearAllOrders();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await sl<GetCafeOrders>()(widget.cafeId, day: _day);
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

  Future<void> _clearAllOrders() async {
    final ok = await confirmLeaveForm(
      context,
      title: 'Delete all orders?',
      message:
          'This permanently removes every order and payment for this cafe '
          '(reports will reset). Menu and tables are not affected.',
      stayLabel: 'Keep',
      leaveLabel: 'Delete all',
    );
    if (!ok || !mounted) return;
    final result = await sl<ClearCafeOrders>()(widget.cafeId);
    if (!mounted) return;
    result.fold(
      (f) => showAppMessageDialog(context, title: 'Orders', message: f.message),
      (_) async {
        await showAppMessageDialog(
          context,
          title: 'Orders',
          message: 'All orders cleared.',
        );
        if (mounted) await _reload();
      },
    );
  }

  Future<void> _cancel(CafeOrder order) async {
    if (order.prepStatus == CafePrepStatus.cancelled) return;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
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

  Color _prepColor(CafePrepStatus status) {
    return switch (status) {
      CafePrepStatus.neu => const Color(0xFFD97706),
      CafePrepStatus.preparing => const Color(0xFF2563EB),
      CafePrepStatus.ready => AppColors.success,
      CafePrepStatus.completed => AppColors.textLight,
      CafePrepStatus.cancelled => AppColors.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    final canTerminal = AppAccess.canRunCafeTerminal(user, widget.cafeId);
    final canKitchen = AppAccess.canRunCafeKitchen(user, widget.cafeId);
    if (!canTerminal && !canKitchen) {
      return const CafePosBackdrop(
        child: Center(child: Text('Orders access denied.')),
      );
    }

    return CafePosBackdrop(
      child: Column(
        children: [
          Padding(
            padding: CafePosSpace.page(context).copyWith(bottom: 8),
            child: CafePosPageHeader(
              title: 'Orders',
              subtitle: 'History for the selected day',
              trailing: TextButton.icon(
                onPressed: _pickDay,
                style: CafePosHeaderActions.dateButtonStyle(),
                icon: const Icon(Icons.calendar_today_outlined, size: 15),
                label: Text(AppDates.medium.format(_day)),
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
                        title: 'Couldn’t load orders',
                        message: _error!,
                        action: AppButton(
                          label: 'Retry',
                          expand: false,
                          onPressed: _reload,
                        ),
                      )
                    : _orders.isEmpty
                        ? const CafePosEmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'No orders',
                            message: 'Nothing for this day yet.',
                          )
                        : ListView.separated(
                            padding:
                                CafePosSpace.page(context).copyWith(top: 4),
                            itemCount: _orders.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final order = _orders[index];
                              final cancelled = order.prepStatus ==
                                  CafePrepStatus.cancelled;
                              final tint = _prepColor(order.prepStatus);
                              return Material(
                                color: AppColors.background,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    CafePosSpace.radius,
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    14,
                                    14,
                                    12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              order.orderNo,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                          Text(
                                            MoneyFormat.format(
                                              order.totalAmount,
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          CafePosStatusChip(
                                            label: order.prepStatus.label,
                                            color: tint,
                                            selected: true,
                                          ),
                                          CafePosStatusChip(
                                            label: order.tableNo.trim().isEmpty
                                                ? order.orderType.label
                                                : 'Table ${order.tableNo.trim()}',
                                            color: AppColors.textLight,
                                          ),
                                          if (order.tableNo.trim().isNotEmpty)
                                            CafePosStatusChip(
                                              label: order.orderType.label,
                                              color: AppColors.textLight,
                                            ),
                                          CafePosStatusChip(
                                            label: order.paymentStatus.label,
                                            color: AppColors.textLight,
                                          ),
                                          CafePosStatusChip(
                                            label: _orderTime.format(
                                              order.createdAt.toLocal(),
                                            ),
                                            color: AppColors.textLight,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        order.items
                                            .map(
                                              (i) =>
                                                  '${i.quantity.toStringAsFixed(0)}× ${i.itemName}',
                                            )
                                            .join(', '),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontSize: 13,
                                              height: 1.35,
                                            ),
                                      ),
                                      if (cancelled &&
                                          order.cancelReason.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Cancelled: ${order.cancelReason}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.error,
                                              ),
                                        ),
                                      ],
                                      if (canTerminal && !cancelled) ...[
                                        const SizedBox(height: 4),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () => _cancel(order),
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
