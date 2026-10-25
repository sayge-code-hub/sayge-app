import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_filter_dropdown.dart';
import '../../../../injection_container.dart';
import '../../data/cafe_guest_menu_api.dart';
import '../../domain/entities/cafe_entities.dart';
import '../guest/cafe_guest_detailed_menu.dart';
import '../guest/guest_menu_theme.dart';

const _kInk = Color(0xFF141210);
const _kMuted = Color(0xFF6B7280);
const _kSoft = Color(0xFF8B8B86);
const _kLine = Color(0xFFE8E8E4);
const _kBgFresh = Color(0xFFFAFAF8);
const _kBgGallery = Color(0xFFF5F4F1);

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
  late final AnimationController _cartBounce;
  late final TextEditingController _searchCtrl;
  GuestOrderResult? _placed;

  String get _tableNo => widget.tableNo.trim();

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _cartBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
      // Guest QR is always in-cafe — dine-in (table optional on cafe-wide QR).
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

  Map<String, int> get _categoryCounts {
    final menu = _menu;
    if (menu == null) return const {};
    final counts = <String, int>{};
    for (final item in menu.items) {
      final id = item.categoryId;
      if (id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _openCart() async {
    final accent = _theme.accent;
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

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    final accent = theme.accent;
    final isGallery = theme.layout == GuestMenuLayout.gallery;
    final bg = isGallery ? _kBgGallery : _kBgFresh;

    if (_placed != null) {
      return _phoneShell(
        bg: _kBgFresh,
        child: _OrderPlacedView(
          result: _placed!,
          accent: accent,
          onNewOrder: () => setState(() => _placed = null),
        ),
      );
    }

    if (_loading) {
      return _phoneShell(
        bg: _kBgFresh,
        child: const Center(
          child: CircularProgressIndicator(color: _kInk),
        ),
      );
    }

    if (_error != null || _menu == null) {
      return _phoneShell(
        bg: _kBgFresh,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, color: accent, size: 40),
                const SizedBox(height: 16),
                Text(
                  'Menu unavailable',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: _kInk,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _kMuted, height: 1.4),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _load,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(160, 48),
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
    final counts = _categoryCounts;

    if (theme.layout == GuestMenuLayout.detailed) {
      return _phoneShell(
        bg: DetailedMenuColors.bg,
        child: CafeGuestDetailedMenu(
          cafeName: menu.cafeName,
          tableNo: _tableNo,
          categories: menu.categories,
          items: menu.items,
          cart: _cart,
          qtyFor: _qty,
          onAdd: _add,
          onRemove: _remove,
          onOpenCart: _openCart,
          searchController: _searchCtrl,
          onSearch: (v) => setState(() => _search = v),
          accent: accent,
        ),
      );
    }

    return _phoneShell(
      bg: bg,
      child: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _GuestHero(
                  cafeName: menu.cafeName,
                  tableNo: _tableNo,
                  accent: accent,
                  tagline: theme.tagline.isEmpty
                      ? (isGallery
                          ? 'Signature picks, ready when you are.'
                          : 'What are you craving?')
                      : theme.tagline,
                  showLogo: theme.showLogo,
                  logoUrl: theme.logoUrl,
                  style: isGallery
                      ? GuestHeroStyle.gallery
                      : GuestHeroStyle.fresh,
                ),
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
                    counts: counts,
                    selectedId: _categoryId,
                    onSelected: _selectCategory,
                    accent: accent,
                    background: bg,
                    chipStyle: isGallery
                        ? GuestChipStyle.ink
                        : GuestChipStyle.accent,
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
                        'Nothing in this category yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _kMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
              else if (isGallery)
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
                      return _FreshMenuRow(
                        item: item,
                        qty: _qty(item),
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

enum GuestHeroStyle { fresh, gallery }

enum GuestChipStyle { ink, accent }

class _GuestHero extends StatelessWidget {
  const _GuestHero({
    required this.cafeName,
    required this.tableNo,
    required this.accent,
    required this.tagline,
    required this.showLogo,
    required this.style,
    this.logoUrl,
  });

  final String cafeName;
  final String tableNo;
  final Color accent;
  final String tagline;
  final bool showLogo;
  final String? logoUrl;
  final GuestHeroStyle style;

  Widget _logo({double size = 52}) {
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
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E2DF)),
        boxShadow: [
          BoxShadow(
            color: _kInk.withValues(alpha: 0.06),
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
    final top = MediaQuery.paddingOf(context).top;
    final isGallery = style == GuestHeroStyle.gallery;
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
                    _logo(size: 48),
                    Text(
                      cafeName,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: _kInk,
                                fontSize: isGallery ? 28 : 26,
                                height: 1.1,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tagline,
                      style: TextStyle(
                        color: _kMuted,
                        fontSize: isGallery ? 16 : 14,
                        height: 1.35,
                        fontWeight:
                            isGallery ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (tableNo.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 10, top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Table $tableNo',
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
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CategoryHeaderDelegate({
    required this.categories,
    required this.counts,
    required this.selectedId,
    required this.onSelected,
    required this.accent,
    required this.background,
    this.chipStyle = GuestChipStyle.ink,
  });

  final List<CafeCategory> categories;
  final Map<String, int> counts;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final Color accent;
  final Color background;
  final GuestChipStyle chipStyle;

  @override
  double get minExtent => 62;

  @override
  double get maxExtent => 62;

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
      shadowColor: _kInk.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                  count: counts[c.id],
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
        oldDelegate.counts != counts ||
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
    this.count,
    this.style = GuestChipStyle.ink,
  });

  final String label;
  final int? count;
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
            : _kInk;
    final border = !selected
        ? const Color(0xFFE2E2DF)
        : style == GuestChipStyle.accent
            ? accent
            : _kInk;
    final text = selected ? Colors.white : const Color(0xFF2A221C);
    final countLabel = count == null ? null : '$count';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppFilterDropdown.radius),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
            if (countLabel != null) ...[
              const SizedBox(width: 6),
              Text(
                countLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: text.withValues(alpha: selected ? 0.85 : 0.55),
                ),
              ),
            ],
          ],
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
  });

  final int count;
  final double total;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(28),
      elevation: 10,
      shadowColor: accent.withValues(alpha: 0.45),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                color: Colors.white.withValues(alpha: 0.95),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'View cart · $count',
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
    required this.accent,
    required this.scrollController,
    required this.onAdd,
    required this.onRemove,
    required this.onPlace,
  });

  final List<CafeCartLine> cart;
  final String tableNo;
  final double subtotal;
  final bool placing;
  final Color accent;
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
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            itemCount: cart.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final line = cart[i];
              return Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: _kBgFresh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kLine),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.menuItem.name,
                        style: const TextStyle(
                          color: _kInk,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => onRemove(line.menuItem),
                      icon: Icon(Icons.remove_rounded, color: accent),
                    ),
                    Text(
                      '${line.quantity.round()}',
                      style: const TextStyle(
                        color: _kInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    IconButton(
                      onPressed: () => onAdd(line.menuItem),
                      icon: Icon(Icons.add_rounded, color: accent),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        MoneyFormat.format(line.lineTotal),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: _kInk,
                          fontWeight: FontWeight.w700,
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
                child: Icon(
                  Icons.check_rounded,
                  size: 44,
                  color: accent,
                ),
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
        color: _kInk,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        border: Border.all(color: _kLine),
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
                    color: _kInk,
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
                      color: _kSoft,
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
                        color: _kInk,
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
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(22),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            child: Text(
              'Add',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onRemove,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(Icons.remove_rounded, size: 20, color: accent),
          ),
          Text(
            '$qty',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: accent,
            ),
          ),
          IconButton(
            onPressed: onAdd,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(Icons.add_rounded, size: 20, color: accent),
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
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 22,
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
                          color: accent,
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
                        color: _kInk,
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
