import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_filter_dropdown.dart';
import '../../../../injection_container.dart';
import '../../data/cafe_guest_menu_api.dart';
import '../../domain/entities/cafe_entities.dart';
import '../guest/guest_menu_theme.dart';

String _guestItemInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''))
      .where((w) => w.isNotEmpty && !RegExp(r'^\d+$').hasMatch(w))
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final s = words.first;
    return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
  }
  return '${words[0][0]}${words[1][0]}'.toUpperCase();
}

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

class _CafeGuestMenuPageState extends State<CafeGuestMenuPage>
    with TickerProviderStateMixin {
  GuestCafeMenu? _menu;
  String? _error;
  bool _loading = true;
  bool _placing = false;
  String? _categoryId;
  String _search = '';
  final List<CafeCartLine> _cart = [];
  late final AnimationController _heroPulse;
  late final AnimationController _cartBounce;
  late final TextEditingController _searchCtrl;
  GuestOrderResult? _placed;

  String get _tableNo => widget.tableNo.trim();

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _heroPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);
    _cartBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _heroPulse.dispose();
    _cartBounce.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final menu = await sl<CafeGuestMenuApi>().fetchMenu(widget.cafeId);
      if (!mounted) return;
      setState(() {
        _menu = menu;
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

  int _qty(CafeMenuItem item) {
    for (final l in _cart) {
      if (l.menuItem.id == item.id) return l.quantity.round();
    }
    return 0;
  }

  void _add(CafeMenuItem item) {
    HapticFeedback.selectionClick();
    setState(() {
      final existing = _cart.where((l) => l.menuItem.id == item.id);
      if (existing.isNotEmpty) {
        existing.first.quantity += 1;
      } else {
        _cart.add(CafeCartLine(menuItem: item));
      }
    });
    _cartBounce
      ..reset()
      ..forward();
  }

  void _remove(CafeMenuItem item) {
    HapticFeedback.selectionClick();
    setState(() {
      CafeCartLine? line;
      for (final l in _cart) {
        if (l.menuItem.id == item.id) {
          line = l;
          break;
        }
      }
      if (line == null) return;
      line.quantity -= 1;
      if (line.quantity <= 0) _cart.remove(line);
    });
  }

  double get _subtotal =>
      _cart.fold<double>(0, (s, l) => s + l.lineTotal);

  int get _count =>
      _cart.fold<int>(0, (s, l) => s + l.quantity.round());

  List<CafeMenuItem> get _visible {
    final menu = _menu;
    if (menu == null) return const [];
    var list = menu.items;
    final catId = _categoryId?.trim();
    if (catId != null && catId.isNotEmpty) {
      list = list.where((i) => i.categoryId.trim() == catId).toList();
    }
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((i) => i.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  void _selectCategory(String? id) {
    HapticFeedback.selectionClick();
    setState(() => _categoryId = id);
  }

  GuestMenuTheme get _theme =>
      GuestMenuTheme.fromBrand(_menu?.brand ?? GuestCafeBrand.defaults);

  Future<void> _placeOrder() async {
    if (_cart.isEmpty || _placing) return;
    setState(() => _placing = true);
    try {
      final result = await sl<CafeGuestMenuApi>().placeOrder(
        cafeId: widget.cafeId,
        lines: List.of(_cart),
        tableNo: _tableNo,
        orderType: _tableNo.isEmpty
            ? CafeOrderType.takeaway
            : CafeOrderType.dineIn,
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141210),
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
              initialChildSize: 0.72,
              minChildSize: 0.42,
              maxChildSize: 0.94,
              builder: (_, scroll) {
                return _GuestCartSheet(
                  cart: _cart,
                  tableNo: _tableNo,
                  subtotal: _subtotal,
                  placing: _placing,
                  scrollController: scroll,
                  onAdd: (item) => sync(() => _add(item)),
                  onRemove: (item) => sync(() => _remove(item)),
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 560) {
      return _DesktopGate(
        cafeName: _menu?.cafeName,
        cafeId: widget.cafeId,
        tableNo: _tableNo,
      );
    }

    if (_placed != null) {
      return _OrderPlacedView(
        result: _placed!,
        onNewOrder: () => setState(() => _placed = null),
      );
    }

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF141210),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B4A)),
        ),
      );
    }

    if (_error != null || _menu == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF141210),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    color: Color(0xFFFF6B4A), size: 40),
                const SizedBox(height: 16),
                Text(
                  'Menu unavailable',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFB0A8A0), height: 1.4),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _load,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B4A),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final menu = _menu!;
    final theme = _theme;
    final accent = theme.accent;
    final bg = switch (theme.layout) {
      GuestMenuLayout.night => const Color(0xFFF3F3F1),
      GuestMenuLayout.fresh => const Color(0xFFFafaf8),
      GuestMenuLayout.gallery => const Color(0xFFF5F4F1),
    };

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: switch (theme.layout) {
                  GuestMenuLayout.night => _GuestHero(
                      cafeName: menu.cafeName,
                      tableNo: _tableNo,
                      pulse: _heroPulse,
                      accent: accent,
                      tagline: theme.tagline.isEmpty
                          ? 'Tap what you want. We’ll send it to the kitchen.'
                          : theme.tagline,
                      showLogo: theme.showLogo,
                      logoUrl: theme.logoUrl,
                      style: GuestHeroStyle.night,
                    ),
                  GuestMenuLayout.fresh => _GuestHero(
                      cafeName: menu.cafeName,
                      tableNo: _tableNo,
                      pulse: _heroPulse,
                      accent: accent,
                      tagline: theme.tagline.isEmpty
                          ? 'What are you craving?'
                          : theme.tagline,
                      showLogo: theme.showLogo,
                      logoUrl: theme.logoUrl,
                      style: GuestHeroStyle.fresh,
                    ),
                  GuestMenuLayout.gallery => _GuestHero(
                      cafeName: menu.cafeName,
                      tableNo: _tableNo,
                      pulse: _heroPulse,
                      accent: accent,
                      tagline: theme.tagline.isEmpty
                          ? 'Signature picks, ready when you are.'
                          : theme.tagline,
                      showLogo: theme.showLogo,
                      logoUrl: theme.logoUrl,
                      style: GuestHeroStyle.gallery,
                    ),
                },
              ),
              if (theme.showSearch)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: _GuestSearchField(
                      controller: _searchCtrl,
                      accent: accent,
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                ),
              if (menu.categories.isNotEmpty)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CategoryHeaderDelegate(
                    categories: menu.categories,
                    selectedId: _categoryId,
                    onSelected: _selectCategory,
                    accent: accent,
                    background: bg,
                    chipStyle: theme.layout == GuestMenuLayout.fresh
                        ? GuestChipStyle.accent
                        : GuestChipStyle.ink,
                  ),
                ),
              if (_visible.isEmpty)
                SliverFillRemaining(
                  key: ValueKey('empty-${_categoryId ?? 'all'}-$_search'),
                  hasScrollBody: false,
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Nothing on the menu in this category yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
              else if (theme.layout == GuestMenuLayout.gallery)
                SliverPadding(
                  key: ValueKey('grid-${_categoryId ?? 'all'}-$_search'),
                  padding: EdgeInsets.fromLTRB(
                    14,
                    10,
                    14,
                    _cart.isEmpty ? 32 : 120,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _visible[index];
                        return _GalleryCard(
                          item: item,
                          qty: _qty(item),
                          accent: accent,
                          onAdd: () => _add(item),
                          onRemove: () => _remove(item),
                        );
                      },
                      childCount: _visible.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  key: ValueKey('list-${_categoryId ?? 'all'}-$_search'),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    _cart.isEmpty ? 32 : 120,
                  ),
                  sliver: SliverList.separated(
                    itemCount: _visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _visible[index];
                      final qty = _qty(item);
                      if (theme.layout == GuestMenuLayout.fresh) {
                        return _FreshMenuRow(
                          item: item,
                          qty: qty,
                          accent: accent,
                          onAdd: () => _add(item),
                          onRemove: () => _remove(item),
                        );
                      }
                      return _MenuRow(
                        item: item,
                        qty: qty,
                        accent: accent,
                        onAdd: () => _add(item),
                        onRemove: () => _remove(item),
                      );
                    },
                  ),
                ),
            ],
          ),
          if (_cart.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ScaleTransition(
                    scale: Tween(begin: 0.96, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _cartBounce,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    child: _CartBar(
                      count: _count,
                      total: _subtotal,
                      accent: accent,
                      onTap: _openCart,
                      pill: theme.layout != GuestMenuLayout.night,
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

enum GuestHeroStyle { night, fresh, gallery }

enum GuestChipStyle { ink, accent }

class _GuestHero extends StatelessWidget {
  const _GuestHero({
    required this.cafeName,
    required this.tableNo,
    required this.pulse,
    required this.accent,
    required this.tagline,
    required this.showLogo,
    required this.style,
    this.logoUrl,
  });

  final String cafeName;
  final String tableNo;
  final Animation<double> pulse;
  final Color accent;
  final String tagline;
  final bool showLogo;
  final String? logoUrl;
  final GuestHeroStyle style;

  Widget _logo({required bool onDark, double size = 52}) {
    final url = logoUrl;
    if (!showLogo || url == null || url.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: onDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white,
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.18)
              : const Color(0xFFE2E2DF),
        ),
        boxShadow: onDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF141210).withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.storefront_rounded,
          color: accent,
          size: size * 0.45,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (style == GuestHeroStyle.fresh || style == GuestHeroStyle.gallery) {
      final top = MediaQuery.paddingOf(context).top;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, top + 18, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _logo(onDark: false, size: 48),
                      Text(
                        cafeName,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: const Color(0xFF141210),
                              fontSize: style == GuestHeroStyle.gallery
                                  ? 28
                                  : 26,
                              height: 1.1,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tagline,
                        style: TextStyle(
                          color: const Color(0xFF6B7280),
                          fontSize: style == GuestHeroStyle.gallery ? 16 : 14,
                          height: 1.35,
                          fontWeight: style == GuestHeroStyle.gallery
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (tableNo.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 10, top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'T$tableNo',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            22,
            MediaQuery.paddingOf(context).top + 28,
            22,
            28,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.2 - t * 0.15, -1),
              end: Alignment(1, 1.1),
              colors: [
                const Color(0xFF141210),
                Color.lerp(
                  const Color(0xFF2A221C),
                  accent.withValues(alpha: 0.55),
                  0.18 + t * 0.08,
                )!,
                const Color(0xFF1A1512),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      tableNo.isEmpty ? 'ORDER HERE' : 'TABLE $tableNo',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!(showLogo && (logoUrl?.isNotEmpty ?? false)))
                    Icon(
                      Icons.local_cafe_rounded,
                      color: Colors.white.withValues(alpha: 0.35),
                      size: 22,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _logo(onDark: true, size: 56),
              Text(
                cafeName,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 1.05,
                      fontSize: 36,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                tagline,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CategoryHeaderDelegate({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    required this.accent,
    required this.background,
    this.chipStyle = GuestChipStyle.ink,
  });

  final List<CafeCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final Color accent;
  final Color background;
  final GuestChipStyle chipStyle;

  @override
  double get minExtent => 58;

  @override
  double get maxExtent => 58;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Row + horizontal SingleChildScrollView (not ListView) so chip taps
    // win over the outer CustomScrollView on Flutter web.
    return Material(
      color: background,
      elevation: overlapsContent ? 1.5 : 0,
      shadowColor: const Color(0xFF141210).withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _CatChip(
                label: 'All',
                selected: selectedId == null,
                accent: accent,
                style: chipStyle,
                onTap: () => onSelected(null),
              ),
              const SizedBox(width: 8),
              for (final c in categories) ...[
                _CatChip(
                  label: c.name,
                  selected: selectedId == c.id,
                  accent: accent,
                  style: chipStyle,
                  onTap: () => onSelected(c.id),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) {
    return oldDelegate.selectedId != selectedId ||
        oldDelegate.categories != categories ||
        oldDelegate.chipStyle != chipStyle ||
        oldDelegate.accent != accent ||
        oldDelegate.background != background;
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.style = GuestChipStyle.ink,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final GuestChipStyle style;

  @override
  Widget build(BuildContext context) {
    final fill = !selected
        ? Colors.white
        : style == GuestChipStyle.accent
            ? accent
            : const Color(0xFF141210);
    final border = !selected
        ? const Color(0xFFE2E2DF)
        : style == GuestChipStyle.accent
            ? accent
            : const Color(0xFF141210);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppFilterDropdown.radius),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF2A221C),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.item,
    required this.qty,
    required this.accent,
    required this.onAdd,
    required this.onRemove,
  });

  final CafeMenuItem item;
  final int qty;
  final Color accent;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  String get _initials => _guestItemInitials(item.name);

  @override
  Widget build(BuildContext context) {
    final selected = qty > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? accent.withValues(alpha: 0.55)
              : const Color(0xFFE2E2DF),
          width: selected ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF141210).withValues(alpha: selected ? 0.08 : 0.03),
            blurRadius: selected ? 18 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.22),
                  accent.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: Text(
              _initials,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.2,
                    color: Color(0xFF141210),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  MoneyFormat.format(item.price),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          if (qty == 0)
            _RoundIconButton(
              icon: Icons.add_rounded,
              filled: true,
              accent: accent,
              onTap: onAdd,
            )
          else
            Row(
              children: [
                _RoundIconButton(
                  icon: Icons.remove_rounded,
                  filled: false,
                  accent: accent,
                  onTap: onRemove,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '$qty',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF141210),
                    ),
                  ),
                ),
                _RoundIconButton(
                  icon: Icons.add_rounded,
                  filled: true,
                  accent: accent,
                  onTap: onAdd,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.filled,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final bool filled;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? const Color(0xFF141210) : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: filled ? null : Border.all(color: const Color(0xFFE2E2DF)),
          ),
          child: Icon(
            icon,
            size: 18,
            color: filled ? Colors.white : const Color(0xFF141210),
          ),
        ),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({
    required this.count,
    required this.total,
    required this.accent,
    required this.onTap,
    this.pill = false,
  });

  final int count;
  final double total;
  final Color accent;
  final VoidCallback onTap;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final radius = pill ? 28.0 : 18.0;
    return Material(
      color: pill ? accent : const Color(0xFF141210),
      borderRadius: BorderRadius.circular(radius),
      elevation: 12,
      shadowColor: Colors.black54,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                color: Colors.white.withValues(alpha: 0.9),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'View cart ($count)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                MoneyFormat.format(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
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
    required this.scrollController,
    required this.onAdd,
    required this.onRemove,
    required this.onPlace,
  });

  final List<CafeCartLine> cart;
  final String tableNo;
  final double subtotal;
  final bool placing;
  final ScrollController scrollController;
  final ValueChanged<CafeMenuItem> onAdd;
  final ValueChanged<CafeMenuItem> onRemove;
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
            color: Colors.white24,
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
                    color: Colors.white,
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
                    color: AppColors.highlight,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            itemCount: cart.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final line = cart[i];
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      line.menuItem.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => onRemove(line.menuItem),
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.white54),
                  ),
                  Text(
                    '${line.quantity.round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => onAdd(line.menuItem),
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.white54),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      MoneyFormat.format(line.lineTotal),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    MoneyFormat.format(subtotal),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pay at the counter when you’re ready. Kitchen gets this now.',
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: placing || cart.isEmpty ? null : onPlace,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.highlight,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white24,
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
    required this.onNewOrder,
  });

  final GuestOrderResult result;
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
    return Scaffold(
      backgroundColor: const Color(0xFF141210),
      body: SafeArea(
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
                    color: AppColors.highlight.withValues(alpha: 0.18),
                    border: Border.all(color: AppColors.highlight, width: 2),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 44,
                    color: AppColors.highlight,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Order sent',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
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
                  color: AppColors.highlight,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Kitchen’s on it. Pay ${MoneyFormat.format(r.totalAmount)} at the counter.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB0A8A0),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: widget.onNewOrder,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF141210),
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
      ),
    );
  }
}

class _DesktopGate extends StatelessWidget {
  const _DesktopGate({
    required this.cafeName,
    required this.cafeId,
    required this.tableNo,
  });

  final String? cafeName;
  final String cafeId;
  final String tableNo;

  @override
  Widget build(BuildContext context) {
    final origin = AppConfig.appPublicUrl.isNotEmpty
        ? AppConfig.appPublicUrl
        : Uri.base.origin;
    final url = tableNo.isEmpty
        ? '$origin/m/$cafeId'
        : '$origin/m/$cafeId?t=${Uri.encodeQueryComponent(tableNo)}';

    return Scaffold(
      backgroundColor: const Color(0xFF141210),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: -math.pi / 28,
                  child: const Icon(
                    Icons.smartphone_rounded,
                    size: 56,
                    color: Color(0xFFFF6B4A),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  cafeName ?? 'This menu',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Guest ordering is built for phones. Scan this QR or open the link on mobile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFB0A8A0),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: url,
                    size: 180,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF141210),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF141210),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestSearchField extends StatelessWidget {
  const _GuestSearchField({
    required this.controller,
    required this.accent,
    required this.onChanged,
  });

  final TextEditingController controller;
  final Color accent;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Color(0xFF141210),
      ),
      decoration: InputDecoration(
        hintText: 'Search menu',
        hintStyle: TextStyle(
          color: const Color(0xFF9CA3AF).withValues(alpha: 0.95),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(Icons.search_rounded, color: accent, size: 22),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E2DF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E2DF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 1.4),
        ),
      ),
    );
  }
}

class _FreshMenuRow extends StatelessWidget {
  const _FreshMenuRow({
    required this.item,
    required this.qty,
    required this.accent,
    required this.onAdd,
    required this.onRemove,
  });

  final CafeMenuItem item;
  final int qty;
  final Color accent;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  String get _initials => _guestItemInitials(item.name);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E8E4)),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.28),
                  accent.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: Text(
              _initials,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF141210),
                    height: 1.2,
                  ),
                ),
                if (item.categoryName.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8B8B86),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      MoneyFormat.format(item.price),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF141210),
                      ),
                    ),
                    const Spacer(),
                    _QtyPill(
                      qty: qty,
                      accent: accent,
                      onAdd: onAdd,
                      onRemove: onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyPill extends StatelessWidget {
  const _QtyPill({
    required this.qty,
    required this.accent,
    required this.onAdd,
    required this.onRemove,
  });

  final int qty;
  final Color accent;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (qty == 0) {
      return Material(
        color: accent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              'Add',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: Icon(Icons.remove_rounded, size: 18, color: accent),
          ),
          Text(
            '$qty',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: accent,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onAdd,
            icon: Icon(Icons.add_rounded, size: 18, color: accent),
          ),
        ],
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({
    required this.item,
    required this.qty,
    required this.accent,
    required this.onAdd,
    required this.onRemove,
  });

  final CafeMenuItem item;
  final int qty;
  final Color accent;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  String get _initials => _guestItemInitials(item.name);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAdd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.35),
                          accent.withValues(alpha: 0.08),
                          const Color(0xFFEDEBE6),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _initials,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                          color: accent.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Material(
                      color: accent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onAdd,
                        child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (qty > 0)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141210),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '×$qty',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.15,
                        color: Color(0xFF141210),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            MoneyFormat.format(item.price),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: accent,
                            ),
                          ),
                        ),
                        if (qty > 0)
                          GestureDetector(
                            onTap: onRemove,
                            child: Icon(
                              Icons.remove_circle_outline_rounded,
                              size: 20,
                              color: accent.withValues(alpha: 0.85),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
