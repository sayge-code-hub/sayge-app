import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/cafe_entities.dart';

/// Soft green palette matching the Detailed View reference.
class DetailedMenuColors {
  static const green = Color(0xFF3DDC84);
  static const greenDeep = Color(0xFF2BB673);
  static const ink = Color(0xFF1A1A1A);
  static const muted = Color(0xFF8A8A8A);
  static const soft = Color(0xFFF4F6F5);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE8ECE9);
  static const bg = Color(0xFFFAFBFA);
}

String _initials(String name) {
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

Color _toneFor(String seed) {
  const tones = <Color>[
    Color(0xFFE8F8EF),
    Color(0xFFFFF3E0),
    Color(0xFFE3F2FD),
    Color(0xFFFCE4EC),
    Color(0xFFF3E5F5),
    Color(0xFFE0F7FA),
  ];
  final i = seed.hashCode.abs() % tones.length;
  return tones[i];
}

/// Full guest menu chrome for [GuestMenuLayout.detailed].
class CafeGuestDetailedMenu extends StatefulWidget {
  const CafeGuestDetailedMenu({
    super.key,
    required this.cafeName,
    required this.tableNo,
    required this.categories,
    required this.items,
    required this.cart,
    required this.qtyFor,
    required this.onAdd,
    required this.onRemove,
    required this.onOpenCart,
    required this.searchController,
    required this.onSearch,
    this.accent,
  });

  final String cafeName;
  final String tableNo;
  final List<CafeCategory> categories;
  final List<CafeMenuItem> items;
  final List<CafeCartLine> cart;
  final int Function(CafeMenuItem) qtyFor;
  final ValueChanged<CafeMenuItem> onAdd;
  final ValueChanged<CafeMenuItem> onRemove;
  final VoidCallback onOpenCart;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final Color? accent;

  @override
  State<CafeGuestDetailedMenu> createState() => _CafeGuestDetailedMenuState();
}

class _CafeGuestDetailedMenuState extends State<CafeGuestDetailedMenu> {
  String? _categoryId;
  CafeMenuItem? _detail;
  int _nav = 0;

  Color get _green => widget.accent ?? DetailedMenuColors.green;

  List<CafeMenuItem> get _recommended {
    final list = List<CafeMenuItem>.of(widget.items);
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list.take(6).toList();
  }

  List<CafeMenuItem> get _grid {
    var list = widget.items;
    if (_categoryId != null && _categoryId!.isNotEmpty) {
      list = list.where((i) => i.categoryId == _categoryId).toList();
    }
    final q = widget.searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((i) => i.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  int get _cartCount =>
      widget.cart.fold<int>(0, (s, l) => s + l.quantity.round());

  @override
  Widget build(BuildContext context) {
    if (_detail != null) {
      return _DetailedItemScreen(
        item: _detail!,
        related: widget.items
            .where(
              (i) =>
                  i.categoryId == _detail!.categoryId && i.id != _detail!.id,
            )
            .take(8)
            .toList(),
        green: _green,
        qty: widget.qtyFor(_detail!),
        onBack: () => setState(() => _detail = null),
        onAdd: () {
          widget.onAdd(_detail!);
          HapticFeedback.selectionClick();
          setState(() {});
        },
        onRemove: () {
          widget.onRemove(_detail!);
          HapticFeedback.selectionClick();
          setState(() {});
        },
      );
    }

    return Scaffold(
      backgroundColor: DetailedMenuColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _searchBar()),
                  if (_recommended.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                        child: Text(
                          'Recommended',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: DetailedMenuColors.ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 196,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          scrollDirection: Axis.horizontal,
                          itemCount: _recommended.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 14),
                          itemBuilder: (context, i) {
                            final item = _recommended[i];
                            return _RecommendedCard(
                              item: item,
                              green: _green,
                              onTap: () => setState(() => _detail = item),
                              onHeart: () => widget.onAdd(item),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  if (widget.categories.isNotEmpty)
                    SliverToBoxAdapter(child: _categoryTabs()),
                  if (_grid.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'Nothing here yet.',
                          style: TextStyle(
                            color: DetailedMenuColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        _cartCount > 0 ? 100 : 24,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.78,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = _grid[index];
                            return _PopularCard(
                              item: item,
                              qty: widget.qtyFor(item),
                              green: _green,
                              onTap: () => setState(() => _detail = item),
                              onHeart: () => widget.onAdd(item),
                            );
                          },
                          childCount: _grid.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _bottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    final tip = widget.tableNo.isEmpty
        ? widget.cafeName
        : '${widget.cafeName} · T${widget.tableNo}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: DetailedMenuColors.card,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: widget.searchController,
          onChanged: (v) {
            widget.onSearch(v);
            setState(() {});
          },
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: DetailedMenuColors.ink,
          ),
          decoration: InputDecoration(
            hintText: "What's your pick, $tip?",
            hintStyle: TextStyle(
              color: DetailedMenuColors.muted.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            prefixIcon: Icon(Icons.search_rounded, color: _green, size: 22),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryTabs() {
    final tabs = <({String? id, String label})>[
      (id: null, label: 'Popular'),
      for (final c in widget.categories) (id: c.id, label: c.name),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in tabs)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _categoryId = t.id);
                  },
                  child: Column(
                    children: [
                      Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _categoryId == t.id
                              ? _green
                              : DetailedMenuColors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 3,
                        width: _categoryId == t.id ? 28 : 0,
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(2),
                        ),
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

  Widget _bottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: DetailedMenuColors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navIcon(Icons.home_rounded, 0, onTap: () => setState(() => _nav = 0)),
              _navIcon(
                Icons.qr_code_scanner_rounded,
                1,
                onTap: () => setState(() => _nav = 1),
              ),
              _navIcon(
                Icons.favorite_border_rounded,
                2,
                onTap: () => setState(() => _nav = 2),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _navIcon(
                    Icons.shopping_bag_outlined,
                    3,
                    onTap: () {
                      setState(() => _nav = 3);
                      if (_cartCount > 0) widget.onOpenCart();
                    },
                  ),
                  if (_cartCount > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_cartCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, int index, {required VoidCallback onTap}) {
    final selected = _nav == index;
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: selected ? _green : DetailedMenuColors.muted,
        size: 26,
      ),
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  const _RecommendedCard({
    required this.item,
    required this.green,
    required this.onTap,
    required this.onHeart,
  });

  final CafeMenuItem item;
  final Color green;
  final VoidCallback onTap;
  final VoidCallback onHeart;

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(item.id);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        decoration: BoxDecoration(
          color: DetailedMenuColors.card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: tone),
                  Center(
                    child: Text(
                      _initials(item.name),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: green.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: onHeart,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.favorite_border_rounded,
                          size: 16,
                          color: green,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: DetailedMenuColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.categoryName.trim().isEmpty
                        ? MoneyFormat.format(item.price)
                        : item.categoryName,
                    style: const TextStyle(
                      color: DetailedMenuColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularCard extends StatelessWidget {
  const _PopularCard({
    required this.item,
    required this.qty,
    required this.green,
    required this.onTap,
    required this.onHeart,
  });

  final CafeMenuItem item;
  final int qty;
  final Color green;
  final VoidCallback onTap;
  final VoidCallback onHeart;

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(item.name);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: DetailedMenuColors.card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: tone),
                  Center(
                    child: Text(
                      _initials(item.name),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: green.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_rounded, size: 12, color: green),
                          const SizedBox(width: 4),
                          Text(
                            qty > 0 ? '$qty' : MoneyFormat.format(item.price),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: DetailedMenuColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onHeart,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.favorite_border_rounded,
                          size: 14,
                          color: green,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
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
                        fontSize: 13,
                        height: 1.15,
                        color: DetailedMenuColors.ink,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.categoryName.trim().isEmpty
                          ? MoneyFormat.format(item.price)
                          : '${item.categoryName} · ${MoneyFormat.format(item.price)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: DetailedMenuColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
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

class _DetailedItemScreen extends StatelessWidget {
  const _DetailedItemScreen({
    required this.item,
    required this.related,
    required this.green,
    required this.qty,
    required this.onBack,
    required this.onAdd,
    required this.onRemove,
  });

  final CafeMenuItem item;
  final List<CafeMenuItem> related;
  final Color green;
  final int qty;
  final VoidCallback onBack;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  List<({String title, String subtitle, String trailing})> get _rows {
    final rows = <({String title, String subtitle, String trailing})>[
      (
        title: item.categoryName.trim().isEmpty ? 'Menu' : item.categoryName,
        subtitle: 'Category',
        trailing: MoneyFormat.format(item.price),
      ),
    ];
    if (item.taxRate > 0) {
      rows.add((
        title: 'Tax',
        subtitle: '${item.taxRate.toStringAsFixed(0)}%',
        trailing: 'incl.',
      ));
    }
    for (final a in item.addons.take(6)) {
      rows.add((
        title: a.name,
        subtitle: 'Add-on',
        trailing: '+ ${MoneyFormat.format(a.price)}',
      ));
    }
    // Keep visual density like the reference list.
    while (rows.length < 3) {
      rows.add((
        title: 'Fresh serve',
        subtitle: 'Kitchen',
        trailing: '—',
      ));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(item.id);
    final chips = [
      item,
      ...related,
    ].take(5).toList();

    return Scaffold(
      backgroundColor: DetailedMenuColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    color: DetailedMenuColors.ink,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onAdd,
                    icon: Icon(Icons.favorite_border_rounded, color: green),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tone,
                        boxShadow: [
                          BoxShadow(
                            color: green.withValues(alpha: 0.18),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(item.name),
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                          color: green.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      decoration: BoxDecoration(
                        color: DetailedMenuColors.card,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: DetailedMenuColors.ink,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.addons.isEmpty
                                ? MoneyFormat.format(item.price)
                                : '${item.addons.length + 1} options',
                            style: const TextStyle(
                              color: DetailedMenuColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 44,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: chips.length + (related.length > 4 ? 1 : 0),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, i) {
                                if (i >= chips.length) {
                                  return CircleAvatar(
                                    radius: 22,
                                    backgroundColor: DetailedMenuColors.soft,
                                    child: Text(
                                      '+${related.length - 4}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: green,
                                      ),
                                    ),
                                  );
                                }
                                final c = chips[i];
                                return CircleAvatar(
                                  radius: 22,
                                  backgroundColor: _toneFor(c.id),
                                  child: Text(
                                    _initials(c.name),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: green,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final row in _rows) ...[
                    _IngredientRow(
                      title: row.title,
                      subtitle: row.subtitle,
                      trailing: row.trailing,
                      tone: _toneFor(row.title),
                      green: green,
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.keyboard_arrow_up_rounded,
                          color: green.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'Swipe up to see all options',
                        style: TextStyle(
                          color: DetailedMenuColors.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (qty == 0)
                    FilledButton(
                      onPressed: onAdd,
                      style: FilledButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      child: Text('Add · ${MoneyFormat.format(item.price)}'),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onRemove,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DetailedMenuColors.ink,
                              side: const BorderSide(
                                color: DetailedMenuColors.line,
                              ),
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Icon(Icons.remove_rounded),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '$qty',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: FilledButton(
                            onPressed: onAdd,
                            style: FilledButton.styleFrom(
                              backgroundColor: green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Icon(Icons.add_rounded),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.tone,
    required this.green,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final Color tone;
  final Color green;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      decoration: BoxDecoration(
        color: DetailedMenuColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DetailedMenuColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(title),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: green,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: DetailedMenuColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: DetailedMenuColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: DetailedMenuColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
