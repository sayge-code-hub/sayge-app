import 'package:flutter/material.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/pdf_saver.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_filter_dropdown.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../data/cafe_receipt_pdf.dart';
import '../../data/cafe_terminal_session_cache.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';
import '../widgets/cafe_pos_catalog.dart';
import '../widgets/cafe_pos_chrome.dart';

class CafeTerminalPage extends StatefulWidget {
  const CafeTerminalPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<CafeTerminalPage> createState() => _CafeTerminalPageState();
}

class _CafeTerminalPageState extends State<CafeTerminalPage> {
  List<CafeCategory> _categories = const [];
  List<CafeMenuItem> _items = const [];
  final Map<String, CafeTerminalSession> _sessions = {};
  String? _activeKey;
  String? _categoryFilter;
  String _query = '';
  bool _loading = true;
  bool _busy = false;
  bool _applyingCoupon = false;
  String? _error;
  String _cafeName = 'Cafe';
  Cafe? _cafe;
  List<CafeCoupon> _coupons = const [];
  final _couponCode = TextEditingController();

  CafeTerminalSession? get _session =>
      _activeKey == null ? null : _sessions[_activeKey];

  List<CafeCartLine> get _cart => _session?.lines ?? const [];

  CafeOrderType get _orderType =>
      _session?.orderType ?? CafeOrderType.dineIn;

  String get _tableNo => _session?.tableNo.trim() ?? '';

  CafeCoupon? get _coupon {
    final s = _session;
    if (s == null) return null;
    final id = s.couponId;
    if (id != null) {
      for (final c in _coupons) {
        if (c.id == id) return c;
      }
    }
    final code = s.couponCode.trim().toUpperCase();
    if (code.isEmpty) return null;
    for (final c in _coupons) {
      if (c.code.toUpperCase() == code) return c;
    }
    return null;
  }

  String get _orderTitle {
    final s = _session;
    if (s == null) return 'Select a table';
    return s.label;
  }

  List<CafeTerminalSession> get _openTabs {
    final list = _sessions.values
        .where(
          (s) =>
              !s.isEmpty ||
              (s.orderType == CafeOrderType.dineIn &&
                  s.tableNo.trim().isNotEmpty),
        )
        .toList();
    list.sort((a, b) {
      if (a.orderType != b.orderType) {
        return a.orderType == CafeOrderType.dineIn ? -1 : 1;
      }
      final an = int.tryParse(a.tableNo) ?? 999;
      final bn = int.tryParse(b.tableNo) ?? 999;
      return an.compareTo(bn);
    });
    return list;
  }

  @override
  void dispose() {
    CafePosTerminalChrome.newTableTick.removeListener(_onChromeNewTable);
    CafePosTerminalChrome.clearTablesTick.removeListener(_onChromeClearTables);
    _couponCode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    CafePosTerminalChrome.newTableTick.addListener(_onChromeNewTable);
    CafePosTerminalChrome.clearTablesTick.addListener(_onChromeClearTables);
    _reload();
    _loadCafe();
  }

  void _onChromeNewTable() {
    if (!mounted) return;
    _pickTable();
  }

  void _onChromeClearTables() {
    if (!mounted) return;
    _clearAllTables();
  }

  Future<void> _clearAllTables() async {
    if (_sessions.isEmpty) {
      await showAppMessageDialog(
        context,
        title: 'Tables',
        message: 'No open tables to clear.',
      );
      return;
    }
    final ok = await confirmLeaveForm(
      context,
      title: 'Clear all tables?',
      message:
          'This closes every open table tab and clears their carts. '
          'This cannot be undone.',
      stayLabel: 'Keep',
      leaveLabel: 'Clear all',
    );
    if (!ok || !mounted) return;
    setState(() {
      _sessions.clear();
      _activeKey = null;
      _couponCode.clear();
    });
    await sl<CafeTerminalSessionCache>().clear(widget.cafeId);
  }

  Future<void> _persistSessions() async {
    await sl<CafeTerminalSessionCache>().save(
      cafeId: widget.cafeId,
      sessions: Map.of(_sessions),
      activeKey: _activeKey,
    );
  }

  void _syncCouponField() {
    final s = _session;
    _couponCode.text = s?.couponCode ?? '';
  }

  void _activateSession(CafeTerminalSession session) {
    final key = session.storageKey;
    _sessions.removeWhere((k, v) => identical(v, session) && k != key);
    _sessions[key] = session;
    _activeKey = key;
    _syncCouponField();
  }

  Future<void> _restoreSessions(List<CafeMenuItem> menu) async {
    final loaded = await sl<CafeTerminalSessionCache>().load(
      cafeId: widget.cafeId,
      menu: menu,
    );
    if (!mounted) return;
    _sessions
      ..clear()
      ..addAll(loaded.sessions);
    _activeKey = loaded.activeKey;
    _syncCouponField();
  }

  Future<void> _loadCafe() async {
    final result = await sl<GetCafes>()();
    result.fold((_) {}, (cafes) {
      for (final c in cafes) {
        if (c.id == widget.cafeId && mounted) {
          setState(() {
            _cafe = c;
            _cafeName = c.name;
          });
          return;
        }
      }
    });
    final coupons = await sl<GetCafeCoupons>()(widget.cafeId);
    if (!mounted) return;
    coupons.fold((_) {}, (list) {
      setState(() {
        _coupons = list.where((c) => c.isActive).toList(growable: false);
      });
    });
  }

  Future<void> _pickCoupon() async {
    if (_cart.isEmpty) {
      await showAppMessageDialog(
        context,
        title: 'Coupon',
        message: 'Add items before applying a coupon.',
      );
      return;
    }
    if (_coupons.isEmpty) {
      await showAppMessageDialog(
        context,
        title: 'Coupon',
        message: 'No active coupons. Add some in POS Settings.',
      );
      return;
    }
    final selected = await showModalBottomSheet<CafeCoupon>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  title: Text(
                    'Choose a coupon',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  subtitle: const Text('Or type a code and tap Apply'),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in _coupons)
                        ListTile(
                          leading: Icon(
                            Icons.local_offer_outlined,
                            color: AppColors.highlight,
                          ),
                          title: Text(
                            c.code,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          subtitle: Text(
                            [
                              if (c.name.isNotEmpty) c.name,
                              c.discountType == CafeDiscountType.percent
                                  ? '${c.discountValue.toStringAsFixed(c.discountValue == c.discountValue.roundToDouble() ? 0 : 1)}% off'
                                  : '${MoneyFormat.format(c.discountValue)} off',
                            ].join(' · '),
                          ),
                          onTap: () => Navigator.pop(ctx, c),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    await _applyCouponEntity(selected);
  }

  Future<void> _applyCouponEntity(CafeCoupon coupon) async {
    final err = coupon.validationError(subtotal: _subtotal);
    if (err != null) {
      await showAppMessageDialog(context, title: 'Coupon', message: err);
      return;
    }
    final s = _session;
    if (s == null) return;
    setState(() {
      s.couponId = coupon.id;
      s.couponCode = coupon.code;
      _couponCode.text = coupon.code;
    });
    await _persistSessions();
  }

  Future<void> _editLineNotes(CafeCartLine line) async {
    final notes = TextEditingController(text: line.notes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Instructions · ${line.menuItem.name}'),
        content: AppTextField(
          label: 'e.g. less onion, no sugar',
          controller: notes,
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Save',
            expand: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => line.notes = notes.text.trim());
    await _persistSessions();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final cats = await sl<GetCafeCategories>()(widget.cafeId);
    final items = await sl<GetCafeMenuItems>()(
      widget.cafeId,
      availableOnly: true,
    );
    if (!mounted) return;
    await cats.fold(
      (f) async => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (list) async {
        await items.fold(
          (f) async => setState(() {
            _loading = false;
            _error = f.message;
          }),
          (menu) async {
            final activeMenu =
                menu.where((i) => i.isActive && i.isAvailable).toList();
            await _restoreSessions(activeMenu);
            if (!mounted) return;
            setState(() {
              _categories = list.where((c) => c.isActive).toList();
              _items = activeMenu;
              _loading = false;
            });
          },
        );
      },
    );
  }

  Future<bool> _ensureOrderingSession() async {
    final s = _session;
    if (s != null) {
      if (s.orderType == CafeOrderType.dineIn && s.tableNo.trim().isEmpty) {
        return _pickTable();
      }
      return true;
    }
    // Prefer dine-in table pick for a new session.
    return _pickTable();
  }

  Future<bool> _pickTable() async {
    final count = (_cafe?.tableCount ?? 16).clamp(1, 100);
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Select table',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Open a tab per table — switch anytime until the bill is paid.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.35,
                    ),
                    itemCount: count,
                    itemBuilder: (context, index) {
                      final no = '${index + 1}';
                      final key = CafeTerminalSession.keyFor(
                        orderType: CafeOrderType.dineIn,
                        tableNo: no,
                      );
                      final open = _sessions[key];
                      final isOpen = open != null && !open.isEmpty;
                      final isActive = _activeKey == key;
                      return Material(
                        color: isActive
                            ? AppColors.highlight.withValues(alpha: 0.16)
                            : AppColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isActive || isOpen
                                ? AppColors.highlight
                                : AppColors.border,
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.pop(ctx, no),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                no,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: AppColors.text,
                                ),
                              ),
                              if (isOpen)
                                Text(
                                  '${open.itemCount}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.highlight,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, 'takeaway'),
                  child: const Text('Takeaway instead'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return false;
    if (selected == 'takeaway') {
      _switchToTakeaway();
      return true;
    }
    _switchToTable(selected);
    return true;
  }

  void _switchToTable(String tableNo) {
    final key = CafeTerminalSession.keyFor(
      orderType: CafeOrderType.dineIn,
      tableNo: tableNo,
    );
    final existing = _sessions[key];
    final session = existing ??
        CafeTerminalSession(
          orderType: CafeOrderType.dineIn,
          tableNo: tableNo,
        );
    setState(() => _activateSession(session));
    _persistSessions();
  }

  void _switchToTakeaway() {
    const key = 'takeaway';
    final existing = _sessions[key];
    final session = existing ??
        CafeTerminalSession(orderType: CafeOrderType.takeaway);
    setState(() => _activateSession(session));
    _persistSessions();
  }

  Future<void> _onOrderTypeChanged(CafeOrderType type) async {
    if (type == CafeOrderType.takeaway) {
      _switchToTakeaway();
      return;
    }
    await _pickTable();
  }

  void _selectOpenTab(CafeTerminalSession session) {
    setState(() => _activateSession(session));
    _persistSessions();
  }

  Future<void> _addItem(CafeMenuItem item) async {
    final ok = await _ensureOrderingSession();
    if (!ok || !mounted) return;
    final cart = _session?.lines;
    if (cart == null) return;
    setState(() {
      final existing = cart.where((l) => l.menuItem.id == item.id);
      if (existing.isNotEmpty) {
        existing.first.quantity += 1;
      } else {
        cart.add(CafeCartLine(menuItem: item));
      }
    });
    await _persistSessions();
  }

  Future<void> _removeOne(CafeMenuItem item) async {
    final cart = _session?.lines;
    if (cart == null) return;
    setState(() {
      CafeCartLine? line;
      for (final l in cart) {
        if (l.menuItem.id == item.id) {
          line = l;
          break;
        }
      }
      if (line == null) return;
      line.quantity -= 1;
      if (line.quantity <= 0) cart.remove(line);
    });
    await _persistSessions();
  }

  Future<void> _setQty(CafeCartLine line, int qty) async {
    final cart = _session?.lines;
    if (cart == null) return;
    setState(() {
      if (qty <= 0) {
        cart.remove(line);
      } else {
        line.quantity = qty.toDouble();
      }
    });
    await _persistSessions();
  }

  Future<void> _clearActiveCart() async {
    final s = _session;
    if (s == null) return;
    setState(() {
      s.lines.clear();
      s.couponId = null;
      s.couponCode = '';
      _couponCode.clear();
      if (s.orderType == CafeOrderType.takeaway) {
        _sessions.remove(s.storageKey);
        _activeKey = null;
      }
    });
    await _persistSessions();
  }

  double get _subtotal =>
      _cart.fold<double>(0, (s, l) => s + l.lineTotal);

  double get _tax => _cart.fold<double>(
        0,
        (s, l) => s + l.lineTotal * (l.menuItem.taxRate / 100),
      );

  double get _discount {
    final c = _coupon;
    if (c == null) return 0;
    return c.discountFor(subtotal: _subtotal, tax: _tax);
  }

  double get _total =>
      (_subtotal + _tax - _discount).clamp(0.0, double.infinity);

  void _clearCoupon() {
    final s = _session;
    setState(() {
      if (s != null) {
        s.couponId = null;
        s.couponCode = '';
      }
      _couponCode.clear();
    });
    _persistSessions();
  }

  Future<void> _applyCoupon() async {
    final code = _couponCode.text.trim();
    if (code.isEmpty || _applyingCoupon) return;
    if (_cart.isEmpty) {
      await showAppMessageDialog(
        context,
        title: 'Coupon',
        message: 'Add items before applying a coupon.',
      );
      return;
    }
    setState(() => _applyingCoupon = true);
    final result = await sl<LookupCafeCoupon>()(
      cafeId: widget.cafeId,
      code: code,
    );
    if (!mounted) return;
    setState(() => _applyingCoupon = false);
    await result.fold(
      (f) async {
        await showAppMessageDialog(
          context,
          title: 'Coupon',
          message: f.message,
        );
      },
      (coupon) async {
        if (coupon == null) {
          await showAppMessageDialog(
            context,
            title: 'Coupon',
            message: 'Coupon code not found.',
          );
          return;
        }
        await _applyCouponEntity(coupon);
      },
    );
  }

  int _qtyInCart(CafeMenuItem item) {
    for (final line in _cart) {
      if (line.menuItem.id == item.id) return line.quantity.round();
    }
    return 0;
  }

  List<CafeMenuItem> get _visible {
    var list = _items;
    if (_categoryFilter != null) {
      list = list.where((i) => i.categoryId == _categoryFilter).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (i) =>
                i.name.toLowerCase().contains(q) ||
                i.categoryName.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty || _busy) return;
    final session = _session;
    if (session == null) return;
    if (session.orderType == CafeOrderType.dineIn &&
        session.tableNo.trim().isEmpty) {
      final picked = await _pickTable();
      if (!picked || !mounted) return;
      if (_session?.tableNo.trim().isEmpty ?? true) return;
    }
    final method = await showModalBottomSheet<CafePaymentMethod>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                title: Text(
                  'Charge ${MoneyFormat.format(_total)}',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                subtitle: const Text('Choose a payment method'),
              ),
              for (final m in CafePaymentMethod.values)
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.highlight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      switch (m) {
                        CafePaymentMethod.cash => Icons.payments_outlined,
                        CafePaymentMethod.upi => Icons.qr_code_2_outlined,
                        CafePaymentMethod.card => Icons.credit_card_outlined,
                      },
                      size: 20,
                      color: AppColors.highlight,
                    ),
                  ),
                  title: Text(m.label),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => Navigator.pop(ctx, m),
                ),
            ],
          ),
        ),
      ),
    );
    if (method == null || !mounted) return;

    // Re-validate coupon against current cart before charging.
    final applied = _coupon;
    if (applied != null) {
      final err = applied.validationError(subtotal: _subtotal);
      if (err != null) {
        await showAppMessageDialog(context, title: 'Coupon', message: err);
        _clearCoupon();
        return;
      }
    }

    final settleSession = _session!;
    final settleKey = settleSession.storageKey;
    setState(() => _busy = true);
    final created = await sl<CreateCafeOrder>()(
      cafeId: widget.cafeId,
      orderType: settleSession.orderType,
      lines: List.of(settleSession.lines),
      discountAmount: _discount,
      couponId: applied?.id,
      couponCode: applied?.code ?? '',
      tableNo: settleSession.tableNo,
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
            setState(() {
              _sessions.remove(settleKey);
              if (_activeKey == settleKey) _activeKey = null;
              _couponCode.clear();
            });
            await _persistSessions();
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
        backgroundColor: AppColors.background,
        title: Text('Order ${order.orderNo}'),
        content: Text(
          [
            if (order.tableNo.trim().isNotEmpty)
              'Table ${order.tableNo.trim()}.',
            'Paid ${MoneyFormat.format(order.totalAmount)}.',
            'Kitchen has the ticket.',
          ].join(' '),
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

  Future<void> _openMobileCart() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            void sync(VoidCallback fn) {
              setState(fn);
              setSheet(() {});
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.72,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return _OrderPanel(
                  title: _orderTitle,
                  tableNo: _tableNo,
                  cart: _cart,
                  orderType: _orderType,
                  subtotal: _subtotal,
                  tax: _tax,
                  discount: _discount,
                  total: _total,
                  busy: _busy,
                  cafe: _cafe,
                  coupon: _coupon,
                  couponCode: _couponCode,
                  applyingCoupon: _applyingCoupon,
                  hasSavedCoupons: _coupons.isNotEmpty,
                  scrollController: scrollController,
                  onOrderType: (t) async {
                    await _onOrderTypeChanged(t);
                    setSheet(() {});
                  },
                  onPickTable: () async {
                    await _pickTable();
                    setSheet(() {});
                  },
                  onClear: () async {
                    await _clearActiveCart();
                    setSheet(() {});
                  },
                  onQty: (line, qty) async {
                    await _setQty(line, qty);
                    setSheet(() {});
                  },
                  onRemove: (line) async {
                    sync(() => _session?.lines.remove(line));
                    await _persistSessions();
                  },
                  onEditNotes: (line) async {
                    await _editLineNotes(line);
                    setSheet(() {});
                  },
                  onApplyCoupon: () async {
                    await _applyCoupon();
                    setSheet(() {});
                  },
                  onPickCoupon: () async {
                    await _pickCoupon();
                    setSheet(() {});
                  },
                  onClearCoupon: () {
                    sync(_clearCoupon);
                  },
                  onPay: () {
                    Navigator.pop(ctx);
                    _checkout();
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (!AppAccess.canRunCafeTerminal(user, widget.cafeId)) {
      return const CafePosBackdrop(
        child: Center(child: Text('Terminal access denied.')),
      );
    }
    final isDesktop = Breakpoints.isDesktop(context);
    if (_loading) {
      return const CafePosBackdrop(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.text),
        ),
      );
    }
    if (_error != null) {
      return CafePosBackdrop(
        child: CafePosEmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Couldn’t load menu',
          message: _error!,
          action: AppButton(label: 'Retry', expand: false, onPressed: _reload),
        ),
      );
    }

    final openTabs = _openTabs;
    final catalog = _CatalogPane(
      categories: _categories,
      categoryFilter: _categoryFilter,
      query: _query,
      items: _visible,
      qtyFor: _qtyInCart,
      openTabs: openTabs,
      activeKey: _activeKey,
      onSelectTab: _selectOpenTab,
      onNewTable: _pickTable,
      onClearTables: _clearAllTables,
      onCategory: (id) => setState(() => _categoryFilter = id),
      onQuery: (q) => setState(() => _query = q),
      onAdd: _addItem,
      onRemove: _removeOne,
    );

    if (isDesktop) {
      return CafePosBackdrop(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                child: catalog,
              ),
            ),
            Container(
              width: 360,
              margin: const EdgeInsets.fromLTRB(0, 12, 16, 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(CafePosSpace.radius),
                border: Border.all(color: AppColors.border),
              ),
              child: _OrderPanel(
                title: _orderTitle,
                tableNo: _tableNo,
                cart: _cart,
                orderType: _orderType,
                subtotal: _subtotal,
                tax: _tax,
                discount: _discount,
                total: _total,
                busy: _busy,
                cafe: _cafe,
                coupon: _coupon,
                couponCode: _couponCode,
                applyingCoupon: _applyingCoupon,
                hasSavedCoupons: _coupons.isNotEmpty,
                onOrderType: _onOrderTypeChanged,
                onPickTable: _pickTable,
                onClear: _clearActiveCart,
                onQty: _setQty,
                onRemove: (line) async {
                  setState(() => _session?.lines.remove(line));
                  await _persistSessions();
                },
                onEditNotes: _editLineNotes,
                onApplyCoupon: _applyCoupon,
                onPickCoupon: _pickCoupon,
                onClearCoupon: _clearCoupon,
                onPay: _checkout,
              ),
            ),
          ],
        ),
      );
    }

    final cartCount =
        _cart.fold<int>(0, (s, l) => s + l.quantity.round());

    return CafePosBackdrop(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: catalog,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Material(
                color: AppColors.text,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () async {
                    if (_session == null) {
                      final ok = await _pickTable();
                      if (!ok || !mounted) return;
                    }
                    await _openMobileCart();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$cartCount',
                            style: const TextStyle(
                              color: AppColors.background,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _orderTitle,
                            style: const TextStyle(
                              color: AppColors.background,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          MoneyFormat.format(_total),
                          style: const TextStyle(
                            color: AppColors.background,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.background,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogPane extends StatelessWidget {
  const _CatalogPane({
    required this.categories,
    required this.categoryFilter,
    required this.query,
    required this.items,
    required this.qtyFor,
    required this.openTabs,
    required this.activeKey,
    required this.onSelectTab,
    required this.onNewTable,
    required this.onClearTables,
    required this.onCategory,
    required this.onQuery,
    required this.onAdd,
    required this.onRemove,
  });

  final List<CafeCategory> categories;
  final String? categoryFilter;
  final String query;
  final List<CafeMenuItem> items;
  final int Function(CafeMenuItem) qtyFor;
  final List<CafeTerminalSession> openTabs;
  final String? activeKey;
  final ValueChanged<CafeTerminalSession> onSelectTab;
  final Future<void> Function() onNewTable;
  final Future<void> Function() onClearTables;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String> onQuery;
  final ValueChanged<CafeMenuItem> onAdd;
  final ValueChanged<CafeMenuItem> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OpenTabsDropdown(
          tabs: openTabs,
          activeKey: activeKey,
          onSelect: onSelectTab,
          onPickTable: onNewTable,
          onClearTables: onClearTables,
        ),
        const SizedBox(height: 12),
        CafePosCategoryBar(
          categories: categories,
          selectedId: categoryFilter,
          onSelected: onCategory,
        ),
        const SizedBox(height: 12),
        AppListSearchField(
          hintText: 'Search menu items…',
          onChanged: onQuery,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: CafePosProductGrid(
            items: items,
            onAdd: onAdd,
            onRemove: onRemove,
            qtyFor: qtyFor,
            empty: CafePosEmptyState(
              icon: Icons.restaurant_menu_outlined,
              title: items.isEmpty && query.isEmpty && categoryFilter == null
                  ? 'No items available'
                  : 'No matches',
              message: items.isEmpty && query.isEmpty && categoryFilter == null
                  ? 'Add menu items before taking orders.'
                  : 'Try another search or category.',
            ),
          ),
        ),
      ],
    );
  }
}

class _OpenTabsDropdown extends StatelessWidget {
  const _OpenTabsDropdown({
    required this.tabs,
    required this.activeKey,
    required this.onSelect,
    required this.onPickTable,
    required this.onClearTables,
  });

  final List<CafeTerminalSession> tabs;
  final String? activeKey;
  final ValueChanged<CafeTerminalSession> onSelect;
  final Future<void> Function() onPickTable;
  final Future<void> Function() onClearTables;

  static const _pickKey = '__pick__';
  static const _clearKey = '__clear__';

  @override
  Widget build(BuildContext context) {
    final options = <AppFilterOption<String>>[
      for (final tab in tabs)
        AppFilterOption(
          value: tab.storageKey,
          label: tab.itemCount > 0
              ? '${tab.label} (${tab.itemCount})'
              : tab.label,
        ),
      const AppFilterOption(value: _pickKey, label: 'Choose table…'),
      if (tabs.isNotEmpty)
        const AppFilterOption(value: _clearKey, label: 'Clear all tables…'),
    ];
    final hasActive = tabs.any((t) => t.storageKey == activeKey);
    final value = hasActive ? activeKey! : _pickKey;

    return SizedBox(
      width: double.infinity,
      child: AppFilterDropdown<String>(
        value: value,
        options: options,
        onChanged: (key) async {
          if (key == _pickKey) {
            await onPickTable();
            return;
          }
          if (key == _clearKey) {
            await onClearTables();
            return;
          }
          for (final tab in tabs) {
            if (tab.storageKey == key) {
              onSelect(tab);
              return;
            }
          }
        },
      ),
    );
  }
}

class _OrderPanel extends StatelessWidget {
  const _OrderPanel({
    required this.title,
    required this.tableNo,
    required this.cart,
    required this.orderType,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    required this.busy,
    required this.cafe,
    required this.coupon,
    required this.couponCode,
    required this.applyingCoupon,
    required this.hasSavedCoupons,
    required this.onOrderType,
    required this.onPickTable,
    required this.onClear,
    required this.onQty,
    required this.onRemove,
    required this.onEditNotes,
    required this.onApplyCoupon,
    required this.onPickCoupon,
    required this.onClearCoupon,
    required this.onPay,
    this.scrollController,
  });

  final String title;
  final String tableNo;
  final List<CafeCartLine> cart;
  final CafeOrderType orderType;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final bool busy;
  final Cafe? cafe;
  final CafeCoupon? coupon;
  final TextEditingController couponCode;
  final bool applyingCoupon;
  final bool hasSavedCoupons;
  final ValueChanged<CafeOrderType> onOrderType;
  final Future<void> Function() onPickTable;
  final Future<void> Function() onClear;
  final void Function(CafeCartLine line, int qty) onQty;
  final ValueChanged<CafeCartLine> onRemove;
  final Future<void> Function(CafeCartLine line) onEditNotes;
  final Future<void> Function() onApplyCoupon;
  final Future<void> Function() onPickCoupon;
  final VoidCallback onClearCoupon;
  final VoidCallback onPay;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                ),
              ),
              if (cart.isNotEmpty)
                IconButton(
                  tooltip: 'Clear tab',
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppColors.textLight,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<CafeOrderType>(
            segments: [
              for (final t in CafeOrderType.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {orderType},
            onSelectionChanged: (s) => onOrderType(s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.highlight.withValues(alpha: 0.14);
                }
                return AppColors.background;
              }),
            ),
          ),
        ),
        if (orderType == CafeOrderType.dineIn) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: onPickTable,
              icon: const Icon(Icons.table_restaurant_outlined, size: 18),
              label: Text(
                tableNo.isEmpty ? 'Select table' : 'Table $tableNo',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size(0, 40),
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      orderType == CafeOrderType.dineIn && tableNo.isEmpty
                          ? 'Select a table, then tap items'
                          : 'Tap items to add',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textLight,
                            fontSize: 13,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  itemCount: cart.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final line = cart[index];
                    return _CartRow(
                      line: line,
                      onQty: (q) => onQty(line, q),
                      onRemove: () => onRemove(line),
                      onEditNotes: () => onEditNotes(line),
                    );
                  },
                ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              if (coupon == null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Coupon code',
                        controller: couponCode,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => onApplyCoupon(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: kAppButtonHeight,
                      child: OutlinedButton(
                        onPressed: cart.isEmpty || applyingCoupon
                            ? null
                            : () => onApplyCoupon(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: const BorderSide(color: AppColors.border),
                          minimumSize: const Size(72, kAppButtonHeight),
                          maximumSize:
                              const Size(120, kAppButtonHeight),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: applyingCoupon
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.text,
                                ),
                              )
                            : const Text(
                                'Apply',
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                  ],
                ),
                if (hasSavedCoupons) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: cart.isEmpty ? null : () => onPickCoupon(),
                      icon: Icon(
                        Icons.local_offer_outlined,
                        size: 16,
                        color: AppColors.highlight,
                      ),
                      label: Text(
                        'Choose from available coupons',
                        style: TextStyle(
                          color: AppColors.highlight,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ] else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_offer_outlined,
                        size: 18,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${coupon!.code} applied',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppColors.success,
                                  ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove coupon',
                        onPressed: onClearCoupon,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: AppColors.textLight,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _totalRow(context, 'Subtotal', MoneyFormat.format(subtotal)),
              ..._gstRows(context),
              if (discount > 0)
                _totalRow(
                  context,
                  'Discount',
                  '- ${MoneyFormat.format(discount)}',
                  valueColor: AppColors.success,
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    MoneyFormat.format(total),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: cart.isEmpty || busy ? null : onPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.highlight,
                    foregroundColor: AppColors.background,
                    disabledBackgroundColor:
                        AppColors.textLight.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Charge ${MoneyFormat.format(total)}'),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _gstRows(BuildContext context) {
    final show = cafe?.showGstOnBill ?? true;
    if (!show) return const [];
    final split = cafe?.gstSplitHalves ?? false;
    final label = (cafe?.gstLabel.trim().isNotEmpty ?? false)
        ? cafe!.gstLabel.trim()
        : 'GST';
    if (split) {
      final half = tax / 2;
      return [
        _totalRow(context, 'CGST', MoneyFormat.format(half)),
        _totalRow(context, 'SGST', MoneyFormat.format(half)),
      ];
    }
    return [
      _totalRow(context, label, MoneyFormat.format(tax)),
    ];
  }

  Widget _totalRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                  fontSize: 13,
                ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.line,
    required this.onQty,
    required this.onRemove,
    required this.onEditNotes,
  });

  final CafeCartLine line;
  final ValueChanged<int> onQty;
  final VoidCallback onRemove;
  final VoidCallback onEditNotes;

  @override
  Widget build(BuildContext context) {
    final hasNotes = line.notes.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CafePosProductThumb(name: line.menuItem.name, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.menuItem.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      MoneyFormat.format(line.lineTotal),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.highlight,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              CafePosQtyStepper(
                quantity: line.quantity.round(),
                onChanged: onQty,
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AppColors.error,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: onEditNotes,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                children: [
                  Icon(
                    hasNotes
                        ? Icons.sticky_note_2_outlined
                        : Icons.note_add_outlined,
                    size: 16,
                    color: hasNotes ? AppColors.highlight : AppColors.textLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hasNotes ? line.notes : 'Add instruction…',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: hasNotes
                                ? AppColors.text
                                : AppColors.textLight,
                            fontStyle:
                                hasNotes ? FontStyle.normal : FontStyle.italic,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
