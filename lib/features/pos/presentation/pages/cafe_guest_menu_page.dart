import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../data/cafe_guest_menu_api.dart';
import '../../domain/entities/cafe_entities.dart';
import '../guest/cafe_guest_detailed_menu.dart';
const _kInk = Color(0xFF141210);
const _kMuted = Color(0xFF6B7280);
const _kSoft = Color(0xFF8B8B86);
const _kLine = Color(0xFFE8E8E4);
const _kBg = Color(0xFFFAFBFA);

/// Public customer menu — mobile-first QR experience (`/m/:cafeId`).
class CafeGuestMenuPage extends StatefulWidget {
  const CafeGuestMenuPage({
    super.key,
    required this.cafeId,
    this.tableNo = '',
  });

  final String cafeId;
  final String tableNo;

  @override
  State<CafeGuestMenuPage> createState() => _CafeGuestMenuPageState();
}

class _CafeGuestMenuPageState extends State<CafeGuestMenuPage> {
  GuestCafeMenu? _menu;
  String? _error;
  bool _loading = true;
  bool _placing = false;
  final List<CafeCartLine> _cart = [];
  late final TextEditingController _searchCtrl;
  GuestOrderResult? _placed;

  String _splashName = '';
  String? _splashLogoUrl;
  bool _splashShowLogo = true;

  String get _tableNo => widget.tableNo.trim();

  String get _cacheNameKey => 'guest_splash_name_${widget.cafeId}';
  String get _cacheLogoKey => 'guest_splash_logo_${widget.cafeId}';
  String get _cacheShowLogoKey => 'guest_splash_show_logo_${widget.cafeId}';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _restoreSplash();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreSplash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_cacheNameKey) ?? '';
      final logo = prefs.getString(_cacheLogoKey);
      final showLogo = prefs.getBool(_cacheShowLogoKey) ?? true;
      if (!mounted) return;
      setState(() {
        _splashName = name;
        _splashLogoUrl = (logo == null || logo.isEmpty) ? null : logo;
        _splashShowLogo = showLogo;
      });
    } catch (_) {
      // Splash cache is best-effort — never block the menu.
    }
  }

  Future<void> _persistSplash(GuestCafeMenu menu) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheNameKey, menu.cafeName.trim());
      final url = menu.brand.logoUrl?.trim() ?? '';
      if (url.isEmpty) {
        await prefs.remove(_cacheLogoKey);
      } else {
        await prefs.setString(_cacheLogoKey, url);
      }
      await prefs.setBool(_cacheShowLogoKey, menu.brand.showLogo);
    } catch (_) {
      // Ignore cache write failures.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final menu = await sl<CafeGuestMenuApi>().fetchMenu(widget.cafeId);
      if (!mounted) return;
      await _persistSplash(menu);
      if (!mounted) return;
      setState(() {
        _menu = menu;
        _splashName = menu.cafeName.trim();
        _splashLogoUrl = menu.brand.logoUrl;
        _splashShowLogo = menu.brand.showLogo;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  CafeCartLine? _findLine(
    CafeMenuItem item, {
    required List<CafeMenuAddon> addons,
    required String notes,
  }) {
    for (final l in _cart) {
      if (l.matches(item, addons) && l.notes.trim() == notes.trim()) {
        return l;
      }
    }
    return null;
  }

  int _qtyForConfig(
    CafeMenuItem item, {
    required List<CafeMenuAddon> addons,
    required String notes,
  }) {
    return _findLine(item, addons: addons, notes: notes)?.quantity.round() ?? 0;
  }

  void _bump(
    CafeMenuItem item, {
    required List<CafeMenuAddon> addons,
    required String notes,
    required int delta,
  }) {
    HapticFeedback.selectionClick();
    setState(() {
      final existing = _findLine(item, addons: addons, notes: notes);
      if (existing != null) {
        existing.quantity += delta;
        if (existing.quantity <= 0) _cart.remove(existing);
      } else if (delta > 0) {
        _cart.add(
          CafeCartLine(
            menuItem: item,
            quantity: delta.toDouble(),
            notes: notes.trim(),
            addons: addons,
          ),
        );
      }
    });
  }

  void _bumpLine(CafeCartLine line, int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      line.quantity += delta;
      if (line.quantity <= 0) _cart.remove(line);
    });
  }

  double get _subtotal => _cart.fold<double>(0, (s, l) => s + l.lineTotal);

  Future<void> _placeOrder() async {
    if (_cart.isEmpty || _placing) return;
    setState(() => _placing = true);
    try {
      final result = await sl<CafeGuestMenuApi>().placeOrder(
        cafeId: widget.cafeId,
        lines: List.of(_cart),
        tableNo: _tableNo,
        orderType: CafeOrderType.dineIn,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _placing = false;
        _placed = result;
        _cart.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.text,
        ),
      );
    }
  }

  Future<void> _openCart() async {
    const accent = DetailedMenuColors.green;
    final initial = (0.4 + _cart.length * 0.07).clamp(0.48, 0.9);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
              initialChildSize: initial,
              minChildSize: 0.4,
              maxChildSize: 0.94,
              builder: (_, scroll) {
                return _GuestCartSheet(
                  cart: _cart,
                  tableNo: _tableNo,
                  subtotal: _subtotal,
                  placing: _placing,
                  accent: accent,
                  scrollController: scroll,
                  onBumpLine: (line, delta) =>
                      sync(() => _bumpLine(line, delta)),
                  onPlace: () async {
                    Navigator.pop(ctx);
                    await _placeOrder();
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _phoneShell({required Color bg, required Widget child}) {
    return Scaffold(
      backgroundColor: bg,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: child,
        ),
      ),
    );
  }

  Widget _brandSplash({
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    final showLogo = _splashShowLogo && (_splashLogoUrl?.isNotEmpty ?? false);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _kLine),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: showLogo
                  ? Image.network(
                      _splashLogoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.storefront_rounded,
                        size: 40,
                        color: _kMuted,
                      ),
                    )
                  : const Icon(
                      Icons.storefront_rounded,
                      size: 40,
                      color: _kMuted,
                    ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kInk,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.4,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kMuted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(height: 24),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = DetailedMenuColors.green;

    if (_placed != null) {
      return _phoneShell(
        bg: _kBg,
        child: _OrderPlacedView(
          result: _placed!,
          accent: accent,
          onNewOrder: () => setState(() => _placed = null),
        ),
      );
    }

    if (_loading) {
      final name = _splashName.trim().isEmpty ? 'Loading menu…' : _splashName;
      return _phoneShell(
        bg: _kBg,
        child: _brandSplash(
          title: name,
          subtitle: _splashName.trim().isEmpty ? null : 'Loading menu…',
          trailing: const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: DetailedMenuColors.green,
            ),
          ),
        ),
      );
    }

    if (_error != null || _menu == null) {
      return _phoneShell(
        bg: _kBg,
        child: _brandSplash(
          title: _splashName.trim().isEmpty ? 'Menu unavailable' : _splashName,
          subtitle: _error ?? 'Unknown error',
          trailing: FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(160, 48),
            ),
            child: const Text('Try again'),
          ),
        ),
      );
    }

    final menu = _menu!;
    if (menu.cafeName.trim().isEmpty) {
      return _phoneShell(
        bg: _kBg,
        child: _brandSplash(
          title: 'Add a cafe name',
          subtitle:
              'Open Cafe POS → Guest menu look and save a cafe name, then refresh.',
          trailing: FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(160, 48),
            ),
            child: const Text('Refresh'),
          ),
        ),
      );
    }

    return _phoneShell(
      bg: DetailedMenuColors.bg,
      child: CafeGuestDetailedMenu(
        cafeName: menu.cafeName,
        tableNo: _tableNo,
        categories: menu.categories,
        items: menu.items,
        cart: _cart,
        qtyForConfig: _qtyForConfig,
        onBump: _bump,
        onOpenCart: _openCart,
        searchController: _searchCtrl,
        onSearch: (_) => setState(() {}),
        showSearch: menu.brand.showSearch,
      ),
    );
  }
}

class _GuestCartSheet extends StatelessWidget {
  const _GuestCartSheet({
    required this.cart,
    required this.tableNo,
    required this.subtotal,
    required this.placing,
    required this.accent,
    required this.scrollController,
    required this.onBumpLine,
    required this.onPlace,
  });

  final List<CafeCartLine> cart;
  final String tableNo;
  final double subtotal;
  final bool placing;
  final Color accent;
  final ScrollController scrollController;
  final void Function(CafeCartLine line, int delta) onBumpLine;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: _kLine,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Your order',
                  style: TextStyle(
                    color: _kInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (tableNo.isNotEmpty)
                Text(
                  'Table $tableNo',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: cart.isEmpty
              ? const Center(
                  child: Text(
                    'Cart is empty',
                    style: TextStyle(
                      color: _kMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  itemCount: cart.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final line = cart[i];
                    final note = line.notes.trim();
                    return Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      decoration: BoxDecoration(
                        color: _kBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kLine),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.displayName,
                                  style: const TextStyle(
                                    color: _kInk,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                if (note.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    note,
                                    style: const TextStyle(
                                      color: _kMuted,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => onBumpLine(line, -1),
                            icon: Icon(Icons.remove_rounded, color: accent),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              '${line.quantity.round()}',
                              style: const TextStyle(
                                color: _kInk,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => onBumpLine(line, 1),
                            icon: Icon(Icons.add_rounded, color: accent),
                          ),
                          SizedBox(
                            width: 72,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                MoneyFormat.format(line.lineTotal),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: _kInk,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'Subtotal',
                    style: TextStyle(color: _kMuted, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    MoneyFormat.format(subtotal),
                    style: const TextStyle(
                      color: _kInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pay at the counter when you’re ready. Kitchen gets this now.',
                style: TextStyle(color: _kSoft, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: placing || cart.isEmpty ? null : onPlace,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: accent.withValues(alpha: 0.35),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                child: Text(placing ? 'Sending…' : 'Send to kitchen'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderPlacedView extends StatefulWidget {
  const _OrderPlacedView({
    required this.result,
    required this.accent,
    required this.onNewOrder,
  });

  final GuestOrderResult result;
  final Color accent;
  final VoidCallback onNewOrder;

  @override
  State<_OrderPlacedView> createState() => _OrderPlacedViewState();
}

class _OrderPlacedViewState extends State<_OrderPlacedView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final accent = widget.accent;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            ScaleTransition(
              scale: CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
              child: Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.14),
                  border: Border.all(color: accent, width: 2),
                ),
                child: Icon(Icons.check_rounded, size: 44, color: accent),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Order sent',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _kInk,
                fontWeight: FontWeight.w800,
                fontSize: 32,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              [
                r.orderNo,
                if (r.tableNo.trim().isNotEmpty) 'Table ${r.tableNo.trim()}',
              ].join(' · '),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Kitchen’s on it. Pay ${MoneyFormat.format(r.totalAmount)} at the counter.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kMuted,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: widget.onNewOrder,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              child: const Text('Order more'),
            ),
          ],
        ),
      ),
    );
  }
}
