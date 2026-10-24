import 'package:flutter/material.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/pdf_saver.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../../settings/domain/usecases/get_clients.dart';
import '../../data/cafe_receipt_pdf.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';

class CafeTerminalPage extends StatefulWidget {
  const CafeTerminalPage({super.key, required this.clientId});

  final String clientId;

  @override
  State<CafeTerminalPage> createState() => _CafeTerminalPageState();
}

class _CafeTerminalPageState extends State<CafeTerminalPage> {
  List<CafeCategory> _categories = const [];
  List<CafeMenuItem> _items = const [];
  final List<CafeCartLine> _cart = [];
  CafeOrderType _orderType = CafeOrderType.dineIn;
  String? _categoryFilter;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _cafeName = 'Cafe';

  @override
  void initState() {
    super.initState();
    _reload();
    _loadCafeName();
  }

  Future<void> _loadCafeName() async {
    final result = await sl<GetClientsUseCase>()();
    result.fold((_) {}, (clients) {
      for (final c in clients) {
        if (c.id == widget.clientId && mounted) {
          setState(() => _cafeName = c.name);
          return;
        }
      }
    });
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final cats = await sl<GetCafeCategories>()(widget.clientId);
    final items = await sl<GetCafeMenuItems>()(
      widget.clientId,
      availableOnly: true,
    );
    if (!mounted) return;
    cats.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (list) {
        items.fold(
          (f) => setState(() {
            _loading = false;
            _error = f.message;
          }),
          (menu) => setState(() {
            _categories = list.where((c) => c.isActive).toList();
            _items = menu.where((i) => i.isActive && i.isAvailable).toList();
            _loading = false;
          }),
        );
      },
    );
  }

  void _addItem(CafeMenuItem item) {
    setState(() {
      final existing = _cart.where((l) => l.menuItem.id == item.id);
      if (existing.isNotEmpty) {
        existing.first.quantity += 1;
      } else {
        _cart.add(CafeCartLine(menuItem: item));
      }
    });
  }

  double get _subtotal =>
      _cart.fold<double>(0, (s, l) => s + l.lineTotal);

  double get _tax => _cart.fold<double>(
        0,
        (s, l) => s + l.lineTotal * (l.menuItem.taxRate / 100),
      );

  double get _total => _subtotal + _tax;

  Future<void> _checkout() async {
    if (_cart.isEmpty || _busy) return;
    final method = await showModalBottomSheet<CafePaymentMethod>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Pay ${MoneyFormat.format(_total)}',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final m in CafePaymentMethod.values)
              ListTile(
                leading: Icon(switch (m) {
                  CafePaymentMethod.cash => Icons.payments_outlined,
                  CafePaymentMethod.upi => Icons.qr_code_2_outlined,
                  CafePaymentMethod.card => Icons.credit_card_outlined,
                }),
                title: Text(m.label),
                onTap: () => Navigator.pop(ctx, m),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (method == null || !mounted) return;

    setState(() => _busy = true);
    final created = await sl<CreateCafeOrder>()(
      clientId: widget.clientId,
      orderType: _orderType,
      lines: List.of(_cart),
    );
    if (!mounted) return;

    await created.fold(
      (f) async {
        setState(() => _busy = false);
        await showAppMessageDialog(
          context,
          title: 'Terminal',
          message: f.message,
        );
      },
      (order) async {
        final paid = await sl<RecordCafePayment>()(
          orderId: order.id,
          method: method,
          amount: order.totalAmount,
        );
        if (!mounted) return;
        setState(() => _busy = false);
        await paid.fold(
          (f) async {
            await showAppMessageDialog(
              context,
              title: 'Payment',
              message: f.message,
            );
          },
          (paidOrder) async {
            setState(_cart.clear);
            await _showReceipt(paidOrder);
          },
        );
      },
    );
  }

  Future<void> _showReceipt(CafeOrder order) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Order ${order.orderNo}'),
        content: Text(
          'Paid ${MoneyFormat.format(order.totalAmount)}. '
          'Kitchen has the ticket.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'ok'),
            child: const Text('Done'),
          ),
          AppButton(
            label: 'Receipt PDF',
            expand: false,
            onPressed: () => Navigator.pop(ctx, 'pdf'),
          ),
        ],
      ),
    );
    if (action == 'pdf' && mounted) {
      try {
        final doc = await CafeReceiptPdf.build(order, cafeName: _cafeName);
        final bytes = await doc.save();
        await savePdfBytes(
          bytes: bytes,
          filename: 'Receipt_${order.orderNo}.pdf',
        );
      } catch (e) {
        if (!mounted) return;
        await showAppMessageDialog(
          context,
          title: 'Receipt',
          message: 'Could not save receipt PDF.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (!AppAccess.canRunCafeTerminal(user, widget.clientId)) {
      return const Center(child: Text('Terminal access denied.'));
    }
    final isDesktop = Breakpoints.isDesktop(context);
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.text),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            AppButton(label: 'Retry', expand: false, onPressed: _reload),
          ],
        ),
      );
    }

    final visible = _categoryFilter == null
        ? _items
        : _items.where((i) => i.categoryId == _categoryFilter).toList();

    final menu = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SegmentedButton<CafeOrderType>(
            segments: [
              for (final t in CafeOrderType.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {_orderType},
            onSelectionChanged: (s) => setState(() => _orderType = s.first),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('All'),
                  selected: _categoryFilter == null,
                  onSelected: (_) => setState(() => _categoryFilter = null),
                ),
              ),
              for (final c in _categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(c.name),
                    selected: _categoryFilter == c.id,
                    onSelected: (_) =>
                        setState(() => _categoryFilter = c.id),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final item = visible[index];
              return Material(
                color: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _addItem(item),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontSize: 14),
                          ),
                        ),
                        Text(
                          MoneyFormat.format(item.price),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );

    final cart = _CartPanel(
      cart: _cart,
      subtotal: _subtotal,
      tax: _tax,
      total: _total,
      busy: _busy,
      onClear: () => setState(_cart.clear),
      onQty: (line, delta) {
        setState(() {
          line.quantity += delta;
          if (line.quantity <= 0) _cart.remove(line);
        });
      },
      onPay: _checkout,
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(flex: 3, child: menu),
          const VerticalDivider(width: 1),
          SizedBox(width: 340, child: cart),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: menu),
        Material(
          elevation: 8,
          color: AppColors.background,
          child: SafeArea(
            top: false,
            child: cart,
          ),
        ),
      ],
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({
    required this.cart,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.busy,
    required this.onClear,
    required this.onQty,
    required this.onPay,
  });

  final List<CafeCartLine> cart;
  final double subtotal;
  final double tax;
  final double total;
  final bool busy;
  final VoidCallback onClear;
  final void Function(CafeCartLine line, double delta) onQty;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Cart',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (cart.isNotEmpty)
                TextButton(onPressed: onClear, child: const Text('Clear')),
            ],
          ),
          if (cart.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Tap items to add',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: cart.length,
                itemBuilder: (context, index) {
                  final line = cart[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(line.menuItem.name),
                    subtitle: Text(MoneyFormat.format(line.lineTotal)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => onQty(line, -1),
                        ),
                        Text(line.quantity.toStringAsFixed(0)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => onQty(line, 1),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const Divider(),
          Row(
            children: [
              const Text('Total'),
              const Spacer(),
              Text(
                MoneyFormat.format(total),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          if (tax > 0)
            Text(
              'incl. tax ${MoneyFormat.format(tax)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textLight,
                  ),
            ),
          const SizedBox(height: 8),
          AppButton(
            label: busy ? 'Processing…' : 'Pay',
            enabled: cart.isNotEmpty && !busy,
            isLoading: busy,
            onPressed: onPay,
          ),
        ],
      ),
    );
  }
}
